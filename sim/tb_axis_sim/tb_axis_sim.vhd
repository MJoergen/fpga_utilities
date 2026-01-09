-- ---------------------------------------------------------------------------------------
-- Description: Verify axis_sim
-- ---------------------------------------------------------------------------------------

library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std.all;

library std;
  use std.env.stop;

entity tb_axis_sim is
  generic (
    G_PAUSE_SIZE : natural;
    G_RAM_DEPTH  : natural;
    G_RANDOM     : boolean;
    G_FAST       : boolean;
    G_CNT_SIZE   : natural;
    G_DATA_BYTES : natural
  );
end entity tb_axis_sim;

architecture simulation of tb_axis_sim is

  signal clk : std_logic := '1';
  signal rst : std_logic := '1';

  signal s_ready : std_logic;
  signal s_valid : std_logic;
  signal s_data  : std_logic_vector(G_DATA_BYTES * 8 - 1 downto 0);

  signal m_ready : std_logic;
  signal m_valid : std_logic;
  signal m_data  : std_logic_vector(G_DATA_BYTES * 8 - 1 downto 0);

begin

  ----------------------------------------------
  -- Clock and Reset
  ----------------------------------------------

  clk <= not clk after 5 ns;
  rst <= '1', '0' after 100 ns;


  ----------------------------------------------
  -- Instantiate DUT
  ----------------------------------------------

  axis_sim_inst : entity work.axis_sim
    generic map (
      G_RANDOM     => G_RANDOM,
      G_FAST       => G_FAST,
      G_CNT_SIZE   => G_CNT_SIZE,
      G_DATA_BYTES => G_DATA_BYTES
    )
    port map (
      clk_i     => clk,
      rst_i     => rst,
      m_ready_i => m_ready,
      m_valid_o => m_valid,
      m_data_o  => m_data,
      s_ready_o => s_ready,
      s_valid_i => s_valid,
      s_data_i  => s_data
    ); -- axis_sim_inst : entity work.axis_sim


  ----------------------------------------------
  -- Add additional random delays
  ----------------------------------------------

  axis_pause_inst : entity work.axis_pause
    generic map (
      G_SEED       => X"CAFEBABE666B00B5",
      G_DATA_SIZE  => G_DATA_BYTES * 8,
      G_PAUSE_SIZE => G_PAUSE_SIZE
    )
    port map (
      clk_i     => clk,
      rst_i     => rst,
      s_ready_o => m_ready,
      s_valid_i => m_valid,
      s_data_i  => m_data,
      m_ready_i => s_ready,
      m_valid_o => s_valid,
      m_data_o  => s_data
    ); -- axis_pause_inst : entity work.axis_pause

end architecture simulation;

