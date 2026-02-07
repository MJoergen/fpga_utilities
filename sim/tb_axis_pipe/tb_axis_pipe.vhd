-- ---------------------------------------------------------------------------------------
-- Description: Verify axis_pipe
-- ---------------------------------------------------------------------------------------

library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std.all;

library work;
  use work.axis_pkg.all;

entity tb_axis_pipe is
  generic (
    G_RANDOM     : boolean;
    G_FAST       : boolean;
    G_CNT_SIZE   : natural;
    G_DATA_BYTES : natural
  );
end entity tb_axis_pipe;

architecture simulation of tb_axis_pipe is

  signal clk : std_logic := '1';
  signal rst : std_logic := '1';

  -- Input to axis_pipe_lite
  signal tx_axis : axis_rec_type (
    data(G_DATA_BYTES * 8 - 1 downto 0)
  );

  -- Output from axis_pipe_lite
  signal rx_axis : axis_rec_type (
    data(G_DATA_BYTES * 8 - 1 downto 0)
  );

begin

  ----------------------------------------------
  -- Clock and Reset
  ----------------------------------------------

  clk <= not clk after 5 ns;
  rst <= '1', '0' after 100 ns;


  ----------------------------------------------
  -- Instantiate DUT
  ----------------------------------------------

  axis_pipe_inst : entity work.axis_pipe
    port map (
      clk_i  => clk,
      rst_i  => rst,
      s_axis => tx_axis,
      m_axis => rx_axis
    ); -- axis_pipe_inst : entity work.axis_pipe


  ----------------------------------------------
  -- Generate stimulus and verify response
  ----------------------------------------------

  axis_sim_inst : entity work.axis_sim
    generic map (
      G_RANDOM     => G_RANDOM,
      G_FAST       => G_FAST,
      G_CNT_SIZE   => G_CNT_SIZE
    )
    port map (
      clk_i  => clk,
      rst_i  => rst,
      m_axis => tx_axis,
      s_axis => rx_axis
    ); -- axis_sim_inst : entity work.axis_sim

end architecture simulation;

