-- ----------------------------------------------------------------------------
-- Author     : Michael Jørgensen
-- Platform   : AMD Artix 7
-- ----------------------------------------------------------------------------
-- Allows several Wushbone Masters to interact with a single Wishbone Slave.
-- ----------------------------------------------------------------------------

library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std.all;

library work;
  use work.wbus_pkg.slv32_array_type;

entity wbus_arbiter_general is
  generic (
    G_NUM_MASTERS : natural
  );
  port (
    clk_i     : in    std_logic;
    rst_i     : in    std_logic;

    -- Wishbone bus Slave interface
    s_cyc_i   : in    std_logic_vector(G_NUM_MASTERS - 1 downto 0);
    s_stall_o : out   std_logic_vector(G_NUM_MASTERS - 1 downto 0);
    s_stb_i   : in    std_logic_vector(G_NUM_MASTERS - 1 downto 0);
    s_addr_i  : in    slv32_array_type(G_NUM_MASTERS - 1 downto 0);
    s_we_i    : in    std_logic_vector(G_NUM_MASTERS - 1 downto 0);
    s_wrdat_i : in    slv32_array_type(G_NUM_MASTERS - 1 downto 0);
    s_ack_o   : out   std_logic_vector(G_NUM_MASTERS - 1 downto 0);
    s_rddat_o : out   slv32_array_type(G_NUM_MASTERS - 1 downto 0);

    -- Wishbone bus Master interface
    m_cyc_o   : out   std_logic;
    m_stall_i : in    std_logic;
    m_stb_o   : out   std_logic;
    m_addr_o  : out   std_logic_vector(31 downto 0);
    m_we_o    : out   std_logic;
    m_wrdat_o : out   std_logic_vector(31 downto 0);
    m_ack_i   : in    std_logic;
    m_rddat_i : in    std_logic_vector(31 downto 0)
  );
end entity wbus_arbiter_general;

architecture synthesis of wbus_arbiter_general is

  subtype  R_LEFT is natural range G_NUM_MASTERS - 1 downto G_NUM_MASTERS / 2;

  subtype  R_RIGHT is natural range G_NUM_MASTERS / 2 - 1 downto 0;

  constant C_NUM_LEFT  : natural := R_LEFT'high - R_LEFT'low + 1;
  constant C_NUM_RIGHT : natural := R_RIGHT'high - R_RIGHT'low + 1;

  signal   left_cyc   : std_logic;
  signal   left_stall : std_logic;
  signal   left_stb   : std_logic;
  signal   left_addr  : std_logic_vector(31 downto 0);
  signal   left_we    : std_logic;
  signal   left_wrdat : std_logic_vector(31 downto 0);
  signal   left_ack   : std_logic;
  signal   left_rddat : std_logic_vector(31 downto 0);

  signal   right_cyc   : std_logic;
  signal   right_stall : std_logic;
  signal   right_stb   : std_logic;
  signal   right_addr  : std_logic_vector(31 downto 0);
  signal   right_we    : std_logic;
  signal   right_wrdat : std_logic_vector(31 downto 0);
  signal   right_ack   : std_logic;
  signal   right_rddat : std_logic_vector(31 downto 0);

begin

  iterate_gen : if G_NUM_MASTERS = 1 generate
    -- Only one master
    m_cyc_o      <= s_cyc_i(0);
    m_stb_o      <= s_stb_i(0);
    m_addr_o     <= s_addr_i(0);
    m_we_o       <= s_we_i(0);
    m_wrdat_o    <= s_wrdat_i(0);
    s_stall_o(0) <= m_stall_i;
    s_ack_o(0)   <= m_ack_i;
    s_rddat_o(0) <= m_rddat_i;

  elsif G_NUM_MASTERS = 2 generate

    -- Just two masters
    wbus_arbiter_inst : entity work.wbus_arbiter
      generic map (
        G_ADDR_SIZE => 32
      )
      port map (
        clk_i      => clk_i,
        rst_i      => rst_i,
        s0_cyc_i   => s_cyc_i(0),
        s0_stall_o => s_stall_o(0),
        s0_stb_i   => s_stb_i(0),
        s0_addr_i  => s_addr_i(0),
        s0_we_i    => s_we_i(0),
        s0_wrdat_i => s_wrdat_i(0),
        s0_ack_o   => s_ack_o(0),
        s0_rddat_o => s_rddat_o(0),
        s1_cyc_i   => s_cyc_i(1),
        s1_stall_o => s_stall_o(1),
        s1_stb_i   => s_stb_i(1),
        s1_addr_i  => s_addr_i(1),
        s1_we_i    => s_we_i(1),
        s1_wrdat_i => s_wrdat_i(1),
        s1_ack_o   => s_ack_o(1),
        s1_rddat_o => s_rddat_o(1),
        m_cyc_o    => m_cyc_o,
        m_stall_i  => m_stall_i,
        m_stb_o    => m_stb_o,
        m_addr_o   => m_addr_o,
        m_we_o     => m_we_o,
        m_wrdat_o  => m_wrdat_o,
        m_ack_i    => m_ack_i,
        m_rddat_i  => m_rddat_i
      ); -- wbus_arbiter_inst : entity work.wbus_arbiter

  else generate

    assert G_NUM_MASTERS > 2;

    wbus_arbiter_general_left_inst : entity work.wbus_arbiter_general
      generic map (
        G_NUM_MASTERS => C_NUM_LEFT
      )
      port map (
        clk_i     => clk_i,
        rst_i     => rst_i,
        s_cyc_i   => s_cyc_i(R_LEFT),
        s_stall_o => s_stall_o(R_LEFT),
        s_stb_i   => s_stb_i(R_LEFT),
        s_addr_i  => s_addr_i(R_LEFT),
        s_we_i    => s_we_i(R_LEFT),
        s_wrdat_i => s_wrdat_i(R_LEFT),
        s_ack_o   => s_ack_o(R_LEFT),
        s_rddat_o => s_rddat_o(R_LEFT),
        m_cyc_o   => left_cyc,
        m_stall_i => left_stall,
        m_stb_o   => left_stb,
        m_addr_o  => left_addr,
        m_we_o    => left_we,
        m_wrdat_o => left_wrdat,
        m_ack_i   => left_ack,
        m_rddat_i => left_rddat
      ); -- wbus_arbiter_general_left_inst : entity work.wbus_arbiter_general

    wbus_arbiter_general_right_inst : entity work.wbus_arbiter_general
      generic map (
        G_NUM_MASTERS => C_NUM_RIGHT
      )
      port map (
        clk_i     => clk_i,
        rst_i     => rst_i,
        s_cyc_i   => s_cyc_i(R_RIGHT),
        s_stall_o => s_stall_o(R_RIGHT),
        s_stb_i   => s_stb_i(R_RIGHT),
        s_addr_i  => s_addr_i(R_RIGHT),
        s_we_i    => s_we_i(R_RIGHT),
        s_wrdat_i => s_wrdat_i(R_RIGHT),
        s_ack_o   => s_ack_o(R_RIGHT),
        s_rddat_o => s_rddat_o(R_RIGHT),
        m_cyc_o   => right_cyc,
        m_stall_i => right_stall,
        m_stb_o   => right_stb,
        m_addr_o  => right_addr,
        m_we_o    => right_we,
        m_wrdat_o => right_wrdat,
        m_ack_i   => right_ack,
        m_rddat_i => right_rddat
      ); -- wbus_arbiter_general_right_inst : entity work.wbus_arbiter_general

    -- Just two masters
    wbus_arbiter_inst : entity work.wbus_arbiter
      generic map (
        G_ADDR_SIZE => 32
      )
      port map (
        clk_i      => clk_i,
        rst_i      => rst_i,
        s0_cyc_i   => left_cyc,
        s0_stall_o => left_stall,
        s0_stb_i   => left_stb,
        s0_addr_i  => left_addr,
        s0_we_i    => left_we,
        s0_wrdat_i => left_wrdat,
        s0_ack_o   => left_ack,
        s0_rddat_o => left_rddat,
        s1_cyc_i   => right_cyc,
        s1_stall_o => right_stall,
        s1_stb_i   => right_stb,
        s1_addr_i  => right_addr,
        s1_we_i    => right_we,
        s1_wrdat_i => right_wrdat,
        s1_ack_o   => right_ack,
        s1_rddat_o => right_rddat,
        m_cyc_o    => m_cyc_o,
        m_stall_i  => m_stall_i,
        m_stb_o    => m_stb_o,
        m_addr_o   => m_addr_o,
        m_we_o     => m_we_o,
        m_wrdat_o  => m_wrdat_o,
        m_ack_i    => m_ack_i,
        m_rddat_i  => m_rddat_i
      ); -- wbus_arbiter_inst : entity work.wbus_arbiter

  end generate iterate_gen;

end architecture synthesis;

