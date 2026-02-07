-- ---------------------------------------------------------------------------------------
-- Description: Simple testbench for the AXI-Lite to WBUS and WBUS to AXI-Lite converters
-- ---------------------------------------------------------------------------------------

library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std.all;

library work;
  use work.wbus_pkg.all;
  use work.axil_pkg.all;

entity tb_wbus_axil_wbus is
  generic (
    G_DEBUG     : boolean;
    G_ADDR_SIZE : natural;
    G_DATA_SIZE : natural
  );
end entity tb_wbus_axil_wbus;

architecture simulation of tb_wbus_axil_wbus is

  signal wbus_clk : std_logic := '1';
  signal wbus_rst : std_logic := '1';

  signal tb_wbus : wbus_rec_type (
                                  addr(G_ADDR_SIZE - 1 downto 0),
                                  wrdat(G_DATA_SIZE - 1 downto 0),
                                  rddat(G_DATA_SIZE - 1 downto 0)
                                 );

  signal mem_wbus : wbus_rec_type (
                                   addr(G_ADDR_SIZE - 1 downto 0),
                                   wrdat(G_DATA_SIZE - 1 downto 0),
                                   rddat(G_DATA_SIZE - 1 downto 0)
                                  );

  signal axil : axil_rec_type (
                               awaddr(G_ADDR_SIZE - 1 downto 0),
                               wdata(G_DATA_SIZE - 1 downto 0),
                               wstrb(G_DATA_SIZE / 8 - 1 downto 0),
                               araddr(G_ADDR_SIZE - 1 downto 0),
                               rdata(G_DATA_SIZE - 1 downto 0)
                              );

begin

  -------------------------------------
  -- Clock and reset
  -------------------------------------

  wbus_clk <= not wbus_clk after 5 ns;
  wbus_rst <= '1', '0' after 100 ns;


  -------------------------------------
  -- Instantiate DUTs
  -------------------------------------

  wbus_to_axil_inst : entity work.wbus_to_axil
    port map (
      clk_i  => wbus_clk,
      rst_i  => wbus_rst,
      s_wbus => tb_wbus,
      m_axil => axil
    ); -- wbus_to_axil_inst : entity work.wbus_to_axil

  axil_to_wbus_inst : entity work.axil_to_wbus
    generic map (
      G_TIMEOUT => 100
    )
    port map (
      clk_i  => wbus_clk,
      rst_i  => wbus_rst,
      s_axil => axil,
      m_wbus => mem_wbus
    ); -- axil_to_wbus_inst : entity work.axil_to_wbus


  -------------------------------------
  -- Generate stimuli
  -------------------------------------

  wbus_master_sim_inst : entity work.wbus_master_sim
    generic map (
      G_DEBUG  => G_DEBUG,
      G_OFFSET => 1234
    )
    port map (
      clk_i  => wbus_clk,
      rst_i  => wbus_rst,
      m_wbus => tb_wbus
    ); -- wbus_master_sim_inst : entity work.wbus_master_sim

  wbus_slave_sim_inst : entity work.wbus_slave_sim
    generic map (
      G_DEBUG => G_DEBUG
    )
    port map (
      clk_i  => wbus_clk,
      rst_i  => wbus_rst,
      s_wbus => mem_wbus
    ); -- wbus_slave_sim_inst : entity work.wbus_slave_sim

end architecture simulation;

