-- ---------------------------------------------------------------------------------------
-- Description: Verify axis_fifo_async
-- ---------------------------------------------------------------------------------------

library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std.all;

library work;
  use work.axip_pkg.all;

entity tb_axip_pipe_async is
  generic (
    G_DEBUG      : boolean;
    G_MIN_LENGTH : positive;
    G_MAX_LENGTH : positive;
    G_RATIO      : positive;
    G_PIPE_SIZE  : positive;
    G_RANDOM     : boolean;
    G_FAST       : boolean;
    G_CNT_SIZE   : positive;
    G_DATA_BYTES : positive
  );
end entity tb_axip_pipe_async;

architecture simulation of tb_axip_pipe_async is

  signal   s_clk : std_logic := '1';
  signal   s_rst : std_logic := '1';

  signal   m_clk : std_logic := '1';
  signal   m_rst : std_logic := '1';

  signal   s_axip : axip_rec_type (
                                   data(G_DATA_BYTES * 8 - 1 downto 0)
                                  );

  signal   m_axip : axip_rec_type (
                                   data(G_DATA_BYTES * 8 - 1 downto 0)
                                  );

  constant C_S_PERIOD : time := 5 ns;
  constant C_M_PERIOD : time := (C_S_PERIOD * G_RATIO) / 100;

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

  axip_pipe_async_inst : entity work.axip_pipe_async
    generic map (
      G_PIPE_SIZE => G_PIPE_SIZE
    )
    port map (
      s_clk_i => s_clk,
      s_axip  => s_axip,
      m_clk_i => m_clk,
      m_axip  => m_axip
    ); -- axip_pipe_async_inst : entity work.axip_pipe_async


  ----------------------------------------------
  -- Generate stimulus
  ----------------------------------------------

  axip_master_sim_inst : entity work.axip_master_sim
    generic map (
      G_DEBUG      => G_DEBUG,
      G_MIN_LENGTH => G_MIN_LENGTH,
      G_MAX_LENGTH => G_MAX_LENGTH,
      G_RANDOM     => G_RANDOM,
      G_FAST       => G_FAST,
      G_CNT_SIZE   => G_CNT_SIZE
    )
    port map (
      clk_i  => s_clk,
      rst_i  => s_rst,
      m_axip => s_axip
    ); -- axip_master_sim_inst : entity work.axip_master_sim


  ----------------------------------------------
  -- Verify response
  ----------------------------------------------

  axip_slave_sim_inst : entity work.axip_slave_sim
    generic map (
      G_DEBUG      => G_DEBUG,
      G_MIN_LENGTH => G_MIN_LENGTH,
      G_MAX_LENGTH => G_MAX_LENGTH,
      G_RANDOM     => G_RANDOM,
      G_CNT_SIZE   => G_CNT_SIZE
    )
    port map (
      clk_i  => m_clk,
      rst_i  => m_rst,
      s_axip => m_axip
    ); -- axip_slave_sim_inst : entity work.axip_slave_sim

end architecture simulation;

