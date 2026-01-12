-- ---------------------------------------------------------------------------------------
-- Description: Verify wbus_sim
-- ---------------------------------------------------------------------------------------

library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std.all;

entity tb_wbus_sim is
  generic (
    G_DEBUG       : boolean;
    G_TIMEOUT_MAX : natural;
    G_DO_ABORT    : boolean;
    G_PAUSE_SIZE  : integer;
    G_ADDR_SIZE   : natural;
    G_DATA_SIZE   : natural
  );
end entity tb_wbus_sim;

architecture simulation of tb_wbus_sim is

  signal clk : std_logic := '1';
  signal rst : std_logic := '1';

  signal m_cyc   : std_logic;
  signal m_stall : std_logic;
  signal m_stb   : std_logic;
  signal m_addr  : std_logic_vector(G_ADDR_SIZE - 1 downto 0);
  signal m_we    : std_logic;
  signal m_wrdat : std_logic_vector(G_DATA_SIZE - 1 downto 0);
  signal m_ack   : std_logic;
  signal m_rddat : std_logic_vector(G_DATA_SIZE - 1 downto 0);

  signal s_cyc   : std_logic;
  signal s_stall : std_logic;
  signal s_stb   : std_logic;
  signal s_addr  : std_logic_vector(G_ADDR_SIZE - 1 downto 0);
  signal s_we    : std_logic;
  signal s_wrdat : std_logic_vector(G_DATA_SIZE - 1 downto 0);
  signal s_ack   : std_logic;
  signal s_rddat : std_logic_vector(G_DATA_SIZE - 1 downto 0);

begin

  --------------------------------
  -- Clock and Reset
  --------------------------------

  clk <= not clk after 5 ns;
  rst <= '1', '0' after 100 ns;


  --------------------------------
  -- Instantiate DUT
  --------------------------------

  wbus_sim_inst : entity work.wbus_sim
    generic map (
      G_DEBUG       => G_DEBUG,
      G_TIMEOUT_MAX => G_TIMEOUT_MAX,
      G_DO_ABORT    => G_DO_ABORT,
      G_NAME        => "",
      G_SEED        => X"1234567887654321",
      G_LATENCY     => 3,
      G_TIMEOUT     => false,
      G_OFFSET      => 1234,
      G_ADDR_SIZE   => G_ADDR_SIZE,
      G_DATA_SIZE   => G_DATA_SIZE
    )
    port map (
      clk_i     => clk,
      rst_i     => rst,
      m_cyc_o   => m_cyc,
      m_stall_i => m_stall,
      m_stb_o   => m_stb,
      m_addr_o  => m_addr,
      m_we_o    => m_we,
      m_wrdat_o => m_wrdat,
      m_ack_i   => m_ack,
      m_rddat_i => m_rddat,
      s_cyc_i   => s_cyc,
      s_stall_o => s_stall,
      s_stb_i   => s_stb,
      s_addr_i  => s_addr,
      s_we_i    => s_we,
      s_wrdat_i => s_wrdat,
      s_ack_o   => s_ack,
      s_rddat_o => s_rddat
    ); -- wbus_master_sim_inst : entity work.wbus_master_sim

  wbus_pause_inst : entity work.wbus_pause
    generic map (
      G_SEED       => X"1122334455667788",
      G_PAUSE_SIZE => G_PAUSE_SIZE,
      G_ADDR_SIZE  => G_ADDR_SIZE,
      G_DATA_SIZE  => G_DATA_SIZE
    )
    port map (
      clk_i     => clk,
      rst_i     => rst,
      s_cyc_i   => m_cyc,
      s_stall_o => m_stall,
      s_stb_i   => m_stb,
      s_addr_i  => m_addr,
      s_we_i    => m_we,
      s_wrdat_i => m_wrdat,
      s_ack_o   => m_ack,
      s_rddat_o => m_rddat,
      m_cyc_o   => s_cyc,
      m_stall_i => s_stall,
      m_stb_o   => s_stb,
      m_addr_o  => s_addr,
      m_we_o    => s_we,
      m_wrdat_o => s_wrdat,
      m_ack_i   => s_ack,
      m_rddat_i => s_rddat
    ); -- wbus_pause_inst : entity work.wbus_pause

end architecture simulation;

