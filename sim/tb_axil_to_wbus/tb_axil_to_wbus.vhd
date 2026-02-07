-- ---------------------------------------------------------------------------------------
-- Description: Comprehensive test of the AXI-Lite to WBUS.  The axil_master_sim module
-- used here generates multiple accesses simultaneously.
-- ---------------------------------------------------------------------------------------

library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std.all;

library work;
  use work.axil_pkg.all;
  use work.wbus_pkg.all;

entity tb_axil_to_wbus is
  generic (
    G_DEBUG     : boolean;
    G_LATENCY   : natural;
    G_RANDOM    : boolean;
    G_FAST      : boolean;
    G_ADDR_SIZE : natural;
    G_DATA_SIZE : natural
  );
end entity tb_axil_to_wbus;

architecture simulation of tb_axil_to_wbus is

  signal clk : std_logic := '1';
  signal rst : std_logic := '1';

  signal axil : axil_rec_type (
                               awaddr(G_ADDR_SIZE - 1 downto 0),
                               wdata(G_DATA_SIZE - 1 downto 0),
                               wstrb(G_DATA_SIZE / 8 - 1 downto 0),
                               araddr(G_ADDR_SIZE - 1 downto 0),
                               rdata(G_DATA_SIZE - 1 downto 0)
                              );

  signal wbus : wbus_rec_type (
                               addr(G_ADDR_SIZE - 1 downto 0),
                               wrdat(G_DATA_SIZE - 1 downto 0),
                               rddat(G_DATA_SIZE - 1 downto 0)
                              );

begin

  ------------------------------------------
  -- Clock and reset
  ------------------------------------------

  clk <= not clk after 5 ns;
  rst <= '1', '0' after 100 ns;


  ------------------------------------------
  -- Generate stimuli
  ------------------------------------------

  axil_master_sim_inst : entity work.axil_master_sim
    generic map (
      G_DEBUG     => G_DEBUG,
      G_OFFSET    => 1234,
      G_RANDOM    => G_RANDOM,
      G_FAST      => G_FAST
    )
    port map (
      clk_i  => clk,
      rst_i  => rst,
      m_axil => axil
    ); -- axil_master_sim_inst : entity work.axil_master_sim


  ------------------------------------------
  -- Instantiate DUT
  ------------------------------------------

  axil_to_wbus_inst : entity work.axil_to_wbus
    generic map (
      G_TIMEOUT   => 100
    )
    port map (
      clk_i  => clk,
      rst_i  => rst,
      s_axil => axil,
      m_wbus => wbus
    ); -- axil_to_wbus_inst : entity work.axil_to_wbus


  ------------------------------------------
  -- Instantiate Wishbone slave
  ------------------------------------------

  wbus_slave_sim_inst : entity work.wbus_slave_sim
    generic map (
      G_DEBUG     => G_DEBUG
    )
    port map (
      clk_i  => clk,
      rst_i  => rst,
      s_wbus => wbus
    ); -- wbus_slave_sim_inst : entity work.wbus_slave_sim

end architecture simulation;

