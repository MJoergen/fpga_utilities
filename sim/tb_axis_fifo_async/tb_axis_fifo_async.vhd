-- ---------------------------------------------------------------------------------------
-- Description: Verify axis_fifo_async
--
-- SPDX-License-Identifier: MIT
-- ---------------------------------------------------------------------------------------

library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std.all;

entity tb_axis_fifo_async is
  generic (
    G_RATIO     : natural;
    G_RANDOM    : boolean;
    G_FAST      : boolean;
    G_ADDR_BITS : natural;
    G_DATA_BITS : natural
  );
end entity tb_axis_fifo_async;

architecture tb of tb_axis_fifo_async is

  signal   async_rst : std_logic := '1';

  signal   s_clk   : std_logic   := '1';
  signal   s_rst   : std_logic   := '1';
  signal   s_ready : std_logic;
  signal   s_valid : std_logic;
  signal   s_data  : std_logic_vector(G_DATA_BITS - 1 downto 0);
  signal   s_fill  : natural range 0 to 2 ** G_ADDR_BITS;

  signal   m_clk   : std_logic   := '1';
  signal   m_rst   : std_logic   := '1';
  signal   m_ready : std_logic;
  signal   m_valid : std_logic;
  signal   m_data  : std_logic_vector(G_DATA_BITS - 1 downto 0);
  signal   m_fill  : natural range 0 to 2 ** G_ADDR_BITS;

  constant C_S_PERIOD : time     := 5 ns;
  constant C_M_PERIOD : time     := (C_S_PERIOD * G_RATIO) / 100;

begin

  ----------------------------------------------
  -- Clock and Reset
  ----------------------------------------------

  s_clk <= not s_clk after C_S_PERIOD;
  m_clk <= not m_clk after C_M_PERIOD;

  async_rst <= '1', '0' after 120 ns;

  s_rst <= async_rst when rising_edge(s_clk);
  m_rst <= async_rst when rising_edge(m_clk);


  ----------------------------------------------
  -- Instantiate DUT
  ----------------------------------------------

  axis_fifo_async_inst : entity work.axis_fifo_async
    generic map (
      G_ADDR_BITS => G_ADDR_BITS,
      G_DATA_BITS => G_DATA_BITS
    )
    port map (
      async_rst_i => async_rst,
      s_clk_i     => s_clk,
      s_ready_o   => s_ready,
      s_valid_i   => s_valid,
      s_data_i    => s_data,
      s_fill_o    => s_fill,
      m_clk_i     => m_clk,
      m_ready_i   => m_ready,
      m_valid_o   => m_valid,
      m_data_o    => m_data,
      m_fill_o    => m_fill
    ); -- axis_fifo_async_inst : entity work.axis_fifo_async


  ----------------------------------------------
  -- Generate stimulus
  ----------------------------------------------

  axis_master_sim_inst : entity work.axis_master_sim
    generic map (
      G_RANDOM    => G_RANDOM,
      G_FAST      => G_FAST,
      G_DATA_BITS => G_DATA_BITS
    )
    port map (
      clk_i     => s_clk,
      rst_i     => s_rst,
      m_ready_i => s_ready,
      m_valid_o => s_valid,
      m_data_o  => s_data
    ); -- axis_master_sim_inst : entity work.axis_master_sim


  ----------------------------------------------
  -- Verify response
  ----------------------------------------------

  axis_slave_sim_inst : entity work.axis_slave_sim
    generic map (
      G_RANDOM    => G_RANDOM,
      G_DATA_BITS => G_DATA_BITS
    )
    port map (
      clk_i     => m_clk,
      rst_i     => m_rst,
      s_ready_o => m_ready,
      s_valid_i => m_valid,
      s_data_i  => m_data
    ); -- axis_slave_sim_inst : entity work.axis_slave_sim

end architecture tb;

