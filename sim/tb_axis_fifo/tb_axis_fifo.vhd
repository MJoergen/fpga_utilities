-- ---------------------------------------------------------------------------------------
-- Description: Verify axis_fifo
-- ---------------------------------------------------------------------------------------

library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std.all;

library work;
  use work.axis_pkg.all;

entity tb_axis_fifo is
  generic (
    G_RAM_DEPTH  : natural;
    G_RANDOM     : boolean;
    G_FAST       : boolean;
    G_CNT_SIZE   : natural;
    G_DATA_BYTES : natural
  );
end entity tb_axis_fifo;

architecture simulation of tb_axis_fifo is

  signal clk : std_logic := '1';
  signal rst : std_logic := '1';

  -- Input to axis_fifo
  signal tx_axis : axis_rec_type (
    data(G_DATA_BYTES * 8 - 1 downto 0)
  );

  -- Output from axis_fifo
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

  axis_fifo_inst : entity work.axis_fifo
    generic map (
      G_RAM_STYLE => "auto",
      G_RAM_DEPTH => G_RAM_DEPTH
    )
    port map (
      clk_i  => clk,
      rst_i  => rst,
      s_axis => rx_axis,
      m_axis => tx_axis
    ); -- axis_fifo_inst : entity work.axis_fifo


  ----------------------------------------------
  -- Generate stimulus and verify response
  ----------------------------------------------

  axis_sim_inst : entity work.axis_sim
    generic map (
      G_RANDOM   => G_RANDOM,
      G_FAST     => G_FAST,
      G_CNT_SIZE => G_CNT_SIZE
    )
    port map (
      clk_i     => clk,
      rst_i     => rst,
      m_axis => rx_axis,
      s_axis => tx_axis
    ); -- axis_sim_inst : entity work.axis_sim

end architecture simulation;

