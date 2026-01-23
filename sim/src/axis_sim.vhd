-- ---------------------------------------------------------------------------------------
-- Description: This provides stimulus to and verifies response from an AXI streaming interface.
-- ---------------------------------------------------------------------------------------

library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std.all;

entity axis_sim is
  generic (
    G_SEED       : std_logic_vector(63 downto 0) := X"DEADBEAFC007BABE";
    G_RANDOM     : boolean;
    G_FAST       : boolean;
    G_CNT_SIZE   : positive;
    G_DATA_BYTES : positive
  );
  port (
    clk_i     : in    std_logic;
    rst_i     : in    std_logic;

    -- Stimulus
    m_ready_i : in    std_logic;
    m_valid_o : out   std_logic;
    m_data_o  : out   std_logic_vector(G_DATA_BYTES * 8 - 1 downto 0);

    -- Response
    s_ready_o : out   std_logic;
    s_valid_i : in    std_logic;
    s_data_i  : in    std_logic_vector(G_DATA_BYTES * 8 - 1 downto 0)
  );
end entity axis_sim;

architecture simulation of axis_sim is

begin

  axis_master_sim_inst : entity work.axis_master_sim
    generic map (
      G_SEED       => G_SEED,
      G_RANDOM     => G_RANDOM,
      G_FAST       => G_FAST,
      G_CNT_SIZE   => G_CNT_SIZE,
      G_DATA_BYTES => G_DATA_BYTES
    )
    port map (
      clk_i     => clk_i,
      rst_i     => rst_i,
      m_ready_i => m_ready_i,
      m_valid_o => m_valid_o,
      m_data_o  => m_data_o
    ); -- axis_master_sim_inst : entity work.axis_master_sim

  axis_slave_sim_inst : entity work.axis_slave_sim
    generic map (
      G_SEED       => G_SEED,
      G_RANDOM     => G_RANDOM,
      G_CNT_SIZE   => G_CNT_SIZE,
      G_DATA_BYTES => G_DATA_BYTES
    )
    port map (
      clk_i     => clk_i,
      rst_i     => rst_i,
      s_ready_o => s_ready_o,
      s_valid_i => s_valid_i,
      s_data_i  => s_data_i
    ); -- axis_slave_sim_inst : entity work.axis_slave_sim

end architecture simulation;

