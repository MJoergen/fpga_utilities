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
--                issue a write, a read, or do nothing — producing randomised bus
--                traffic with natural gaps.
--
--                The simulation ends (std.env.stop) when the write pointer wraps
--                around the full address space.
--
-- Limitations  : - Only single-beat (burstcount = 1) transfers are generated.
--                - Byte-enables are always all-ones (full-word access).
--                - G_TIMEOUT_MAX is declared but not yet used (no watchdog).
-- ---------------------------------------------------------------------------------------

library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std_unsigned.all;  -- VHDL-2008: arithmetic directly on std_logic_vector
  use std.env.stop;                   -- VHDL-2008: simulation control

entity avm_master_sim is
  generic (
    G_BURST_WIDTH : natural                       := 8;

    G_SEED        : std_logic_vector(63 downto 0) := X"DEADBEEFC007BABE";
    -- Initial seed for the PRNG — use different seeds for
    -- independent master instances to decorrelate traffic.

    G_NAME        : string                        := "";
    -- Human-readable instance name, prepended to all report messages.

    G_DEBUG       : boolean                       := false;
    -- When true, every issued write/read is reported to the console.

    G_OFFSET      : natural                       := 1234;
    -- Constant offset added to the address to form the expected data
    -- pattern: data = resize(addr, G_DATA_SIZE) + G_OFFSET.
    -- A non-zero offset helps catch address/data-bus cross-wiring.

    G_ADDR_SIZE   : natural;
    -- Width of the Avalon-MM address bus (bits).

    G_DATA_SIZE   : natural
  -- Width of the Avalon-MM data bus (bits).
  -- Must be a multiple of 8 (byte-enables = G_DATA_SIZE / 8).
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
    m_byteenable_o    : out   std_logic_vector(G_DATA_SIZE / 8 - 1 downto 0); -- Byte-lane enables.
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
  subtype  R_REQUEST is natural range 15 downto 15;

  -- Bit index within random_s that selects write (1) vs. read (0).
  constant C_WRITE : natural  := 1;

  -- Derived one-shot control signals (active for one clock when not in reset).
  signal   do_request : std_logic; -- '1' when a new transaction may be issued.
  signal   do_read    : std_logic; -- '1' when the random decision is "read".
  signal   do_write   : std_logic; -- '1' when the random decision is "write".

  -- FSM states:
  --   IDLE_ST    : No transaction in progress; waiting for a random trigger.
  --   WRITING_ST : A write is in progress (waiting for waitrequest to deassert).
  --   READING_ST : A read has been accepted; waiting for readdatavalid.
  --   DONE_ST    : The full address space has been written; simulation stops.
  type     state_type is (IDLE_ST, WRITING_ST, READING_ST, DONE_ST);
  signal   state : state_type := IDLE_ST;

  -- Sequential write and read address pointers.
  -- wr_ptr: next address to be written (addresses 0..wr_ptr-1 have been written).
  -- rd_ptr: next address to be read back (addresses 0..rd_ptr-1 have been verified).
  -- Invariant: rd_ptr <= wr_ptr (reads never overtake writes).
  signal   wr_ptr : std_logic_vector(G_ADDR_SIZE - 1 downto 0);
  signal   rd_ptr : std_logic_vector(G_ADDR_SIZE - 1 downto 0);

  -- Difference between write and read pointers — exposed for waveform debugging.
  signal   diff_ptr : std_logic_vector(G_ADDR_SIZE - 1 downto 0);

  -- Compute the expected data payload for a given address.
  -- The pattern is simply the address zero-extended (or truncated) to G_DATA_SIZE
  -- bits, plus the constant G_OFFSET.

  pure function addr_to_data (
    addr : std_logic_vector
  ) return std_logic_vector is
  begin
    return resize(addr, G_DATA_SIZE) + G_OFFSET;
  end function addr_to_data;

begin

  -- Combinational pointer difference for waveform inspection.
  diff_ptr <= wr_ptr - rd_ptr;


  --------------------------------------------------------
  -- PRNG instantiation
  -- Produces a new 64-bit pseudo-random vector every clock.
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


  -- Derive per-cycle transaction-request strobes from the PRNG output.
  -- do_request is gated by R_REQUEST bits (all must be '1') and by reset.
  -- do_write / do_read are mutually exclusive, selected by bit C_WRITE.
  do_request <= and(random_s(R_REQUEST)) and not rst_i;
  do_write   <= do_request and     random_s(C_WRITE);
  do_read    <= do_request and not random_s(C_WRITE);


  --------------------------------------------------------
  -- Main FSM — issues writes and reads, verifies read-back data.
  --------------------------------------------------------

  avm_proc : process (clk_i)
    variable first_v : boolean := true;   -- One-shot flag for "test started" message.
  begin
    if rising_edge(clk_i) then
      -- Print a single "test started" message on the first cycle after reset.
      if rst_i = '0' and first_v then
        report "Avalon MASTER " & G_NAME &
               ": Test started";
        first_v := false;
      end if;

      -- Avalon-MM protocol: when waitrequest is deasserted the current
      -- request has been accepted.  Clear the request strobes so they
      -- are not re-asserted unless the FSM explicitly issues a new one.
      if m_waitrequest_i = '0' then
        m_write_o <= '0';
        m_read_o  <= '0';
      end if;

      case state is

        -- ============================================================
        -- IDLE_ST — No transaction in flight. Randomly decide whether
        --           to start a write or a read.
        -- ============================================================
        when IDLE_ST =>
          if do_write = '1' then
            -- Issue a single-beat write to the current write-pointer address.
            m_write_o      <= '1';
            m_address_o    <= wr_ptr;
            m_writedata_o  <= addr_to_data(wr_ptr);
            m_byteenable_o <= (others => '1');
            m_burstcount_o <= (0 => '1', others => '0');
            if G_DEBUG then
              report "Avalon MASTER " & G_NAME &
                     ": Write to address " & to_hstring(wr_ptr) &
                     " with data " & to_hstring(addr_to_data(wr_ptr));
            end if;
            state <= WRITING_ST;
          elsif do_read = '1' and rd_ptr < wr_ptr then
            -- A read is only allowed when there are addresses that have
            -- been written but not yet read back (rd_ptr < wr_ptr).

            -- Issue a single-beat read from the current read-pointer address.
            m_read_o       <= '1';
            m_address_o    <= rd_ptr;
            m_byteenable_o <= (others => '1');
            m_burstcount_o <= (0 => '1', others => '0');
            if G_DEBUG then
              report "Avalon MASTER " & G_NAME &
                     ": Read from address " & to_hstring(rd_ptr);
            end if;
            state <= READING_ST;
          end if;


        -- ============================================================
        -- WRITING_ST — A write is in progress.  Wait for the slave to
        --              accept it (waitrequest = '0'), then optionally
        --              chain the next transaction.
        -- ============================================================
        when WRITING_ST =>
          if m_waitrequest_i = '0' and m_write_o = '1' then
            -- Write accepted.  Advance the write pointer.
            wr_ptr <= wr_ptr + 1;

            -- Attempt to chain the next transaction without returning to IDLE_ST.
            if do_write = '1' then
              -- Check whether the NEXT address would wrap the pointer.
              -- (Uses the OLD wr_ptr; +1 = the address just written, +1+1 = next.)
              if wr_ptr + 1 = 0 then
                -- Entire address space written — terminate.
                state <= DONE_ST;
              else
                -- Chain the next write (address = wr_ptr + 1 = new wr_ptr value).
                m_write_o      <= '1';
                m_address_o    <= wr_ptr + 1;
                m_writedata_o  <= addr_to_data(wr_ptr + 1);
                m_byteenable_o <= (others => '1');
                m_burstcount_o <= (0 => '1', others => '0');
                if G_DEBUG then
                  report "Avalon MASTER " & G_NAME &
                         ": Write to address " & to_hstring(wr_ptr + 1) &
                         " with data " & to_hstring(addr_to_data(wr_ptr + 1));
                end if;
                state <= WRITING_ST;
              end if;
            elsif do_read = '1' and rd_ptr < wr_ptr + 1 then
              -- Chain a read.  Compare rd_ptr against the *updated* write
              -- pointer (wr_ptr + 1) because the signal hasn't propagated yet.
              m_read_o       <= '1';
              m_address_o    <= rd_ptr;
              m_byteenable_o <= (others => '1');
              m_burstcount_o <= (0 => '1', others => '0');
              if G_DEBUG then
                report "Avalon MASTER " & G_NAME &
                       ": Read from address " & to_hstring(rd_ptr);
              end if;
              state <= READING_ST;
            else
              -- No random trigger — return to idle.
              state <= IDLE_ST;
            end if;
          end if;


        -- ============================================================
        -- READING_ST — A read has been accepted; wait for the slave to
        --              return data (readdatavalid = '1'), verify the
        --              payload, then optionally chain the next transaction.
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

            -- Advance the read pointer (this address has been verified).
            rd_ptr <= rd_ptr + 1;

            -- Attempt to chain the next transaction.
            if do_write = '1' then
              -- Chain a write to the current write-pointer address.
              m_write_o      <= '1';
              m_address_o    <= wr_ptr;
              m_writedata_o  <= addr_to_data(wr_ptr);
              m_byteenable_o <= (others => '1');
              m_burstcount_o <= (0 => '1', others => '0');
              if G_DEBUG then
                report "Avalon MASTER " & G_NAME &
                       ": Write to address " & to_hstring(wr_ptr) &
                       " with data " & to_hstring(addr_to_data(wr_ptr));
              end if;
              state <= WRITING_ST;
            elsif do_read = '1' and rd_ptr + 1 < wr_ptr then
              -- Chain a read.  Use rd_ptr + 1 because the signal assignment
              -- (rd_ptr <= rd_ptr + 1) above has not yet propagated.
              m_read_o       <= '1';
              m_address_o    <= rd_ptr + 1;
              m_byteenable_o <= (others => '1');
              m_burstcount_o <= (0 => '1', others => '0');
              if G_DEBUG then
                report "Avalon MASTER " & G_NAME &
                       ": Read from address " & to_hstring(rd_ptr + 1);
              end if;
              state <= READING_ST;
            else
              -- No random trigger or no unread addresses — return to idle.
              state <= IDLE_ST;
            end if;
          end if;


        -- ============================================================
        -- DONE_ST — Full address space has been written. End simulation.
        -- ============================================================
        when DONE_ST =>
          report "Avalon MASTER " & G_NAME &
                 ": Test finished";
          stop;

      end case;

      -- ============================================================
      -- Synchronous reset — clears all outputs and returns to IDLE_ST.
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
        state          <= IDLE_ST;
      end if;
    end if;
  end process avm_proc;

end architecture simulation;

