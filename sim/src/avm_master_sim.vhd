
-- ---------------------------------------------------------------------------------------
-- Module       : avm_master_sim
--
-- Description  : Avalon-MM bus-master simulation model for testbench use.
--
--                Generates a pseudo-random sequence of write and read bursts that
--                sweep through the entire address space:
--
--                  * Writes proceed sequentially from address 0 upward.
--                  * Reads trail behind the write pointer, also sequentially.
--                  * Burst length is randomised per transaction in 1..G_MAX_BURST,
--                    then clipped so that
--                       - write bursts never cross the address-space wrap, and
--                       - read bursts never read past the write pointer.
--                  * Expected read-back data for each address is
--                        data = resize(address, G_DATA_SIZE) + G_OFFSET
--                    which is verified per beat.
--
--                A PRNG instance decides, on each idle clock cycle, whether to
--                issue a write burst, a read burst, or do nothing -- producing
--                randomised bus traffic with natural gaps.
--
--                After the write pointer wraps the address space, the FSM enters
--                DRAIN_ST and keeps issuing read bursts until the read pointer
--                also wraps; only then is the simulation terminated via std.env.stop.
--
--                A watchdog (G_TIMEOUT_MAX, in clocks) fires `severity failure`
--                if a write beat is not accepted, or a read beat does not return,
--                within the configured limit. Set G_TIMEOUT_MAX = 0 to disable.
--
-- Limitations  : - Byte-enables are always all-ones (full-word access).
--                - Burst length up to G_MAX_BURST; caller must ensure
--                  G_MAX_BURST < 2**G_BURST_WIDTH.
-- ---------------------------------------------------------------------------------------

library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std.all;            -- to_unsigned for burstcount conversion
  use ieee.numeric_std_unsigned.all;   -- VHDL-2008: arithmetic directly on std_logic_vector
  use std.env.stop;                    -- VHDL-2008: simulation control

entity avm_master_sim is
  generic (
    G_BURST_WIDTH : positive                      := 8;

    -- Maximum burst length the master will ever request. Each transaction
    -- picks a random length in 1..G_MAX_BURST, then clips it to safe
    -- boundaries (address-space wrap for writes, write-pointer for reads).
    -- Must satisfy 1 <= G_MAX_BURST < 2**G_BURST_WIDTH.
    G_MAX_BURST   : positive                      := 8;

    -- Initial seed for the PRNG -- use different seeds for
    -- independent master instances to decorrelate traffic.
    G_SEED        : std_logic_vector(63 downto 0) := X"DEADBEEFC007BABE";

    -- Human-readable instance name, prepended to all report messages.
    G_NAME        : string                        := "";

    -- When true, every issued write/read burst is reported to the console.
    G_DEBUG       : boolean                       := false;

    -- Constant offset added to the address to form the expected data
    -- pattern: data = resize(addr, G_DATA_SIZE) + G_OFFSET.
    -- A non-zero offset helps catch address/data-bus cross-wiring.
    G_OFFSET      : natural                       := 1234;

    -- Maximum number of clock cycles to wait for a slave response
    -- (waitrequest deassert for a write beat, readdatavalid for a read
    -- beat) before the watchdog fires `severity failure`.
    -- Set to 0 to disable the watchdog entirely.
    G_TIMEOUT_MAX : natural                       := 0;

    -- Width of the Avalon-MM address bus (bits).
    G_ADDR_SIZE   : positive;

    -- Width of the Avalon-MM data bus (bits).
    -- Must be a multiple of 8 (byte-enables = G_DATA_SIZE / 8).
    G_DATA_SIZE   : positive
  );
  port (
    clk_i             : in    std_logic;
    rst_i             : in    std_logic;                                      -- Synchronous reset, active high.

    -- Avalon-MM master interface
    m_waitrequest_i   : in    std_logic;                                      -- Slave back-pressure.
    m_write_o         : out   std_logic;                                      -- Write request strobe.
    m_read_o          : out   std_logic;                                      -- Read request strobe.
    m_address_o       : out   std_logic_vector(G_ADDR_SIZE - 1 downto 0);     -- Burst start address.
    m_writedata_o     : out   std_logic_vector(G_DATA_SIZE - 1 downto 0);     -- Write data (per beat).
    m_byteenable_o    : out   std_logic_vector(G_DATA_SIZE / 8 - 1 downto 0); -- Byte-lane enables (always all-ones).
    m_burstcount_o    : out   std_logic_vector(G_BURST_WIDTH - 1 downto 0);   -- Burst length in beats.
    m_readdatavalid_i : in    std_logic;                                      -- Read-data valid strobe (per beat).
    m_readdata_i      : in    std_logic_vector(G_DATA_SIZE - 1 downto 0)      -- Read-data return (per beat).
  );
end entity avm_master_sim;

architecture simulation of avm_master_sim is

  -- 64-bit PRNG output, updated every clock cycle.
  signal   random_s : std_logic_vector(63 downto 0);

  -- Bit-field selector within random_s that gates request generation.
  -- Defined as a range so it can easily be widened (e.g. 15 downto 12)
  -- to reduce request probability (all selected bits must be '1').
  -- With the current single-bit range, request probability per cycle is 1/2.
  subtype  R_REQUEST is natural range 15 downto 15;

  -- Bit index within random_s that selects write (1) vs. read (0).
  constant C_WRITE : natural                                              := 1;

  -- Constant byte-enable value reused for every transaction.
  constant C_ALL_ONES_BE : std_logic_vector(G_DATA_SIZE / 8 - 1 downto 0) := (others => '1');

  -- Combinational request enables -- true whenever the random gating bit(s)
  -- are '1' and the design is not in reset. do_write and do_read are
  -- mutually exclusive, selected by bit C_WRITE.
  signal   do_request : std_logic;
  signal   do_write   : std_logic;
  signal   do_read    : std_logic;

  -- FSM states:
  --   IDLE_ST    : No transaction in progress; waiting for a random trigger.
  --   WRITING_ST : A write burst is in progress (one or more beats remaining).
  --   READING_ST : A read burst has been accepted; awaiting readdatavalid beats.
  --   DRAIN_ST   : All writes complete; issue read bursts until rd_ptr wraps.
  --   DONE_ST    : Both pointers have wrapped; simulation stops.
  type     state_type is (IDLE_ST, WRITING_ST, READING_ST, DRAIN_ST, DONE_ST);
  signal   state : state_type                                             := IDLE_ST;

  -- Sequential write and read address pointers.
  -- wr_ptr: next address to be written (addresses 0..wr_ptr-1 have been written).
  -- rd_ptr: next address to be read back (addresses 0..rd_ptr-1 have been verified).
  -- Invariant (pre-wrap): rd_ptr <= wr_ptr. After writes wrap, writes_done='1'
  -- and the FSM uses (wr_ptr - rd_ptr) [unsigned] as the remaining-reads count.
  signal   wr_ptr : std_logic_vector(G_ADDR_SIZE - 1 downto 0);
  signal   rd_ptr : std_logic_vector(G_ADDR_SIZE - 1 downto 0);

  -- Difference between write and read pointers -- exposed for waveform debugging.
  signal   diff_ptr : std_logic_vector(G_ADDR_SIZE - 1 downto 0);

  -- Latched once wr_ptr wraps the address space.
  signal   writes_done : std_logic                                        := '0';

  -- Watchdog counter. Increments while waiting in WRITING_ST or READING_ST;
  -- cleared on any state change or transaction beat acceptance.
  signal   timeout_cnt : natural range 0 to G_TIMEOUT_MAX                 := 0;

  -- Beats remaining in the in-flight burst (including the next beat to be
  -- accepted / received). Set when the burst is issued, decremented on each
  -- accepted write beat or readdatavalid pulse. Reaches 1 on the LAST beat.
  signal   wr_beats_left : natural range 0 to G_MAX_BURST                 := 0;
  signal   rd_beats_left : natural range 0 to G_MAX_BURST                 := 0;

  -- Compute the expected data payload for a given address.
  -- The pattern is the address zero-extended (or truncated) to G_DATA_SIZE
  -- bits, plus the constant G_OFFSET. Note: if G_ADDR_SIZE > G_DATA_SIZE the
  -- pattern truncates, which weakens the cross-wiring check.

  pure function addr_to_data (
    addr : std_logic_vector
  ) return std_logic_vector is
  begin
    return resize(addr, G_DATA_SIZE) + G_OFFSET;
  end function addr_to_data;

  -- Pick a desired burst length in 1..G_MAX_BURST from PRNG bits.
  -- The caller is expected to pass at least 16 random bits.

  function pick_burst_len (
    rnd : std_logic_vector
  ) return natural is
  begin
    if G_MAX_BURST <= 1 then
      return 1;
    else
      return (to_integer(rnd) mod G_MAX_BURST) + 1;
    end if;
  end function pick_burst_len;

  -- Clip a write burst so it does not cross the address-space wrap.
  -- Returns 0 only when `desired` is 0 (which is filtered out upstream).

  function clip_write_burst (
    start   : std_logic_vector;
    desired : natural
  ) return natural is
    variable trial_v : std_logic_vector(start'range);
  begin
    if desired = 0 then
      return 0;
    end if;

    -- Address of the last beat under the unclipped burst.
    trial_v := start + (desired - 1);

    if trial_v >= start then
      -- No wrap occurred: full desired burst fits in the address space.
      return desired;
    else
      -- Wrap occurred within `desired` beats. The maximum allowed length is
      -- the count from `start` up to and including all-ones, which is
      --     2**G_ADDR_SIZE - to_integer(start) = to_integer(not start) + 1.
      -- This branch is only reached when start is within G_MAX_BURST of
      -- end-of-space, so (not start) is small and the to_integer is safe.
      return to_integer(not start) + 1;
    end if;
  end function clip_write_burst;

  -- Clip a read burst to the number of valid (written-but-unread) addresses.
  -- Works for both normal operation (rd < wr) and the drain phase
  -- (wr has wrapped to 0; `wr - rd` then equals 2**N - rd, the remaining
  -- drain count). Returns 0 when no reads are available (rd_ptr = wr_ptr).

  function clip_read_burst (
    rd      : std_logic_vector;
    wr      : std_logic_vector;
    desired : natural
  ) return natural is
    variable avail_v       : std_logic_vector(rd'length - 1 downto 0);
    variable desired_slv_v : std_logic_vector(rd'length - 1 downto 0);
  begin
    avail_v := wr - rd;

    if avail_v = std_logic_vector(to_unsigned(0, avail_v'length)) then
      return 0;
    end if;

    -- Build `desired` as an slv of the address width to compare safely
    -- (avail_v may be larger than naturalmax for big G_ADDR_SIZE).
    desired_slv_v := std_logic_vector(to_unsigned(desired, desired_slv_v'length));

    if avail_v >= desired_slv_v then
      return desired;
    else
      -- avail_v < desired <= G_MAX_BURST, so this to_integer is safe.
      return to_integer(avail_v);
    end if;
  end function clip_read_burst;

begin

  -- ----------------------------------------------------------------------------------
  -- Elaboration-time sanity checks
  -- ----------------------------------------------------------------------------------
  assert (G_DATA_SIZE mod 8) = 0
    report "avm_master_sim: G_DATA_SIZE must be a multiple of 8 (got "
           & integer'image(G_DATA_SIZE) & ")"
    severity failure;

  assert G_MAX_BURST < 2 ** G_BURST_WIDTH
    report "avm_master_sim: G_MAX_BURST (" & integer'image(G_MAX_BURST) &
           ") must be representable in G_BURST_WIDTH (" &
           integer'image(G_BURST_WIDTH) & ") bits"
    severity failure;

  -- Combinational pointer difference for waveform inspection.
  diff_ptr <= wr_ptr - rd_ptr;


  --------------------------------------------------------
  -- PRNG instantiation
  -- Produces a new 64-bit pseudo-random vector every clock,
  -- seeded once at elaboration by G_SEED.
  --------------------------------------------------------

  random_inst : entity work.random
    generic map (
      G_SEED => G_SEED
    )
    port map (
      clk_i    => clk_i,
      rst_i    => rst_i,
      update_i => '1',        -- Free-running: new value every cycle.
      output_o => random_s
    ); -- random_inst


  -- Combinational request enables -- gated by R_REQUEST bits (all must be '1')
  -- and held inactive during reset. do_write / do_read are mutually exclusive,
  -- selected by random_s(C_WRITE).
  do_request <= and(random_s(R_REQUEST)) and not rst_i;
  do_write   <= do_request and     random_s(C_WRITE);
  do_read    <= do_request and not random_s(C_WRITE);


  --------------------------------------------------------
  -- Main FSM -- issues write/read bursts, verifies read-back data.
  --------------------------------------------------------

  avm_proc : process (clk_i)
    variable first_v   : boolean := true;   -- One-shot flag for "test started" message.
    variable desired_v : natural;
    variable len_v     : natural;

    -- ------------------------------------------------------------------
    -- Issue the first beat of a write burst of length `len` starting
    -- at `addr`. The remaining beats are presented automatically by the
    -- WRITING_ST handler as each beat is accepted.
    --
    -- Avalon-MM convention: m_address_o holds the burst START address for
    -- the whole burst; m_burstcount_o holds the total beat count; only
    -- m_writedata_o changes per beat. m_write_o stays asserted until the
    -- LAST beat has been accepted.
    -- ------------------------------------------------------------------

    procedure issue_write_burst (
      addr : std_logic_vector;
      len  : natural
    ) is
    begin
      m_write_o      <= '1';
      m_address_o    <= addr;
      m_writedata_o  <= addr_to_data(addr);
      m_byteenable_o <= C_ALL_ONES_BE;
      m_burstcount_o <= std_logic_vector(to_unsigned(len, G_BURST_WIDTH));
      wr_beats_left  <= len;
      if G_DEBUG then
        report "Avalon MASTER " & G_NAME &
               ": Write burst of " & integer'image(len) &
               " beat(s) starting at address " & to_hstring(addr);
      end if;
    end procedure issue_write_burst;

    -- ------------------------------------------------------------------
    -- Issue a read burst of length `len` starting at `addr`. Only the
    -- request is driven; data is verified per beat in READING_ST.
    --
    -- Avalon-MM convention: m_read_o is asserted for one cycle (until
    -- waitrequest deasserts); the slave then returns `len` readdatavalid
    -- pulses with the requested data.
    -- ------------------------------------------------------------------

    procedure issue_read_burst (
      addr : std_logic_vector;
      len  : natural
    ) is
    begin
      m_read_o       <= '1';
      m_address_o    <= addr;
      m_byteenable_o <= C_ALL_ONES_BE;
      m_burstcount_o <= std_logic_vector(to_unsigned(len, G_BURST_WIDTH));
      rd_beats_left  <= len;
      if G_DEBUG then
        report "Avalon MASTER " & G_NAME &
               ": Read burst of " & integer'image(len) &
               " beat(s) starting at address " & to_hstring(addr);
      end if;
    end procedure issue_read_burst;

    -- ------------------------------------------------------------------
    -- Decide what to do next based on do_write / do_read and the
    -- *effective* pointer values supplied by the caller. Used while
    -- writes_done = '0'; the drain path is handled inline because it
    -- has different termination semantics.
    --
    -- wr_eff: address used if a write is issued.
    -- rd_eff: address used if a read is issued. The caller passes the
    --         anticipated (not-yet-propagated) value when chaining
    --         from a state that has just scheduled
    --         wr_ptr <= wr_ptr + N / rd_ptr <= rd_ptr + N.
    -- ------------------------------------------------------------------

    procedure start_next (
      wr_eff : std_logic_vector;
      rd_eff : std_logic_vector
    ) is
      variable desired_v : natural;
      variable len_v     : natural;
    begin
      if do_write = '1' then
        desired_v := pick_burst_len(random_s(31 downto 16));
        len_v     := clip_write_burst(wr_eff, desired_v);
        if len_v = 0 then
          -- Should never happen because desired_v >= 1 and start address
          -- has at least one beat left before wrap; defensive guard.
          state <= IDLE_ST;
        else
          issue_write_burst(wr_eff, len_v);
          state <= WRITING_ST;
        end if;
      elsif do_read = '1' then
        desired_v := pick_burst_len(random_s(31 downto 16));
        len_v     := clip_read_burst(rd_eff, wr_eff, desired_v);
        if len_v = 0 then
          -- No written-but-unread addresses available.
          state <= IDLE_ST;
        else
          issue_read_burst(rd_eff, len_v);
          state <= READING_ST;
        end if;
      else
        state <= IDLE_ST;
      end if;
    end procedure start_next;

  begin
    if rising_edge(clk_i) then
      -- Print a single "test started" message on the first cycle after reset.
      if rst_i = '0' and first_v then
        report "Avalon MASTER " & G_NAME & ": Test started";
        first_v := false;
      end if;

      -- ------------------------------------------------------------
      -- Watchdog: count cycles while waiting for the slave. Reset on
      -- any other state (IDLE/DRAIN/DONE) and on every accepted beat
      -- (inline below). G_TIMEOUT_MAX = 0 disables the watchdog.
      -- ------------------------------------------------------------
      if G_TIMEOUT_MAX > 0 and (state = WRITING_ST or state = READING_ST) then
        if timeout_cnt = G_TIMEOUT_MAX then
          report "Avalon MASTER " & G_NAME &
                 ": Watchdog timeout in state " & state_type'image(state) &
                 " (G_TIMEOUT_MAX = " & integer'image(G_TIMEOUT_MAX) &
                 ", wr_ptr = " & to_hstring(wr_ptr) &
                 ", rd_ptr = " & to_hstring(rd_ptr) &
                 ", wr_beats_left = " & integer'image(wr_beats_left) &
                 ", rd_beats_left = " & integer'image(rd_beats_left) & ")"
            severity failure;
        else
          timeout_cnt <= timeout_cnt + 1;
        end if;
      else
        timeout_cnt <= 0;
      end if;

      case state is

        -- ============================================================
        -- IDLE_ST -- No transaction in flight. Randomly decide whether
        --            to start a write or a read burst.
        -- ============================================================
        when IDLE_ST =>
          start_next(wr_ptr, rd_ptr);


        -- ============================================================
        -- WRITING_ST -- A write burst is in progress.
        --   * On each accepted beat (waitrequest = '0'):
        --       - advance wr_ptr
        --       - decrement wr_beats_left
        --       - if more beats remain, present the next writedata and
        --         keep m_write_o asserted (last-assignment-wins below)
        --       - if this was the LAST beat, deassert m_write_o, check
        --         for wrap, and either chain or enter drain.
        -- ============================================================
        when WRITING_ST =>
          if m_waitrequest_i = '0' and m_write_o = '1' then
            wr_ptr        <= wr_ptr + 1;
            wr_beats_left <= wr_beats_left - 1;
            timeout_cnt   <= 0;

            if wr_beats_left > 1 then
              -- More beats to send. Present the next writedata; m_write_o
              -- stays '1' because no later assignment in this branch
              -- overrides it.
              m_writedata_o <= addr_to_data(wr_ptr + 1);
              if G_DEBUG then
                report "Avalon MASTER " & G_NAME &
                       ": Write beat at address " & to_hstring(wr_ptr + 1) &
                       " with data " & to_hstring(addr_to_data(wr_ptr + 1));
              end if;
            -- state remains WRITING_ST
            else
              -- LAST beat of the burst was just accepted. Deassert the
              -- request strobe explicitly (we did NOT reach the
              -- m_waitrequest='0' block above this case because there
              -- isn't one any more -- the strobes are managed here per
              -- burst boundary).
              m_write_o <= '0';

              -- Wrap detection. wr_ptr (registered) was the address of
              -- the last accepted beat; wr_ptr + 1 is the next address.
              if wr_ptr + 1 = 0 then
                writes_done <= '1';
                state       <= DRAIN_ST;
              else
                start_next(wr_ptr + 1, rd_ptr);
              end if;
            end if;
          end if;


        -- ============================================================
        -- READING_ST -- A read burst has been accepted; the slave is
        -- returning beats via readdatavalid. We:
        --   * deassert m_read_o as soon as the request is accepted
        --     (waitrequest = '0'), independent of readdatavalid;
        --   * on each readdatavalid pulse:
        --       - verify the beat against the expected pattern
        --       - advance rd_ptr
        --       - decrement rd_beats_left
        --       - on the LAST beat, chain or transition to DRAIN/DONE.
        -- ============================================================
        when READING_ST =>
          -- Drop the read request once the slave has accepted it.
          if m_waitrequest_i = '0' and m_read_o = '1' then
            m_read_o <= '0';
          end if;

          if m_readdatavalid_i = '1' then
            assert m_readdata_i = addr_to_data(rd_ptr)
              report "Avalon MASTER " & G_NAME &
                     ": Read failure from address " & to_hstring(rd_ptr) &
                     ". Got " & to_hstring(m_readdata_i) &
                     ", expected " & to_hstring(addr_to_data(rd_ptr))
              severity failure;

            rd_ptr        <= rd_ptr + 1;
            rd_beats_left <= rd_beats_left - 1;
            timeout_cnt   <= 0;

            if rd_beats_left > 1 then
              -- More beats coming; stay in READING_ST.
              null;
            else
              -- LAST beat. Decide what happens next.
              if writes_done = '1' then
                if rd_ptr + 1 = 0 then
                  state <= DONE_ST;
                else
                  state <= DRAIN_ST;
                end if;
              else
                start_next(wr_ptr, rd_ptr + 1);
              end if;
            end if;
          end if;


        -- ============================================================
        -- DRAIN_ST -- All writes complete. Issue read bursts back-to-back
        --             (ignoring the PRNG) until rd_ptr wraps. Burst
        --             length is capped to the remaining unread count so
        --             we never read past the wrap.
        -- ============================================================
        when DRAIN_ST =>
          desired_v := pick_burst_len(random_s(31 downto 16));
          -- Remaining count after wrap = (0 - rd_ptr) unsigned = -rd_ptr.
          -- For the all-ones case (rd_ptr = 0 after a previous DONE check)
          -- this branch is not reachable; we only enter DRAIN_ST while
          -- rd_ptr /= 0 OR writes_done has just been set with rd_ptr = 0
          -- and the full address space is yet to be drained.
          len_v     := clip_read_burst(rd_ptr, wr_ptr, desired_v);

          if len_v = 0 then
            -- Edge case: rd_ptr = wr_ptr = 0 with writes_done = '1'
            -- means every address has already been verified.
            state <= DONE_ST;
          else
            issue_read_burst(rd_ptr, len_v);
            state <= READING_ST;
          end if;


        -- ============================================================
        -- DONE_ST -- Full address space written and verified. End sim.
        -- ============================================================
        when DONE_ST =>
          report "Avalon MASTER " & G_NAME & ": Test finished";
          stop;

      end case;

      -- ============================================================
      -- Synchronous reset -- clears all outputs and returns to IDLE_ST.
      -- IMPORTANT: this block must remain the LAST statement in the
      -- process so that "last assignment wins" guarantees reset
      -- precedence over any assignment made inside the case statement.
      -- Adding any signal assignment after this point will defeat
      -- reset for that signal.
      -- ============================================================
      if rst_i = '1' then
        m_write_o      <= '0';
        m_read_o       <= '0';
        m_address_o    <= (others => '0');
        m_writedata_o  <= (others => '0');
        m_byteenable_o <= (others => '0');
        m_burstcount_o <= (others => '0');
        wr_ptr         <= (others => '0');
        rd_ptr         <= (others => '0');
        wr_beats_left  <= 0;
        rd_beats_left  <= 0;
        writes_done    <= '0';
        timeout_cnt    <= 0;
        state          <= IDLE_ST;
        first_v        := true;          -- Re-arm the "test started" banner.
      end if;
    end if;
  end process avm_proc;

end architecture simulation;

