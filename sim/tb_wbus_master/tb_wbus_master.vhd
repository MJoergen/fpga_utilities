-- ---------------------------------------------------------------------------------------
-- Description: Verify wbus_master
-- ---------------------------------------------------------------------------------------

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

  signal clk : std_logic := '1';
  signal rst : std_logic := '1';

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

  clk <= not clk after 5 ns;
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
      clk_i     => clk,
      rst_i     => rst,
      m_cyc_o   => wbus_cyc,
      m_stall_i => wbus_stall,
      m_stb_o   => wbus_stb,
      m_addr_o  => wbus_addr,
      m_we_o    => wbus_we,
      m_wrdat_o => wbus_wrdat,
      m_ack_i   => wbus_ack,
      m_rddat_i => wbus_rddat
    ); -- wbus_master_sim_inst : entity work.wbus_master_sim


  --------------------------------
  -- Instantiate Wishbone slave
  --------------------------------

  wbus_slave_sim_inst : entity work.wbus_slave_sim
    generic map (
      G_DEBUG     => G_DEBUG,
      G_ADDR_SIZE => G_ADDR_SIZE,
      G_DATA_SIZE => G_DATA_SIZE
    )
    port map (
      clk_i     => clk,
      rst_i     => rst,
      s_cyc_i   => wbus_cyc,
      s_stall_o => wbus_stall,
      s_stb_i   => wbus_stb,
      s_addr_i  => wbus_addr,
      s_we_i    => wbus_we,
      s_wrdat_i => wbus_wrdat,
      s_ack_o   => wbus_ack,
      s_rddat_o => wbus_rddat
    ); -- wbus_slave_sim_inst : entity work.wbus_slave_sim

end architecture simulation;

