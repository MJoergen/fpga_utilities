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
    clk_i          : in    std_logic;
    rst_i          : in    std_logic;

    -- Wishbone bus Slave interface
    s_wbus_cyc_i   : in    std_logic_vector(G_NUM_MASTERS - 1 downto 0);
    s_wbus_stall_o : out   std_logic_vector(G_NUM_MASTERS - 1 downto 0);
    s_wbus_stb_i   : in    std_logic_vector(G_NUM_MASTERS - 1 downto 0);
    s_wbus_addr_i  : in    slv32_array_type(G_NUM_MASTERS - 1 downto 0);
    s_wbus_we_i    : in    std_logic_vector(G_NUM_MASTERS - 1 downto 0);
    s_wbus_wrdat_i : in    slv32_array_type(G_NUM_MASTERS - 1 downto 0);
    s_wbus_ack_o   : out   std_logic_vector(G_NUM_MASTERS - 1 downto 0);
    s_wbus_rddat_o : out   slv32_array_type(G_NUM_MASTERS - 1 downto 0);

    -- Wishbone bus Master interface
    m_wbus_cyc_o   : out   std_logic;
    m_wbus_stall_i : in    std_logic;
    m_wbus_stb_o   : out   std_logic;
    m_wbus_addr_o  : out   std_logic_vector(31 downto 0);
    m_wbus_we_o    : out   std_logic;
    m_wbus_wrdat_o : out   std_logic_vector(31 downto 0);
    m_wbus_ack_i   : in    std_logic;
    m_wbus_rddat_i : in    std_logic_vector(31 downto 0)
  );
end entity wbus_arbiter_general;

architecture synthesis of wbus_arbiter_general is

  subtype R_LEFT is natural range G_NUM_MASTERS - 1 downto G_NUM_MASTERS / 2;
  subtype R_RIGHT is natural range G_NUM_MASTERS / 2 - 1 downto 0;

  constant C_NUM_LEFT  : natural := R_LEFT'high - R_LEFT'low + 1;
  constant C_NUM_RIGHT : natural := R_RIGHT'high - R_RIGHT'low + 1;

  signal  wbus_left_cyc   : std_logic;
  signal  wbus_left_stall : std_logic;
  signal  wbus_left_stb   : std_logic;
  signal  wbus_left_addr  : std_logic_vector(31 downto 0);
  signal  wbus_left_we    : std_logic;
  signal  wbus_left_wrdat : std_logic_vector(31 downto 0);
  signal  wbus_left_ack   : std_logic;
  signal  wbus_left_rddat : std_logic_vector(31 downto 0);

  signal  wbus_right_cyc   : std_logic;
  signal  wbus_right_stall : std_logic;
  signal  wbus_right_stb   : std_logic;
  signal  wbus_right_addr  : std_logic_vector(31 downto 0);
  signal  wbus_right_we    : std_logic;
  signal  wbus_right_wrdat : std_logic_vector(31 downto 0);
  signal  wbus_right_ack   : std_logic;
  signal  wbus_right_rddat : std_logic_vector(31 downto 0);

begin

  iterate_gen : if G_NUM_MASTERS = 1 generate
    -- Only one master
    m_wbus_cyc_o      <= s_wbus_cyc_i(0);
    m_wbus_stb_o      <= s_wbus_stb_i(0);
    m_wbus_addr_o     <= s_wbus_addr_i(0);
    m_wbus_we_o       <= s_wbus_we_i(0);
    m_wbus_wrdat_o    <= s_wbus_wrdat_i(0);
    s_wbus_stall_o(0) <= m_wbus_stall_i;
    s_wbus_ack_o(0)   <= m_wbus_ack_i;
    s_wbus_rddat_o(0) <= m_wbus_rddat_i;

  elsif G_NUM_MASTERS = 2 generate

    -- Just two masters
    wbus_arbiter_inst : entity work.wbus_arbiter
      generic map (
        G_ADDR_SIZE => 32
      )
      port map (
        clk_i           => clk_i,
        rst_i           => rst_i,
        s0_wbus_cyc_i   => s_wbus_cyc_i(0),
        s0_wbus_stall_o => s_wbus_stall_o(0),
        s0_wbus_stb_i   => s_wbus_stb_i(0),
        s0_wbus_addr_i  => s_wbus_addr_i(0),
        s0_wbus_we_i    => s_wbus_we_i(0),
        s0_wbus_wrdat_i => s_wbus_wrdat_i(0),
        s0_wbus_ack_o   => s_wbus_ack_o(0),
        s0_wbus_rddat_o => s_wbus_rddat_o(0),
        s1_wbus_cyc_i   => s_wbus_cyc_i(1),
        s1_wbus_stall_o => s_wbus_stall_o(1),
        s1_wbus_stb_i   => s_wbus_stb_i(1),
        s1_wbus_addr_i  => s_wbus_addr_i(1),
        s1_wbus_we_i    => s_wbus_we_i(1),
        s1_wbus_wrdat_i => s_wbus_wrdat_i(1),
        s1_wbus_ack_o   => s_wbus_ack_o(1),
        s1_wbus_rddat_o => s_wbus_rddat_o(1),
        m_wbus_cyc_o    => m_wbus_cyc_o,
        m_wbus_stall_i  => m_wbus_stall_i,
        m_wbus_stb_o    => m_wbus_stb_o,
        m_wbus_addr_o   => m_wbus_addr_o,
        m_wbus_we_o     => m_wbus_we_o,
        m_wbus_wrdat_o  => m_wbus_wrdat_o,
        m_wbus_ack_i    => m_wbus_ack_i,
        m_wbus_rddat_i  => m_wbus_rddat_i
      ); -- wbus_arbiter_inst : entity work.wbus_arbiter

  else generate

    assert G_NUM_MASTERS > 2;

    wbus_arbiter_general_left_inst : entity work.wbus_arbiter_general
      generic map (
        G_NUM_MASTERS => C_NUM_LEFT
      )
      port map (
        clk_i          => clk_i,
        rst_i          => rst_i,
        s_wbus_cyc_i   => s_wbus_cyc_i(R_LEFT),
        s_wbus_stall_o => s_wbus_stall_o(R_LEFT),
        s_wbus_stb_i   => s_wbus_stb_i(R_LEFT),
        s_wbus_addr_i  => s_wbus_addr_i(R_LEFT),
        s_wbus_we_i    => s_wbus_we_i(R_LEFT),
        s_wbus_wrdat_i => s_wbus_wrdat_i(R_LEFT),
        s_wbus_ack_o   => s_wbus_ack_o(R_LEFT),
        s_wbus_rddat_o => s_wbus_rddat_o(R_LEFT),
        m_wbus_cyc_o   => wbus_left_cyc,
        m_wbus_stall_i => wbus_left_stall,
        m_wbus_stb_o   => wbus_left_stb,
        m_wbus_addr_o  => wbus_left_addr,
        m_wbus_we_o    => wbus_left_we,
        m_wbus_wrdat_o => wbus_left_wrdat,
        m_wbus_ack_i   => wbus_left_ack,
        m_wbus_rddat_i => wbus_left_rddat
      ); -- wbus_arbiter_general_left_inst : entity work.wbus_arbiter_general

    wbus_arbiter_general_right_inst : entity work.wbus_arbiter_general
      generic map (
        G_NUM_MASTERS => C_NUM_RIGHT
      )
      port map (
        clk_i          => clk_i,
        rst_i          => rst_i,
        s_wbus_cyc_i   => s_wbus_cyc_i(R_RIGHT),
        s_wbus_stall_o => s_wbus_stall_o(R_RIGHT),
        s_wbus_stb_i   => s_wbus_stb_i(R_RIGHT),
        s_wbus_addr_i  => s_wbus_addr_i(R_RIGHT),
        s_wbus_we_i    => s_wbus_we_i(R_RIGHT),
        s_wbus_wrdat_i => s_wbus_wrdat_i(R_RIGHT),
        s_wbus_ack_o   => s_wbus_ack_o(R_RIGHT),
        s_wbus_rddat_o => s_wbus_rddat_o(R_RIGHT),
        m_wbus_cyc_o   => wbus_right_cyc,
        m_wbus_stall_i => wbus_right_stall,
        m_wbus_stb_o   => wbus_right_stb,
        m_wbus_addr_o  => wbus_right_addr,
        m_wbus_we_o    => wbus_right_we,
        m_wbus_wrdat_o => wbus_right_wrdat,
        m_wbus_ack_i   => wbus_right_ack,
        m_wbus_rddat_i => wbus_right_rddat
      ); -- wbus_arbiter_general_right_inst : entity work.wbus_arbiter_general

    -- Just two masters
    wbus_arbiter_inst : entity work.wbus_arbiter
      generic map (
        G_ADDR_SIZE => 32
      )
      port map (
        clk_i           => clk_i,
        rst_i           => rst_i,
        s0_wbus_cyc_i   => wbus_left_cyc,
        s0_wbus_stall_o => wbus_left_stall,
        s0_wbus_stb_i   => wbus_left_stb,
        s0_wbus_addr_i  => wbus_left_addr,
        s0_wbus_we_i    => wbus_left_we,
        s0_wbus_wrdat_i => wbus_left_wrdat,
        s0_wbus_ack_o   => wbus_left_ack,
        s0_wbus_rddat_o => wbus_left_rddat,
        s1_wbus_cyc_i   => wbus_right_cyc,
        s1_wbus_stall_o => wbus_right_stall,
        s1_wbus_stb_i   => wbus_right_stb,
        s1_wbus_addr_i  => wbus_right_addr,
        s1_wbus_we_i    => wbus_right_we,
        s1_wbus_wrdat_i => wbus_right_wrdat,
        s1_wbus_ack_o   => wbus_right_ack,
        s1_wbus_rddat_o => wbus_right_rddat,
        m_wbus_cyc_o    => m_wbus_cyc_o,
        m_wbus_stall_i  => m_wbus_stall_i,
        m_wbus_stb_o    => m_wbus_stb_o,
        m_wbus_addr_o   => m_wbus_addr_o,
        m_wbus_we_o     => m_wbus_we_o,
        m_wbus_wrdat_o  => m_wbus_wrdat_o,
        m_wbus_ack_i    => m_wbus_ack_i,
        m_wbus_rddat_i  => m_wbus_rddat_i
      ); -- wbus_arbiter_inst : entity work.wbus_arbiter

  end generate iterate_gen;

end architecture synthesis;

