-- ---------------------------------------------------------------------------------------
-- Module       : avm_master_sim
--
-- Description  : Avalon-MM bus-master simulation model for testbench use.
--
--                Generates a pseudo-random sequence of single-beat write and read
--                transactions that sweep through the entire address space:
--
--                  * Writes proceed sequentially from address 0 upward.
--                  * Reads trail behind the write pointer, also sequentially.
--                  * The expected read-back data for each address is
--                        data = resize(address, G_DATA_SIZE) + G_OFFSET
--                    which creates a deterministic, non-trivial data pattern that
--                    detects address/data-bus wiring errors.
--
--                A PRNG instance decides, on each idle clock cycle, whether to
--                issue a write, a read, or do nothing -- producing randomised bus
--                traffic with natural gaps.
--
--                After the write pointer wraps the address space, the FSM enters a
--                drain state and keeps issuing reads until the read pointer also
--                wraps; only then is the simulation terminated via std.env.stop.
--
--                A watchdog (G_TIMEOUT_MAX, in clocks) fires `severity failure`
--                if a write is not accepted, or a read does not return data,
--                within the configured limit. Set G_TIMEOUT_MAX = 0 to disable.
--
-- Limitations  : - Only single-beat (burstcount = 1) transfers are generated.
--                - Byte-enables are always all-ones (full-word access).
-- ---------------------------------------------------------------------------------------

library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std_unsigned.all;  -- VHDL-2008: arithmetic directly on std_logic_vector
  use std.env.stop;                   -- VHDL-2008: simulation control

entity avm_master_sim is
  generic (
    G_BURST_WIDTH : positive                      := 8;

    -- Initial seed for the PRNG -- use different seeds for
    -- independent master instances to decorrelate traffic.
    G_SEED        : std_logic_vector(63 downto 0) := X"DEADBEEFC007BABE";

    -- Human-readable instance name, prepended to all report messages.
    G_NAME        : string                        := "";

    -- When true, every issued write/read is reported to the console.
    G_DEBUG       : boolean                       := false;

    -- Constant offset added to the address to form the expected data
    -- pattern: data = resize(addr, G_DATA_SIZE) + G_OFFSET.
    -- A non-zero offset helps catch address/data-bus cross-wiring.
    G_OFFSET      : natural                       := 1234;

    -- Maximum number of clock cycles to wait for a slave response
    -- (waitrequest deassert for writes, readdatavalid for reads)
    -- before the watchdog fires a `severity failure`. Set to 0 to
    -- disable the watchdog entirely.
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
    m_address_o       : out   std_logic_vector(G_ADDR_SIZE - 1 downto 0);     -- Transaction address.
    m_writedata_o     : out   std_logic_vector(G_DATA_SIZE - 1 downto 0);     -- Write data.
    m_byteenable_o    : out   std_logic_vector(G_DATA_SIZE / 8 - 1 downto 0); -- Byte-lane enables (always all-ones).
    m_burstcount_o    : out   std_logic_vector(G_BURST_WIDTH - 1 downto 0);   -- Burst length (always 1).
    m_readdatavalid_i : in    std_logic;                                      -- Read-data valid strobe.
    m_readdata_i      : in    std_logic_vector(G_DATA_SIZE - 1 downto 0)      -- Read-data return.
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

  -- Constant bus values reused for every transaction.
  constant C_ALL_ONES_BE : std_logic_vector(G_DATA_SIZE / 8 - 1 downto 0) := (others => '1');
  constant C_BURST_ONE   : std_logic_vector(G_BURST_WIDTH - 1 downto 0)   := (0 => '1', others => '0');

  -- Combinational request enables -- true whenever the random gating bit(s)
  -- are '1' and the design is not in reset. do_write and do_read are
  -- mutually exclusive, selected by bit C_WRITE.
  signal   do_request : std_logic;
  signal   do_write   : std_logic;
  signal   do_read    : std_logic;

  -- FSM states:
  --   IDLE_ST    : No transaction in progress; waiting for a random trigger.
  --   WRITING_ST : A write is in progress (waiting for waitrequest to deassert).
  --   READING_ST : A read has been accepted; waiting for readdatavalid.
  --   DRAIN_ST   : All writes complete; reads still pending. Issue reads
  --                back-to-back until the read pointer also wraps.
  --   DONE_ST    : Both pointers have wrapped; simulation stops.
  type     state_type is (IDLE_ST, WRITING_ST, READING_ST, DRAIN_ST, DONE_ST);
  signal   state : state_type                                             := IDLE_ST;

  -- Sequential write and read address pointers.
  -- wr_ptr: next address to be written (addresses 0..wr_ptr-1 have been written).
  -- rd_ptr: next address to be read back (addresses 0..rd_ptr-1 have been verified).
  -- Invariant (pre-wrap): rd_ptr <= wr_ptr.
  -- After the writes wrap, writes_done = '1' and the relation is tracked by the FSM.
  signal   wr_ptr : std_logic_vector(G_ADDR_SIZE - 1 downto 0);
  signal   rd_ptr : std_logic_vector(G_ADDR_SIZE - 1 downto 0);

  -- Difference between write and read pointers -- exposed for waveform debugging.
  signal   diff_ptr : std_logic_vector(G_ADDR_SIZE - 1 downto 0);

  -- Latched once wr_ptr wraps the address space. Used to gate the reads-only
  -- DRAIN_ST behaviour and the DONE_ST transition.
  signal   writes_done : std_logic                                        := '0';

  -- Watchdog counter. Increments while waiting in WRITING_ST or READING_ST;
  -- cleared on any state change or transaction acceptance.
  signal   timeout_cnt : natural range 0 to G_TIMEOUT_MAX                 := 0;

  -- Compute the expected data payload for a given address.
  -- The pattern is simply the address zero-extended (or truncated) to G_DATA_SIZE
  -- bits, plus the constant G_OFFSET. Note: if G_ADDR_SIZE > G_DATA_SIZE the
  -- pattern truncates, which weakens the cross-wiring check.

  pure function addr_to_data (
    addr : std_logic_vector
  ) return std_logic_vector is
  begin
    return resize(addr, G_DATA_SIZE) + G_OFFSET;
  end function addr_to_data;

begin

  -- ----------------------------------------------------------------------------------
  -- Elaboration-time sanity checks
  -- ----------------------------------------------------------------------------------
  assert (G_DATA_SIZE mod 8) = 0
    report "avm_master_sim: G_DATA_SIZE must be a multiple of 8 (got "
           & integer'image(G_DATA_SIZE) & ")"
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
  -- Main FSM -- issues writes and reads, verifies read-back data.
  --------------------------------------------------------

  avm_proc : process (clk_i)
    variable first_v : boolean := true;   -- One-shot flag for "test started" message.

    -- ------------------------------------------------------------------
    -- Drive the bus for a single-beat write to `addr`.
    -- Caller is responsible for the state transition.
    -- ------------------------------------------------------------------

    procedure issue_write (
      addr : std_logic_vector
    ) is
    begin
      m_write_o      <= '1';
      m_address_o    <= addr;
      m_writedata_o  <= addr_to_data(addr);
      m_byteenable_o <= C_ALL_ONES_BE;
      m_burstcount_o <= C_BURST_ONE;
      if G_DEBUG then
        report "Avalon MASTER " & G_NAME &
               ": Write to address " & to_hstring(addr) &
               " with data " & to_hstring(addr_to_data(addr));
      end if;
    end procedure issue_write;

    -- ------------------------------------------------------------------
    -- Drive the bus for a single-beat read from `addr`.
    -- Caller is responsible for the state transition.
    -- ------------------------------------------------------------------

    procedure issue_read (
      addr : std_logic_vector
    ) is
    begin
      m_read_o       <= '1';
      m_address_o    <= addr;
      m_byteenable_o <= C_ALL_ONES_BE;
      m_burstcount_o <= C_BURST_ONE;
      if G_DEBUG then
        report "Avalon MASTER " & G_NAME &
               ": Read from address " & to_hstring(addr);
      end if;
    end procedure issue_read;

    -- ------------------------------------------------------------------
    -- Decide what to do next based on do_write / do_read and the
    -- *effective* pointer values supplied by the caller.
    --
    -- wr_eff: address that should be used if a write is issued.
    -- rd_eff: address that should be used if a read is issued. The
    --         caller passes the anticipated (not-yet-propagated) value
    --         when chaining from a state that has just scheduled
    --         rd_ptr <= rd_ptr + 1 / wr_ptr <= wr_ptr + 1.
    --
    -- Note: this helper is used only while writes_done = '0'. The
    -- drain path (DRAIN_ST / READING_ST after writes_done) is handled
    -- inline because it has different termination semantics.
    -- ------------------------------------------------------------------

    procedure start_next (
      wr_eff : std_logic_vector;
      rd_eff : std_logic_vector
    ) is
    begin
      if do_write = '1' then
        issue_write(wr_eff);
        state <= WRITING_ST;
      elsif do_read = '1' and rd_eff < wr_eff then
        issue_read(rd_eff);
        state <= READING_ST;
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
      -- any other state (IDLE/DRAIN/DONE) and on successful acceptance
      -- (handled inline below). G_TIMEOUT_MAX = 0 disables the watchdog.
      -- ------------------------------------------------------------
      if G_TIMEOUT_MAX > 0 and (state = WRITING_ST or state = READING_ST) then
        if timeout_cnt = G_TIMEOUT_MAX then
          report "Avalon MASTER " & G_NAME &
                 ": Watchdog timeout in state " & state_type'image(state) &
                 " (G_TIMEOUT_MAX = " & integer'image(G_TIMEOUT_MAX) &
                 ", wr_ptr = " & to_hstring(wr_ptr) &
                 ", rd_ptr = " & to_hstring(rd_ptr) & ")"
            severity failure;
        else
          timeout_cnt <= timeout_cnt + 1;
        end if;
      else
        timeout_cnt <= 0;
      end if;

      -- Avalon-MM protocol: when waitrequest is deasserted the current
      -- request has been accepted. Clear the request strobes so they
      -- are not re-asserted unless the FSM explicitly issues a new one.
      if m_waitrequest_i = '0' then
        m_write_o <= '0';
        m_read_o  <= '0';
      end if;

      case state is

        -- ============================================================
        -- IDLE_ST -- No transaction in flight. Randomly decide whether
        --            to start a write or a read.
        -- ============================================================
        when IDLE_ST =>
          start_next(wr_ptr, rd_ptr);


        -- ============================================================
        -- WRITING_ST -- A write is in progress. Wait for the slave to
        --               accept it (waitrequest = '0'), then optionally
        --               chain the next transaction or enter drain.
        -- ============================================================
        when WRITING_ST =>
          assert m_write_o = '1';

          if m_waitrequest_i = '0' and m_write_o = '1' then
            -- Write accepted. Advance the write pointer and clear the watchdog.
            wr_ptr      <= wr_ptr + 1;
            timeout_cnt <= 0;

            -- Wrap detection is unconditional: it must trigger whether or not
            -- the PRNG happens to issue another write in this cycle.
            -- wr_ptr (the registered value) is still the address that was just
            -- written; wr_ptr + 1 is the value about to be committed and is
            -- therefore the next address. If it is zero, the address space
            -- has been fully covered.
            if wr_ptr + 1 = 0 then
              writes_done <= '1';
              state       <= DRAIN_ST;
            else
              -- Chain using the *anticipated* write pointer (wr_ptr + 1)
              -- because the signal assignment above has not propagated yet.
              start_next(wr_ptr + 1, rd_ptr);
            end if;
          end if;


        -- ============================================================
        -- READING_ST -- A read has been accepted; wait for the slave to
        --               return data (readdatavalid = '1'), verify the
        --               payload, then either chain or continue draining.
        -- ============================================================
        when READING_ST =>
          if m_readdatavalid_i = '1' then
            -- Verify the returned data against the expected pattern.
            assert m_readdata_i = addr_to_data(rd_ptr)
              report "Avalon MASTER " & G_NAME &
                     ": Read failure from address " & to_hstring(rd_ptr) &
                     ". Got " & to_hstring(m_readdata_i) &
                     ", expected " & to_hstring(addr_to_data(rd_ptr))
              severity failure;

            -- Advance the read pointer (this address has been verified)
            -- and clear the watchdog.
            rd_ptr      <= rd_ptr + 1;
            timeout_cnt <= 0;

            if writes_done = '1' then
              -- We are draining. Two cases:
              --   * rd_ptr + 1 = 0 -> every address has been verified, done.
              --   * otherwise      -> continue draining (DRAIN_ST will
              --                       unconditionally issue the next read).
              if rd_ptr + 1 = 0 then
                state <= DONE_ST;
              else
                state <= DRAIN_ST;
              end if;
            else
              -- Normal operation. Chain using the *anticipated* read pointer
              -- (rd_ptr + 1) for the do_read availability check.
              start_next(wr_ptr, rd_ptr + 1);
            end if;
          end if;


        -- ============================================================
        -- DRAIN_ST -- All writes complete. Issue reads back-to-back
        --             (ignoring the PRNG) until rd_ptr wraps.
        -- ============================================================
        when DRAIN_ST =>
          issue_read(rd_ptr);
          state <= READING_ST;


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
        writes_done    <= '0';
        timeout_cnt    <= 0;
        state          <= IDLE_ST;
        first_v        := true;            -- Re-arm the "test started" banner.
      end if;
    end if;
  end process avm_proc;

end architecture simulation;

