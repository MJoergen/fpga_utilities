-- ---------------------------------------------------------------------------------------
-- Description: Verify axis_fifo_async
-- ---------------------------------------------------------------------------------------

library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std.all;

library work;
  use work.axis_pkg.all;

entity tb_axis_pipe_async is
  generic (
    G_RATIO      : natural;
    G_PIPE_SIZE  : natural;
    G_RANDOM     : boolean;
    G_FAST       : boolean;
    G_CNT_SIZE   : natural;
    G_DATA_BYTES : natural
  );
end entity tb_axis_pipe_async;

architecture simulation of tb_axis_pipe_async is

  constant C_S_PERIOD : time  := 5 ns;
  constant C_M_PERIOD : time  := (C_S_PERIOD * G_RATIO) / 100;

  signal   s_clk : std_logic  := '1';
  signal   s_rst : std_logic  := '1';

  signal   s_axis : axis_rec_type (
                                   data(G_DATA_BYTES * 8 - 1 downto 0)
                                  );
  signal   m_clk  : std_logic := '1';
  signal   m_rst  : std_logic := '1';

  signal   m_axis : axis_rec_type (
                                   data(G_DATA_BYTES * 8 - 1 downto 0)
                                  );

begin

  ----------------------------------------------
  -- Clock and Reset
  ----------------------------------------------

  s_clk <= not s_clk after C_S_PERIOD;
  s_rst <= '1', '0' after 100 ns;

  m_clk <= not m_clk after C_M_PERIOD;
  m_rst <= '1', '0' after 100 ns;


  ----------------------------------------------
  -- Instantiate DUT
  ----------------------------------------------

  axis_pipe_async_inst : entity work.axis_pipe_async
    generic map (
      G_PIPE_SIZE => G_PIPE_SIZE
    )
    port map (
      s_clk_i   => s_clk,
      s_axis    => s_axis,
      m_clk_i   => m_clk,
      m_axis    => m_axis
    ); -- axis_pipe_async_inst : entity work.axis_pipe_async


  ----------------------------------------------
  -- Generate stimulus
  ----------------------------------------------

  axis_master_sim_inst : entity work.axis_master_sim
    generic map (
      G_RANDOM   => G_RANDOM,
      G_FAST     => G_FAST,
      G_CNT_SIZE => G_CNT_SIZE
    )
    port map (
      clk_i  => s_clk,
      rst_i  => s_rst,
      m_axis => s_axis
    ); -- axis_master_sim_inst : entity work.axis_master_sim


  ----------------------------------------------
  -- Verify response
  ----------------------------------------------

  axis_slave_sim_inst : entity work.axis_slave_sim
    generic map (
      G_RANDOM   => G_RANDOM,
      G_CNT_SIZE => G_CNT_SIZE
    )
    port map (
      clk_i  => m_clk,
      rst_i  => m_rst,
      s_axis => m_axis
    ); -- axis_slave_sim_inst : entity work.axis_slave_sim

end architecture simulation;

