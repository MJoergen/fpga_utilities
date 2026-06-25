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
--                    During normal operation reads are chosen randomly; during drain
--                    (after wr wrap) reads are forced until rd_ptr wraps too.
--                  * Burst length is randomised per transaction in 1..G_MAX_BURST,
--                    then clipped so writes never cross the address-space wrap
--                    and reads never overtake the write pointer.
--                  * The base expected pattern is
--                        data = resize(address, G_DATA_BITS) + G_OFFSET.
--                  * When G_RANDOM_BYTEENABLE = true, byte enables are randomised
--                    per beat (>=1 byte always enabled). The master records, for
--                    every address, which bytes were actually written and verifies
--                    only those bytes on read-back.
--
--                A PRNG instance decides, on each idle clock cycle, whether to
--                issue a write burst, a read burst, or do nothing -- producing
--                randomised bus traffic with natural gaps.
--
--                After the write pointer wraps the address space, the FSM enters
--                DRAIN_ST and keeps issuing read bursts until the read pointer
--                also wraps; only then is the simulation terminated via std.env.stop.
--                A coverage report is printed at end-of-test.
--
--                A watchdog (G_TIMEOUT_MAX, in clocks) fires `severity failure`
--                if a write beat is not accepted, or a read beat does not return,
--                within the configured limit. Set G_TIMEOUT_MAX = 0 to disable.
--
-- Limitations  : - Shadow memory is dense, sized 2**G_ADDR_BITS entries.
--                  Practical for G_ADDR_BITS up to ~20.
--                - Reads always issue with byteenable = all-ones
--                  (writes can be randomised; see G_RANDOM_BYTEENABLE).
-- ---------------------------------------------------------------------------------------

library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std.all;            -- to_unsigned for burstcount conversion
  use ieee.numeric_std_unsigned.all;   -- VHDL-2008: arithmetic directly on std_logic_vector
  use std.env.stop;                    -- VHDL-2008: simulation control

entity avm_master_sim is
  generic (
    G_BURST_BITS       : positive                      := 8;

    -- Maximum burst length the master will ever request. Each transaction
    -- picks a random length in 1..G_MAX_BURST, then clips it to safe
    -- boundaries (address-space wrap for writes, write-pointer for reads).
    -- Must satisfy 1 <= G_MAX_BURST < 2**G_BURST_BITS.
    G_MAX_BURST         : positive                      := 8;

    -- When true, randomise byte enables per write beat (>=1 byte forced on).
    -- Verification then checks only the bytes that were actually written.
    G_RANDOM_BYTEENABLE : boolean                       := false;

    -- Initial seed for the PRNG -- use different seeds for
    -- independent master instances to decorrelate traffic.
    G_SEED              : std_logic_vector(63 downto 0) := X"DEADBEEFC007BABE";

    -- Human-readable instance name, prepended to all report messages.
    G_NAME              : string                        := "";

    -- When true, every issued write/read burst is reported to the console.
    G_DEBUG             : boolean                       := false;

    -- Constant offset added to the address to form the expected data
    -- pattern: data = resize(addr, G_DATA_BITS) + G_OFFSET.
    -- A non-zero offset helps catch address/data-bus cross-wiring.
    G_OFFSET            : natural                       := 1234;

    -- Maximum number of clock cycles to wait for a slave response
    -- (waitrequest deassert for a write beat, readdatavalid for a read
    -- beat) before the watchdog fires `severity failure`.
    -- Default is 0, i.e. watchdog disabled — set explicitly in your testbench to enable.
    G_TIMEOUT_MAX       : natural                       := 0;

    -- Width of the Avalon-MM address bus (bits).
    G_ADDR_BITS         : positive;

    -- Width of the Avalon-MM data bus (bits).
    -- Must be a multiple of 8 (byte-enables = G_DATA_BITS / 8).
    G_DATA_BITS         : positive
  );
  port (
    clk_i             : in    std_logic;
    rst_i             : in    std_logic;                                      -- Synchronous reset, active high.

    -- Avalon-MM master interface
    m_waitrequest_i   : in    std_logic;                                      -- Slave back-pressure.
    m_write_o         : out   std_logic;                                      -- Write request strobe.
    m_read_o          : out   std_logic;                                      -- Read request strobe.
    m_address_o       : out   std_logic_vector(G_ADDR_BITS - 1 downto 0);     -- Burst start address.
    m_writedata_o     : out   std_logic_vector(G_DATA_BITS - 1 downto 0);     -- Write data (per beat).
    m_byteenable_o    : out   std_logic_vector(G_DATA_BITS / 8 - 1 downto 0); -- Byte-lane enables (all-ones for reads;
    --   per-beat randomised for writes if G_RANDOM_BYTEENABLE = true).
    m_burstcount_o    : out   std_logic_vector(G_BURST_BITS - 1 downto 0);   -- Burst length in beats.
    m_readdatavalid_i : in    std_logic;                                      -- Read-data valid strobe (per beat).
    m_readdata_i      : in    std_logic_vector(G_DATA_BITS - 1 downto 0)      -- Read-data return (per beat).
  );
end entity avm_master_sim;

architecture simulation of avm_master_sim is

  constant C_BE_BITS : natural                                      := G_DATA_BITS / 8;

  -- 64-bit PRNG output, updated every clock cycle.
  signal   random_s : std_logic_vector(63 downto 0);

  -- Bit-field selector within random_s that gates request generation.
  -- Defined as a range so it can easily be widened (e.g. 15 downto 12)
  -- to reduce request probability (all selected bits must be '1').
  -- With the current single-bit range, request probability per cycle is 1/2.
  subtype  R_REQUEST is natural range 15 downto 15;

  -- Bit index within random_s that selects write (1) vs. read (0).
  constant C_WRITE : natural                                         := 1;

  -- All-ones byte-enable used for every read burst, and for write bursts when G_RANDOM_BYTEENABLE = false.
  constant C_ALL_ONES_BE : std_logic_vector(C_BE_BITS - 1 downto 0) := (others => '1');

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
  signal   state : state_type                                        := IDLE_ST;

  -- Sequential write and read address pointers.
  -- wr_ptr: next address to be written (addresses 0..wr_ptr-1 have been written).
  -- rd_ptr: next address to be read back (addresses 0..rd_ptr-1 have been verified).
  -- Invariant (pre-wrap): rd_ptr <= wr_ptr. After writes wrap, writes_done='1'
  -- and the FSM uses (wr_ptr - rd_ptr) [unsigned] as the remaining-reads count.
  signal   wr_ptr : std_logic_vector(G_ADDR_BITS - 1 downto 0);
  signal   rd_ptr : std_logic_vector(G_ADDR_BITS - 1 downto 0);

  -- Difference between write and read pointers -- exposed for waveform debugging.
  signal   diff_ptr : std_logic_vector(G_ADDR_BITS - 1 downto 0);

  -- Latched once wr_ptr wraps the address space.
  signal   writes_done : std_logic                                   := '0';

  -- Watchdog counter. Increments while waiting in WRITING_ST or READING_ST;
  -- cleared on any state change or transaction beat acceptance.
  signal   timeout_cnt : natural range 0 to G_TIMEOUT_MAX            := 0;

  -- Beats remaining in the in-flight burst (including the next beat to be
  -- accepted / received). Set when the burst is issued, decremented on each
  -- accepted write beat or readdatavalid pulse. Reaches 1 on the LAST beat.
  signal   wr_beats_left : natural range 0 to G_MAX_BURST            := 0;
  signal   rd_beats_left : natural range 0 to G_MAX_BURST            := 0;

  -- Mirror of the byte-enable currently presented on the bus, so the WRITING_ST handler
  -- can refer to the BE that was in effect during the just-accepted beat when updating
  -- the shadow mask.
  signal   cur_be_s : std_logic_vector(C_BE_BITS - 1 downto 0)      := (others => '0');

  -- ----------------------------------------------------------------------------------
  -- Shadow memory: tracks the expected payload and per-byte "written" mask
  -- for every address. Used to verify partial-byte writes correctly.
  -- ----------------------------------------------------------------------------------
  type     shadow_data_type is array (natural range <>) of std_logic_vector(G_DATA_BITS - 1 downto 0);

  type     shadow_mask_type is array (natural range <>) of std_logic_vector(C_BE_BITS - 1 downto 0);

  signal   shadow_data : shadow_data_type(0 to 2 ** G_ADDR_BITS - 1) := (others => (others => '0'));
  signal   shadow_mask : shadow_mask_type(0 to 2 ** G_ADDR_BITS - 1) := (others => (others => '0'));

  -- ----------------------------------------------------------------------------------
  -- Helper functions
  -- ----------------------------------------------------------------------------------

  -- Compute the expected data payload for a given address.
  -- The pattern is the address zero-extended (or truncated) to G_DATA_BITS
  -- bits, plus the constant G_OFFSET. Note: if G_ADDR_BITS > G_DATA_BITS the
  -- pattern truncates, which weakens the cross-wiring check.

  pure function addr_to_data (
    addr : std_logic_vector
  ) return std_logic_vector is
  begin
    return resize(addr, G_DATA_BITS) + G_OFFSET;
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

  -- Choose a byte-enable for a write beat. When randomisation is off, always
  -- returns all-ones. When on, takes C_BE_BITS bits from `rnd` and forces
  -- at least one bit high so we never issue a degenerate no-op write.
  -- Forcing bit 0 high when the random draw is zero adds a slight bias toward
  -- patterns with bit 0 set; acceptable for stress testing.

  function pick_byteenable (
    rnd : std_logic_vector
  ) return std_logic_vector is
    variable be_v : std_logic_vector(C_BE_BITS - 1 downto 0);
    variable rnd_v : std_logic_vector(15 downto 0);
  begin
    if not G_RANDOM_BYTEENABLE then
      return C_ALL_ONES_BE;
    end if;
    rnd_v := rnd;
    be_v := rnd_v(C_BE_BITS - 1 downto 0);
    if be_v = std_logic_vector(to_unsigned(0, C_BE_BITS)) then
      be_v(0) := '1';
    end if;
    return be_v;
  end function pick_byteenable;

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
      --     2**G_ADDR_BITS - to_integer(start) = to_integer(not start) + 1.
      -- This branch is only reached when start is within G_MAX_BURST of
      -- end-of-space, so not start is in 0..G_MAX_BURST-1 and the to_integer
      -- fits well within natural regardless of G_ADDR_BITS.
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
    -- (avail_v may be larger than natural'high for big G_ADDR_BITS).
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
  assert (G_DATA_BITS mod 8) = 0
    report "avm_master_sim: G_DATA_BITS must be a multiple of 8 (got "
           & integer'image(G_DATA_BITS) & ")"
    severity failure;
  assert G_MAX_BURST < 2 ** G_BURST_BITS
    report "avm_master_sim: G_MAX_BURST (" & integer'image(G_MAX_BURST) &
           ") must be representable in G_BURST_BITS (" &
           integer'image(G_BURST_BITS) & ") bits"
    severity failure;
  assert G_ADDR_BITS <= 20
    report "avm_master_sim: G_ADDR_BITS > 20 with dense shadow memory may exhaust simulator memory"
    severity warning;

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
    variable be_v      : std_logic_vector(C_BE_BITS - 1 downto 0);
    variable desired_v : natural;
    variable len_v     : natural;

    -- ------------------------------------------------------------------
    -- Process-local procedures
    --   shadow memory : record_write_beat, verify_read_beat
    --   bus drivers   : issue_write_burst, issue_read_burst
    --   decision      : start_next
    --   reporting     : report_coverage
    -- -------------------------------------------------------------

    -- Record a write beat into the shadow memory:
    --   * for every enabled byte lane, copy the data byte into shadow_data
    --     and set the corresponding shadow_mask bit.
    --   * unwritten bytes remain at whatever they were before (don't care).

    procedure record_write_beat (
      addr : std_logic_vector;
      data : std_logic_vector;
      be   : std_logic_vector
    ) is
      variable idx_v     : natural;
      variable d_var_v   : std_logic_vector(G_DATA_BITS - 1 downto 0);
      variable m_var_v   : std_logic_vector(C_BE_BITS - 1 downto 0);
    begin
      idx_v   := to_integer(addr);
      d_var_v := shadow_data(idx_v);
      m_var_v := shadow_mask(idx_v);

      for b in 0 to C_BE_BITS - 1 loop
        if be(b) = '1' then
          d_var_v(b * 8 + 7 downto b * 8) := data(b * 8 + 7 downto b * 8);
          m_var_v(b)                      := '1';
        end if;
      end loop;

      shadow_data(idx_v) <= d_var_v;
      shadow_mask(idx_v) <= m_var_v;
    end procedure record_write_beat;

    -- Verify a read beat against the shadow memory:
    --   * for every byte lane whose mask bit is '1', compare against the
    --     stored expected byte;
    --   * lanes whose mask bit is '0' are skipped (never written -> don't check).

    procedure verify_read_beat (
      addr : std_logic_vector;
      data : std_logic_vector
    ) is
      variable idx_v   : natural;
      variable d_exp_v : std_logic_vector(G_DATA_BITS - 1 downto 0);
      variable m_exp_v : std_logic_vector(C_BE_BITS - 1 downto 0);
    begin
      idx_v   := to_integer(addr);
      d_exp_v := shadow_data(idx_v);
      m_exp_v := shadow_mask(idx_v);

      for b in 0 to C_BE_BITS - 1 loop
        if m_exp_v(b) = '1' then
          assert data(b * 8 + 7 downto b * 8) = d_exp_v(b * 8 + 7 downto b * 8)
            report "Avalon MASTER " & G_NAME &
                   ": Read mismatch at address " & to_hstring(addr) &
                   ", byte lane " & integer'image(b) &
                   ". Got " & to_hstring(data(b * 8 + 7 downto b * 8)) &
                   ", expected " & to_hstring(d_exp_v(b * 8 + 7 downto b * 8))
            severity failure;
        end if;
      end loop;
    end procedure verify_read_beat;

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
      len  : natural;
      be   : std_logic_vector
    ) is
    begin
      m_write_o      <= '1';
      m_address_o    <= addr;
      m_writedata_o  <= addr_to_data(addr);
      m_byteenable_o <= be;
      cur_be_s       <= be;
      m_burstcount_o <= std_logic_vector(to_unsigned(len, G_BURST_BITS));
      wr_beats_left  <= len;
      if G_DEBUG then
        report "Avalon MASTER " & G_NAME &
               ": Write burst of " & integer'image(len) &
               " beat(s) starting at " & to_hstring(addr) &
               ", be = " & to_hstring(be);
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
      cur_be_s       <= C_ALL_ONES_BE;
      m_burstcount_o <= std_logic_vector(to_unsigned(len, G_BURST_BITS));
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
    begin
      if do_write = '1' then
        desired_v := pick_burst_len(random_s(31 downto 16));
        len_v     := clip_write_burst(wr_eff, desired_v);
        if len_v = 0 then
          -- Should never happen because desired_v >= 1 and start address
          -- has at least one beat left before wrap; defensive guard.
          state <= IDLE_ST;
        else
          be_v  := pick_byteenable(random_s(47 downto 32));
          issue_write_burst(wr_eff, len_v, be_v);
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

    -- End-of-test coverage report. Counts how many bytes of the address
    -- space were ever written (i.e. mask bit set) so the user can spot
    -- pathological seeds. O(2**G_ADDR_BITS * C_BE_BITS) -- run once at DONE.

    procedure report_coverage is
      variable written_v : natural := 0;
      variable total_v   : natural;
    begin
      total_v := (2 ** G_ADDR_BITS) * C_BE_BITS;
      for a in 0 to 2 ** G_ADDR_BITS - 1 loop
        for b in 0 to C_BE_BITS - 1 loop
          if shadow_mask(a)(b) = '1' then
            written_v := written_v + 1;
          end if;
        end loop;
      end loop;
      report "Avalon MASTER " & G_NAME &
             ": Byte coverage = " & integer'image(written_v) &
             " / " & integer'image(total_v) &
             " (" & integer'image((written_v * 100) / total_v) & "%)";
    end procedure report_coverage;

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
        --       - keep m_write_o asserted (no assignment in this branch
        --         overrides the '1' set by issue_write_burst).
        --       - if this was the LAST beat, deassert m_write_o, check
        --         for wrap, and either chain or enter drain.
        -- ============================================================
        when WRITING_ST =>
          if m_waitrequest_i = '0' and m_write_o = '1' then
            -- Record the just-accepted beat into shadow memory using the BE
            -- and address that were on the bus during the cycle that ended.
            record_write_beat(wr_ptr, addr_to_data(wr_ptr), cur_be_s);

            wr_ptr        <= wr_ptr + 1;
            wr_beats_left <= wr_beats_left - 1;
            timeout_cnt   <= 0;

            if wr_beats_left > 1 then
              -- Present the next beat's data and a (possibly new) random BE.
              -- BE is randomised per beat for maximum partial-write stress.
              be_v           := pick_byteenable(random_s(47 downto 32));
              m_writedata_o  <= addr_to_data(wr_ptr + 1);
              m_byteenable_o <= be_v;
              cur_be_s       <= be_v;
              if G_DEBUG then
                report "Avalon MASTER " & G_NAME &
                       ": Write beat at " & to_hstring(wr_ptr + 1) &
                       ", be = " & to_hstring(be_v);
              end if;
            -- state remains WRITING_ST
            else
              -- LAST beat of the burst was just accepted. Explicitly deassert m_write_o
              -- here; unlike the single-beat version there is no blanket strobe-clear at
              -- the top of the process, so each burst handler must release its own strobe
              -- on its last beat.
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
        --       - verify the beat against the shadow-memory expected bytes (skipping never-written byte lanes).
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
            verify_read_beat(rd_ptr, m_readdata_i);

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
          -- len_v = 0 is not reachable except in the unusual case where DRAIN_ST is
          -- entered with rd_ptr = 0 and writes have just wrapped.
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
          report_coverage;
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
        cur_be_s       <= (others => '0');
        wr_ptr         <= (others => '0');
        rd_ptr         <= (others => '0');
        wr_beats_left  <= 0;
        rd_beats_left  <= 0;
        writes_done    <= '0';
        timeout_cnt    <= 0;
        state          <= IDLE_ST;
        first_v        := true;          -- Re-arm the "test started" banner.
      -- Note: shadow_data / shadow_mask are intentionally NOT cleared on
      -- reset. They model a "test memory" whose initial contents are
      -- defined only by the initialisation in the signal declarations
      -- and the writes the master has performed so far. Clearing them
      -- here would lose history across mid-test resets (which is normally
      -- not what you want for self-check).
      end if;
    end if;
  end process avm_proc;

end architecture simulation;

