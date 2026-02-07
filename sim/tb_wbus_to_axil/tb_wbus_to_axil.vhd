-- ---------------------------------------------------------------------------------------
-- Description: Verify wbus_to_axil
-- ---------------------------------------------------------------------------------------

library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std.all;

library work;
  use work.wbus_pkg.all;
  use work.axil_pkg.all;

entity tb_wbus_to_axil is
  generic (
    G_DO_ABORT   : boolean;
    G_DEBUG      : boolean;
    G_FAST       : boolean;
    G_PAUSE_SIZE : natural;
    G_ADDR_SIZE  : natural;
    G_DATA_SIZE  : natural
  );
end entity tb_wbus_to_axil;

architecture simulation of tb_wbus_to_axil is

  signal clk : std_logic := '1';
  signal rst : std_logic := '1';

  signal m_wbus : wbus_rec_type (
                                 addr(G_ADDR_SIZE - 1 downto 0),
                                 wrdat(G_DATA_SIZE - 1 downto 0),
                                 rddat(G_DATA_SIZE - 1 downto 0)
                                );

  signal m_axil : axil_rec_type (
                                 awaddr(G_ADDR_SIZE - 1 downto 0),
                                 wdata(G_DATA_SIZE - 1 downto 0),
                                 wstrb(G_DATA_SIZE / 8 - 1 downto 0),
                                 araddr(G_ADDR_SIZE - 1 downto 0),
                                 rdata(G_DATA_SIZE - 1 downto 0)
                                );

  signal s_axil : axil_rec_type (
                                 awaddr(G_ADDR_SIZE - 1 downto 0),
                                 wdata(G_DATA_SIZE - 1 downto 0),
                                 wstrb(G_DATA_SIZE / 8 - 1 downto 0),
                                 araddr(G_ADDR_SIZE - 1 downto 0),
                                 rdata(G_DATA_SIZE - 1 downto 0)
                                );

begin

  --------------------------------
  -- Clock and Reset
  --------------------------------

  clk <= not clk after 5 ns;
  rst <= '1', '0' after 100 ns;


  --------------------------------
  -- Instantiate DUTs
  --------------------------------

  wbus_to_axil_inst : entity work.wbus_to_axil
    port map (
      clk_i  => clk,
      rst_i  => rst,
      s_wbus => m_wbus,
      m_axil => m_axil
    ); -- wbus_to_axil_inst : entity work.wbus_to_axil


  --------------------------------
  -- Instantiate Wishbone master
  --------------------------------

  wbus_master_sim_inst : entity work.wbus_master_sim
    generic map (
      G_DEBUG    => false,
      G_OFFSET   => 1234,
      G_DO_ABORT => G_DO_ABORT
    )
    port map (
      clk_i  => clk,
      rst_i  => rst,
      m_wbus => m_wbus
    ); -- wbus_master_sim_inst : entity work.wbus_master_sim


  --------------------------------
  -- Instantiate AXI Lite Slave
  --------------------------------

  axil_pause_inst : entity work.axil_pause
    generic map (
      G_SEED       => (others => '0'),
      G_PAUSE_SIZE => G_PAUSE_SIZE
    )
    port map (
      clk_i  => clk,
      rst_i  => rst,
      s_axil => m_axil,
      m_axil => s_axil
    ); -- axil_pause_inst : entity work.axil_pause


  axil_slave_sim_inst : entity work.axil_slave_sim
    generic map (
      G_DEBUG => G_DEBUG,
      G_FAST  => G_FAST
    )
    port map (
      clk_i  => clk,
      rst_i  => rst,
      s_axil => s_axil
    ); -- axil_slave_sim_inst : entity work.axil_slave_sim


end architecture simulation;

