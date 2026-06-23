library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std.all;

-- This reduces the data width of an Avalon Memory-Mapped (Avalon-MM) bus.
-- The master-side address width grows accordingly.

entity avm_decrease is
  generic (
    G_BURST_WIDTH         : positive := 8;
    G_SLAVE_ADDRESS_SIZE  : positive;
    G_SLAVE_DATA_SIZE     : positive; -- Must be a multiple of G_MASTER_DATA_SIZE
    G_MASTER_ADDRESS_SIZE : positive;
    G_MASTER_DATA_SIZE    : positive
  );
  port (
    clk_i             : in    std_logic;
    rst_i             : in    std_logic;

    -- Slave port (faces upstream master) — wide side
    s_waitrequest_o   : out   std_logic;
    s_write_i         : in    std_logic;
    s_read_i          : in    std_logic;
    s_address_i       : in    std_logic_vector(G_SLAVE_ADDRESS_SIZE - 1 downto 0);
    s_writedata_i     : in    std_logic_vector(G_SLAVE_DATA_SIZE - 1 downto 0);
    s_byteenable_i    : in    std_logic_vector(G_SLAVE_DATA_SIZE / 8 - 1 downto 0);
    s_burstcount_i    : in    std_logic_vector(G_BURST_WIDTH - 1 downto 0);
    s_readdata_o      : out   std_logic_vector(G_SLAVE_DATA_SIZE - 1 downto 0);
    s_readdatavalid_o : out   std_logic;

    -- Master port (faces downstream slave) — narrow side
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
end entity avm_decrease;

architecture synthesis of avm_decrease is

  -- Number of master words per slave word
  -- Must be a power of two
  constant C_RATIO : positive                                              := G_SLAVE_DATA_SIZE / G_MASTER_DATA_SIZE;

  -- Additional address bits on the master side. The compile-time assertion below requires
  -- 2**C_ADDRESS_SHIFT = C_RATIO.
  constant C_ADDRESS_SHIFT : natural                                       := G_MASTER_ADDRESS_SIZE - G_SLAVE_ADDRESS_SIZE;

  constant C_ZERO_ADDRESS : std_logic_vector(C_ADDRESS_SHIFT - 1 downto 0) := (others => '0');

  signal   s_write      : std_logic;
  signal   s_read       : std_logic;
  signal   s_address    : std_logic_vector(G_SLAVE_ADDRESS_SIZE - 1 downto 0);
  signal   s_writedata  : std_logic_vector(G_SLAVE_DATA_SIZE - 1 downto 0);
  signal   s_byteenable : std_logic_vector(G_SLAVE_DATA_SIZE / 8 - 1 downto 0);
  signal   s_burstcount : std_logic_vector(G_BURST_WIDTH - 1 downto 0);

  type     state_type is (
    IDLE_ST,
    WRITING_ST,
    READ_DRAIN_ST
  );
  signal   state : state_type                                              := IDLE_ST;

  signal   s_write_pos : integer range 0 to C_RATIO - 1                    := 0;
  signal   s_read_pos  : integer range 0 to C_RATIO - 1                    := 0;

begin

  -----------------------------------------
  -- Compile-time consistency checks
  -----------------------------------------

  assert C_ADDRESS_SHIFT >= 1
    report "avm_decrease: degenerate ratio 1 not supported; use a passthrough"
    severity failure;
  assert C_RATIO = 2 ** C_ADDRESS_SHIFT
    severity failure;
  assert G_SLAVE_DATA_SIZE = C_RATIO * G_MASTER_DATA_SIZE
    severity failure;


  fsm_proc : process (clk_i)
  begin
    if rising_edge(clk_i) then
      s_readdatavalid_o <= '0';

      -- transaction-accepted handshake
      if m_waitrequest_i = '0' then
        s_write <= '0';
        s_read  <= '0';
      end if;

      -- reassemble C_RATIO narrow beats into one wide slave word, pulsing
      -- s_readdatavalid_o at completion.
      if m_readdatavalid_i = '1' then
        s_readdata_o(G_MASTER_DATA_SIZE * s_read_pos + G_MASTER_DATA_SIZE - 1 downto G_MASTER_DATA_SIZE * s_read_pos) <= m_readdata_i;

        if s_read_pos = C_RATIO - 1 then
          s_read_pos        <= 0;
          s_readdatavalid_o <= '1';
        else
          s_read_pos <= s_read_pos + 1;
        end if;
      end if;

      case state is

        when IDLE_ST =>
          if (s_write_i = '1' or s_read_i = '1') and s_waitrequest_o = '0' then
            s_write      <= s_write_i;
            s_read       <= s_read_i;
            s_address    <= s_address_i;
            s_writedata  <= s_writedata_i;
            s_byteenable <= s_byteenable_i;
            s_burstcount <= s_burstcount_i sll C_ADDRESS_SHIFT;

            if s_write_i = '1' then
              s_write_pos <= 0;
              state       <= WRITING_ST;
            elsif s_read_pos /= 0 or m_readdatavalid_i = '1' then
              state <= READ_DRAIN_ST;
            end if;
          end if;

        when WRITING_ST =>
          if m_waitrequest_i = '0' then
            s_write_pos <= s_write_pos + 1;

            -- Override the default "deassert m_write on accepted beat" so that
            -- m_write_o remains asserted across all C_RATIO beats of the burst.
            -- Note: the final beat (s_write_pos = C_RATIO - 1) is intentionally issued
            -- in IDLE_ST. Outputs in that cycle use the registered s_writedata/address
            -- captured before the previous edge, so they remain correct even if a new
            -- transaction is latched on the same edge (which enables back-to-back bursts
            -- with zero gap).
            s_write     <= s_write;

            if s_write_pos = C_RATIO - 2 then
              state <= IDLE_ST;
            end if;
          end if;

        -- Wait for an in-flight read burst to finish reassembly before accepting another
        -- request, to avoid issuing two read bursts whose responses would arrive on top
        -- of an already-advancing s_read_pos.
        when READ_DRAIN_ST =>
          if s_read_pos = 0 then
            state <= IDLE_ST;
          end if;

      end case;

      if rst_i = '1' then
        s_write           <= '0';
        s_read            <= '0';
        s_read_pos        <= 0;
        s_write_pos       <= 0;
        s_readdatavalid_o <= '0';
        state             <= IDLE_ST;
      end if;
    end if;
  end process fsm_proc;

  m_write_o       <= s_write;
  m_read_o        <= s_read;
  m_address_o     <= s_address & C_ZERO_ADDRESS;
  m_writedata_o   <= s_writedata(G_MASTER_DATA_SIZE * s_write_pos + G_MASTER_DATA_SIZE - 1 downto G_MASTER_DATA_SIZE * s_write_pos);
  m_byteenable_o  <= s_byteenable(G_MASTER_DATA_SIZE / 8 * s_write_pos + G_MASTER_DATA_SIZE / 8 - 1 downto G_MASTER_DATA_SIZE / 8 * s_write_pos);
  m_burstcount_o  <= s_burstcount;

  -- While a write burst is in progress (WRITING_ST) or a prior read burst is still
  -- draining (READ_DRAIN_ST), block upstream requests. In IDLE_ST, forward the downstream
  -- waitrequest only if an outgoing beat is being issued.
  s_waitrequest_o <= ((s_write or s_read) and m_waitrequest_i) when state = IDLE_ST else
                     '1';

end architecture synthesis;

