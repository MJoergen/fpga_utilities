library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std.all;

entity tb_wbus_master is
  generic (
    G_DEBUG     : boolean;
    G_ADDR_SIZE : natural;
    G_DATA_SIZE : natural
  );
end entity tb_wbus_master;

architecture simulation of tb_wbus_master is

  signal running : std_logic := '1';
  signal clk     : std_logic := '1';
  signal rst     : std_logic := '1';

  signal wbus_cyc   : std_logic;
  signal wbus_stall : std_logic;
  signal wbus_stb   : std_logic;
  signal wbus_addr  : std_logic_vector(G_ADDR_SIZE - 1 downto 0);
  signal wbus_we    : std_logic;
  signal wbus_wrdat : std_logic_vector(G_DATA_SIZE - 1 downto 0);
  signal wbus_ack   : std_logic;
  signal wbus_rddat : std_logic_vector(G_DATA_SIZE - 1 downto 0);

begin

  --------------------------------
  -- Clock and Reset
  --------------------------------

  clk <= running and not clk after 5 ns;
  rst <= '1', '0' after 100 ns;


  --------------------------------
  -- Instantiate DUT
  --------------------------------

  wbus_master_sim_inst : entity work.wbus_master_sim
    generic map (
      G_OFFSET    => 1234,
      G_ADDR_SIZE => G_ADDR_SIZE,
      G_DATA_SIZE => G_DATA_SIZE
    )
    port map (
      clk_i          => clk,
      rst_i          => rst,
      m_wbus_cyc_o   => wbus_cyc,
      m_wbus_stall_i => wbus_stall,
      m_wbus_stb_o   => wbus_stb,
      m_wbus_addr_o  => wbus_addr,
      m_wbus_we_o    => wbus_we,
      m_wbus_wrdat_o => wbus_wrdat,
      m_wbus_ack_i   => wbus_ack,
      m_wbus_rddat_i => wbus_rddat
    ); -- wbus_master_sim_inst : entity work.wbus_master_sim


  --------------------------------
  -- Instantiate Wishbone slave
  --------------------------------

  wbus_slave_sim_inst : entity work.wbus_slave_sim
    generic map (
      G_DEBUG     => G_DEBUG,
      G_LATENCY   => 3,
      G_TIMEOUT   => false,
      G_ADDR_SIZE => G_ADDR_SIZE,
      G_DATA_SIZE => G_DATA_SIZE
    )
    port map (
      clk_i          => clk,
      rst_i          => rst,
      s_wbus_cyc_i   => wbus_cyc,
      s_wbus_stall_o => wbus_stall,
      s_wbus_stb_i   => wbus_stb,
      s_wbus_addr_i  => wbus_addr,
      s_wbus_we_i    => wbus_we,
      s_wbus_wrdat_i => wbus_wrdat,
      s_wbus_ack_o   => wbus_ack,
      s_wbus_rddat_o => wbus_rddat
    ); -- wbus_slave_sim_inst : entity work.wbus_slave_sim

end architecture simulation;

