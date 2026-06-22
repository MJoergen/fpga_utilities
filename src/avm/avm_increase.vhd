library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std_unsigned.all;

--------------------------------------------------------------------------------
-- avm_increase
--
-- Up-sizing bridge for the Avalon Memory-Mapped (Avalon-MM) protocol.
--
--   * Slave  side : narrow data path (G_SLAVE_DATA_SIZE bits)
--   * Master side : wide   data path (G_MASTER_DATA_SIZE bits)
--
-- Constraints (checked by assertions):
--   * G_MASTER_DATA_SIZE = C_RATIO * G_SLAVE_DATA_SIZE
--   * C_RATIO must be a power of two and > 1
--   * The total address space (size * 2**address) must match on both sides
--
-- Bursts:
--   * Up to (2**G_BURST_WIDTH - 1) slave beats are translated into the
--     minimum number of master beats required to cover the requested range.
--   * Misaligned start addresses are supported; the first master beat may
--     contain fewer than C_RATIO populated sub-slots (byte-enable encodes
--     this on writes; reads simply discard unused sub-slots). Sub-slot index
--     is given by s_address_i(C_ADDRESS_SHIFT - 1 downto 0).
--
-- Limitations:
--   * Reads and writes may not be issued simultaneously (asserted).
--   * Both interfaces share clk_i / rst_i (no CDC).
--   * The internal AXIS FIFO depth is 2**G_BURST_WIDTH master words
--     (sized to absorb the worst-case master read burst).
--------------------------------------------------------------------------------

entity avm_increase is
  generic (
    G_BURST_WIDTH         : positive := 8;
    G_SLAVE_ADDRESS_SIZE  : positive;
    G_SLAVE_DATA_SIZE     : positive;
    G_MASTER_ADDRESS_SIZE : positive;
    G_MASTER_DATA_SIZE    : positive -- Must be an integer multiple of G_SLAVE_DATA_SIZE
  );
  port (
    clk_i             : in    std_logic;
    rst_i             : in    std_logic;

    -- Slave port (faces upstream master) — narrow side
    s_waitrequest_o   : out   std_logic;
    s_write_i         : in    std_logic;
    s_read_i          : in    std_logic;
    s_address_i       : in    std_logic_vector(G_SLAVE_ADDRESS_SIZE - 1 downto 0);
    s_writedata_i     : in    std_logic_vector(G_SLAVE_DATA_SIZE - 1 downto 0);
    s_byteenable_i    : in    std_logic_vector(G_SLAVE_DATA_SIZE / 8 - 1 downto 0);
    s_burstcount_i    : in    std_logic_vector(G_BURST_WIDTH - 1 downto 0);
    s_readdata_o      : out   std_logic_vector(G_SLAVE_DATA_SIZE - 1 downto 0);
    s_readdatavalid_o : out   std_logic;

    -- Master port (faces downstream slave) — wide side
    m_waitrequest_i   : in    std_logic;
    m_write_o         : out   std_logic;
    m_read_o          : out   std_logic;
    m_address_o       : out   std_logic_vector(G_MASTER_ADDRESS_SIZE - 1 downto 0);
    m_writedata_o     : out   std_logic_vector(G_MASTER_DATA_SIZE - 1 downto 0);
    m_byteenable_o    : out   std_logic_vector(G_MASTER_DATA_SIZE / 8 - 1 downto 0);
    m_burstcount_o    : out   std_logic_vector(G_BURST_WIDTH - 1 downto 0);
    m_readdata_i      : in    std_logic_vector(G_MASTER_DATA_SIZE - 1 downto 0);
    m_readdatavalid_i : in    std_logic
  );
end entity avm_increase;

architecture synthesis of avm_increase is

  -- 2**G_BURST_WIDTH — the smallest value that is NOT a representable burstcount.
  -- Also used as the AXIS FIFO depth so it can absorb the worst-case master read burst.
  constant C_BURST_LIMIT : positive  := 2 ** G_BURST_WIDTH;

  -- Number of slave words per master word.
  constant C_RATIO : positive        := G_MASTER_DATA_SIZE / G_SLAVE_DATA_SIZE;

  -- log2(C_RATIO); also the # of LSBs of the
  -- slave address that select the sub-slot.
  constant C_ADDRESS_SHIFT : natural := G_SLAVE_ADDRESS_SIZE - G_MASTER_ADDRESS_SIZE;

  type     state_type is (
    IDLE_ST,    -- No transaction in flight; accepting new read or write.
    WRITING_ST, -- Multi-beat slave write being packed into master beats.
    READING_ST  -- Master read issued; streaming response beats from FIFO to slave.
  );

  signal   state : state_type        := IDLE_ST;

  -- Current sub-slot index within a master word
  -- (range 0 .. C_RATIO-1, wraps naturally).
  signal   offset : std_logic_vector(C_ADDRESS_SHIFT - 1 downto 0);

  -- Remaining slave beats in the current burst.
  signal   s_burstcount : std_logic_vector(G_BURST_WIDTH - 1 downto 0);

  -- Current master read word held by FIFO output.
  signal   m_readdata : std_logic_vector(G_MASTER_DATA_SIZE - 1 downto 0);

  -- FIFO read-side valid (gated through to s_readdatavalid_o in READING_ST).
  signal   m_readdatavalid : std_logic;

  -- Pops the next master word from the FIFO
  -- when the last sub-slot has been consumed.
  signal   m_ready : std_logic;

  -- High when the slave start address points at the *last* sub-slot of a
  -- master word, i.e. the master beat can be emitted immediately on the
  -- first slave cycle.
  signal   s_last_subslot : std_logic;

  -- AXIS FIFO write-side ready, sampled only for overflow assertion.
  -- The design never throttles on this signal; correctness relies on
  -- G_RAM_DEPTH = C_BURST_LIMIT being enough for the worst-case burst.
  signal   axis_s_ready : std_logic;


  -- Local alias inside fsm_proc:
  alias    s_master_address : std_logic_vector(G_MASTER_ADDRESS_SIZE - 1 downto 0)
                            is s_address_i(G_SLAVE_ADDRESS_SIZE - 1 downto C_ADDRESS_SHIFT);

begin

  ------------------------------
  -- Compile-time consistency checks
  ------------------------------

  assert C_RATIO > 1
    report "C_RATIO must be greater than one (G_MASTER_DATA_SIZE > G_SLAVE_DATA_SIZE required)"
    severity failure;
  assert C_ADDRESS_SHIFT > 0
    report "C_ADDRESS_SHIFT must be > 0 (G_SLAVE_ADDRESS_SIZE > G_MASTER_ADDRESS_SIZE required)"
    severity failure;
  assert G_MASTER_DATA_SIZE = C_RATIO * G_SLAVE_DATA_SIZE
    severity failure;
  assert G_MASTER_DATA_SIZE * (2 ** G_MASTER_ADDRESS_SIZE) =
         G_SLAVE_DATA_SIZE * (2 ** G_SLAVE_ADDRESS_SIZE)
    severity failure;
  assert C_RATIO = 2 ** C_ADDRESS_SHIFT
    report "Width ratio must be power-of-two"
    severity failure;


  s_last_subslot    <= and (s_address_i(C_ADDRESS_SHIFT - 1 downto 0));


  -- Slave is ready when:
  --   * we are IDLE (can accept a new transaction), or
  --   * we are inside a write burst AND the master is not currently stalling us.
  s_waitrequest_o   <= '0' when state = IDLE_ST or
                                (state = WRITING_ST and (m_write_o = '0' or m_waitrequest_i = '0')) else
                       '1';

  fsm_proc : process (clk_i)
    ----------------------------------------------------------------------
    -- calc_m_burstcount
    --   Number of master beats needed to cover [address, address + burstcount).
    --   master_beats = floor((address + burstcount - 1) / C_RATIO)
    --                -  floor(address                / C_RATIO) + 1
    --   The two leading zero-bits ("00" & address) guarantee no overflow during
    --   the intermediate addition. Result is truncated to G_BURST_WIDTH bits;
    --   this is safe because for any C_RATIO >= 2 the master burst is at most
    --   ceil(C_BURST_LIMIT / C_RATIO) + 1 < C_BURST_LIMIT
    ----------------------------------------------------------------------

    pure function calc_m_burstcount (
      address : std_logic_vector;
      burstcount : std_logic_vector
    ) return std_logic_vector is
      variable res_v : std_logic_vector(G_SLAVE_ADDRESS_SIZE + 1 downto 0);
    begin
      res_v := (("00" & address) + burstcount - 1) / C_RATIO - ("00" & address) / C_RATIO + 1;
      return res_v(G_BURST_WIDTH - 1 downto 0);
    end function calc_m_burstcount;

    procedure handle_write (
      pos : natural range 0 to C_RATIO - 1
    ) is
    begin
      m_writedata_o(G_SLAVE_DATA_SIZE  * (pos + 1) - 1 downto G_SLAVE_DATA_SIZE  * pos)        <= s_writedata_i;
      m_byteenable_o(G_SLAVE_DATA_SIZE / 8 * (pos + 1) - 1 downto G_SLAVE_DATA_SIZE / 8 * pos) <= s_byteenable_i;
    end procedure handle_write;

  --------------------------------------------------------------------
  -- Sequential logic
  --------------------------------------------------------------------
  begin
    if rising_edge(clk_i) then
      -- Master-side handshake: once the master accepts the cycle (waitrequest low),
      -- de-assert the strobes. Byte-enable is also cleared on a completed *write*
      -- so the next master beat starts with all sub-slots disabled and is then
      -- selectively re-enabled by handle_write().
      if m_waitrequest_i = '0' then
        m_read_o  <= '0';
        m_write_o <= '0';
        if m_write_o = '1' then
          m_byteenable_o <= (others => '0');
        end if;
      end if;

      case state is

        when IDLE_ST =>
          if s_write_i = '1' and s_waitrequest_o = '0' then
            assert s_burstcount_i /= 0
              report "Avalon-MM: write burstcount must be >= 1"
              severity failure;
            assert m_write_o = '0' or m_waitrequest_i = '0'
              report "Internal error: IDLE_ST"
              severity failure;
            assert s_read_i = '0'
              report "Simultaneous read+write not allowed"
              severity failure;
            m_read_o       <= '0';
            m_address_o    <= s_master_address;
            m_byteenable_o <= (others => '0');
            m_burstcount_o <= calc_m_burstcount(s_address_i, s_burstcount_i);

            handle_write(to_integer(s_address_i(C_ADDRESS_SHIFT - 1 downto 0)));

            -- Issue the master write now if this beat already completes a master word:
            --   * single-beat slave burst                       (s_burstcount_i = 1), or
            --   * misaligned start landing on the last sub-slot (s_last_subslot = '1').
            if s_burstcount_i = 1 or s_last_subslot = '1' then
              m_write_o <= '1';
            end if;

            if s_burstcount_i /= 1 then
              s_burstcount <= s_burstcount_i - 1;
              offset       <= s_address_i(C_ADDRESS_SHIFT - 1 downto 0) + 1;
              state        <= WRITING_ST;
            end if;
          end if;

          if s_read_i = '1' and s_waitrequest_o = '0' then
            assert s_burstcount_i /= 0
              report "Avalon-MM: read burstcount must be >= 1"
              severity failure;
            assert s_write_i = '0'
              report "Simultaneous read+write not allowed"
              severity failure;

            m_write_o      <= '0';
            m_read_o       <= '1';
            m_address_o    <= s_master_address;
            m_byteenable_o <= (others => '1');
            m_burstcount_o <= calc_m_burstcount(s_address_i, s_burstcount_i);
            s_burstcount   <= s_burstcount_i;
            offset         <= s_address_i(C_ADDRESS_SHIFT - 1 downto 0);
            state          <= READING_ST;
          end if;

        when WRITING_ST =>
          assert s_read_i = '0'
            report "Read not allowed during burst write"
            severity failure;
          assert rst_i = '1' or s_burstcount > 0
            report "Internal error: WRITING_ST: s_burstcount must be greater than zero"
            severity failure;
          if s_write_i = '1' and s_waitrequest_o = '0' then
            s_burstcount <= s_burstcount - 1;
            offset       <= offset + 1;

            if offset = C_RATIO - 1 then
              m_write_o <= '1';
            end if;

            handle_write(to_integer(offset));

            -- Force the final master beat early if the slave burst terminates
            -- mid-master-word; remaining byte-enables are zero, signalling a partial
            -- write.
            if s_burstcount = 1 then
              m_write_o <= '1';
              state     <= IDLE_ST;
            end if;
          end if;

        when READING_ST =>
          if m_readdatavalid = '1' then
            s_burstcount <= s_burstcount - 1;
            offset       <= offset + 1;

            -- On the last beat (s_burstcount = 1) we transition to IDLE_ST in the
            -- same cycle that the slave sees the final s_readdatavalid_o = '1'.
            -- Safe because s_readdatavalid_o is combinational on state and gates
            -- m_readdatavalid through to the slave for both READING_ST and the
            -- cycle of the transition.
            if s_burstcount = 1 then
              state <= IDLE_ST;
            end if;
          end if;

      end case;

      if rst_i = '1' then
        m_write_o      <= '0';
        m_read_o       <= '0';
        m_address_o    <= (others => '0');
        m_writedata_o  <= (others => '0');
        m_byteenable_o <= (others => '0');
        m_burstcount_o <= (others => '0');
        state          <= IDLE_ST;
        offset         <= (others => '0');
        s_burstcount   <= (others => '0');
      end if;
    end if;
  end process fsm_proc;


  ------------------------------
  -- Read response handling
  ------------------------------

  -- s_readdata_o is valid only while s_readdatavalid_o = '1'. Between bursts
  -- it presents a slice of stale FIFO data, which is harmless because the
  -- slave is not allowed to sample it.
  s_readdata_o      <= m_readdata(G_SLAVE_DATA_SIZE * (to_integer(offset) + 1) - 1 downto G_SLAVE_DATA_SIZE * to_integer(offset));
  s_readdatavalid_o <= m_readdatavalid when state = READING_ST else
                       '0';

  -- AXIS FIFO read-side pop strategy:
  --   * READING_ST : pop after the *last* sub-slot of the current master word
  --                  has been forwarded to the slave (offset = C_RATIO - 1).
  --   * IDLE_ST    : drain any residual (partial) master word left by the
  --                  previous misaligned read burst, before a new transaction.
  --   * WRITING_ST : not applicable — the FIFO is empty during writes.
  m_ready           <= '1' when offset = C_RATIO - 1 or state = IDLE_ST else
                       '0';

  -- Correctness assumes downstream slave delivers at most m_burstcount_o response words.
  fifo_overflow_check_proc : process (clk_i)
  begin
    if rising_edge(clk_i) and rst_i = '0' then
      assert m_readdatavalid_i = '0' or axis_s_ready = '1'
        report "FIFO overflow: downstream slave returned data while AXIS FIFO not ready"
        severity failure;
    end if;
  end process fifo_overflow_check_proc;


  ------------------------------
  -- Instantiate read FIFO
  ------------------------------

  axis_fifo_inst : entity work.axis_fifo
    generic map (
      G_DATA_SIZE => G_MASTER_DATA_SIZE,
      G_RAM_DEPTH => C_BURST_LIMIT
    )
    port map (
      clk_i     => clk_i,
      rst_i     => rst_i,
      s_ready_o => axis_s_ready,
      s_valid_i => m_readdatavalid_i,
      s_data_i  => m_readdata_i,
      m_ready_i => m_ready,
      m_valid_o => m_readdatavalid,
      m_data_o  => m_readdata
    );

end architecture synthesis;

