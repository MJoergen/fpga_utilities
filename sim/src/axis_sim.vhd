-- ---------------------------------------------------------------------------------------
-- Description: This provides stimulus to and verifies response from an AXI streaming interface.
-- ---------------------------------------------------------------------------------------

library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std.all;

library work;
  use work.axis_pkg.all;

entity axis_sim is
  generic (
    G_SEED     : std_logic_vector(63 downto 0) := x"DEADBEAFC007BABE";
    G_RANDOM   : boolean;
    G_FAST     : boolean;
    G_FIRST    : std_logic                     := 'U';
    G_CNT_SIZE : positive
  );
  port (
    clk_i  : in    std_logic;
    rst_i  : in    std_logic;

    -- Stimulus
    m_axis : view  axis_master_view;

    -- Response
    s_axis : view  axis_slave_view
  );
end entity axis_sim;

architecture simulation of axis_sim is

begin

  axis_master_sim_inst : entity work.axis_master_sim
    generic map (
      G_SEED     => G_SEED,
      G_RANDOM   => G_RANDOM,
      G_FAST     => G_FAST,
      G_FIRST    => G_FIRST,
      G_CNT_SIZE => G_CNT_SIZE
    )
    port map (
      clk_i  => clk_i,
      rst_i  => rst_i,
      m_axis => m_axis
    ); -- axis_master_sim_inst : entity work.axis_master_sim

  axis_slave_sim_inst : entity work.axis_slave_sim
    generic map (
      G_SEED     => G_SEED,
      G_RANDOM   => G_RANDOM,
      G_FIRST    => G_FIRST,
      G_CNT_SIZE => G_CNT_SIZE
    )
    port map (
      clk_i  => clk_i,
      rst_i  => rst_i,
      s_axis => s_axis
    ); -- axis_slave_sim_inst : entity work.axis_slave_sim

end architecture simulation;

