-- ---------------------------------------------------------------------------------------
-- Description: This provides stimulus to and verifies response from an AXI lite
-- interface.  It generates a sequence of Writes and Reads, and verifies that the values
-- returned from Read matches the corresponding values during Write.
-- ---------------------------------------------------------------------------------------

library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std.all;

library work;
  use work.axil_pkg.all;

entity axil_sim is
  generic (
    G_SEED   : std_logic_vector(63 downto 0) := x"DEADBEEFC007BABE";
    G_OFFSET : natural;
    G_DEBUG  : boolean;
    G_RANDOM : boolean;
    G_FAST   : boolean
  );
  port (
    clk_i  : in    std_logic;
    rst_i  : in    std_logic;
    m_axil : view  axil_master_view;
    s_axil : view  axil_slave_view
  );
end entity axil_sim;

architecture simulation of axil_sim is

begin

  axil_master_sim_inst : entity work.axil_master_sim
    generic map (
      G_SEED   => G_SEED,
      G_OFFSET => G_OFFSET,
      G_DEBUG  => G_DEBUG,
      G_RANDOM => G_RANDOM,
      G_FAST   => G_FAST
    )
    port map (
      clk_i  => clk_i,
      rst_i  => rst_i,
      m_axil => m_axil
    ); -- axil_master_sim_inst : entity work.axil_master_sim

  axil_slave_sim_inst : entity work.axil_slave_sim
    generic map (
      G_DEBUG => G_DEBUG,
      G_FAST  => G_FAST
    )
    port map (
      clk_i  => clk_i,
      rst_i  => rst_i,
      s_axil => s_axil
    ); -- axil_slave_sim_inst : entity work.axil_slave_sim

end architecture simulation;

