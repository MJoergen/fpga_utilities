-- ---------------------------------------------------------------------------------------
-- Description:
--
-- SPDX-License-Identifier: MIT
-- ---------------------------------------------------------------------------------------

library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std_unsigned.all;

entity tb_axis_decrease_increase is
  generic (
    G_RANDOM          : boolean;
    G_FAST            : boolean;
    G_DATA_BITS_LARGE : positive;
    G_DATA_BITS_SMALL : positive
  );
end entity tb_axis_decrease_increase;

architecture tb of tb_axis_decrease_increase is

  signal clk : std_logic := '1';
  signal rst : std_logic := '1';

  signal stim_ready   : std_logic;
  signal stim_valid   : std_logic;
  signal stim_data    : std_logic_vector(G_DATA_BITS_LARGE - 1 downto 0);
  signal shrink_ready : std_logic;
  signal shrink_valid : std_logic;
  signal shrink_data  : std_logic_vector(G_DATA_BITS_SMALL - 1 downto 0);
  signal resp_ready   : std_logic;
  signal resp_valid   : std_logic;
  signal resp_data    : std_logic_vector(G_DATA_BITS_LARGE - 1 downto 0);

begin

  ---------------------------------------------------------
  -- Controller clock and reset
  ---------------------------------------------------------

  clk <= not clk after 5 ns;
  rst <= '1', '0' after 100 ns;


  ---------------------------------------------------------
  -- Instantiate DUT: AXIS decrease
  ---------------------------------------------------------

  axis_decrease_inst : entity work.axis_decrease
    generic map (
      G_INPUT_BITS  => G_DATA_BITS_LARGE,
      G_OUTPUT_BITS => G_DATA_BITS_SMALL
    )
    port map (
      clk_i     => clk,
      rst_i     => rst,
      s_ready_o => stim_ready,
      s_valid_i => stim_valid,
      s_data_i  => stim_data,
      m_ready_i => shrink_ready,
      m_valid_o => shrink_valid,
      m_data_o  => shrink_data
    ); -- axis_decrease_inst


  ---------------------------------------------------------
  -- Instantiate DUT: AXIS increase
  ---------------------------------------------------------

  axis_increase_inst : entity work.axis_increase
    generic map (
      G_INPUT_BITS  => G_DATA_BITS_SMALL,
      G_OUTPUT_BITS => G_DATA_BITS_LARGE
    )
    port map (
      clk_i     => clk,
      rst_i     => rst,
      s_ready_o => shrink_ready,
      s_valid_i => shrink_valid,
      s_data_i  => shrink_data,
      m_ready_i => resp_ready,
      m_valid_o => resp_valid,
      m_data_o  => resp_data
    ); -- axis_increase_inst


  ---------------------------------------------------------
  -- Generate stimuli
  ---------------------------------------------------------

  axis_sim_inst : entity work.axis_sim
    generic map (
      G_RANDOM    => G_RANDOM,
      G_FAST      => G_FAST,
      G_DATA_BITS => G_DATA_BITS_LARGE
    )
    port map (
      clk_i     => clk,
      rst_i     => rst,
      m_ready_i => stim_ready,
      m_valid_o => stim_valid,
      m_data_o  => stim_data,
      s_ready_o => resp_ready,
      s_valid_i => resp_valid,
      s_data_i  => resp_data
    ); -- axis_sim_inst

end architecture tb;

