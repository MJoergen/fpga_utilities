-- ---------------------------------------------------------------------------------------
-- Description: Generates a stream of random packets and verifies the response.
-- ---------------------------------------------------------------------------------------

library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std.all;

entity axip_sim is
  generic (
    G_SEED       : std_logic_vector(63 downto 0) := X"DEADBEAFC007BABE";
    G_NAME       : string                        := "";
    G_DEBUG      : boolean;
    G_RANDOM     : boolean;
    G_FAST       : boolean;
    G_MIN_LENGTH : natural;
    G_MAX_LENGTH : natural;
    G_CNT_SIZE   : natural;
    G_DATA_BYTES : natural
  );
  port (
    clk_i     : in    std_logic;
    rst_i     : in    std_logic;

    -- AXI packet output
    m_ready_i : in    std_logic;
    m_valid_o : out   std_logic;
    m_data_o  : out   std_logic_vector(G_DATA_BYTES * 8 - 1 downto 0);
    m_last_o  : out   std_logic;
    m_bytes_o : out   natural range 0 to G_DATA_BYTES;

    -- AXI packet input
    s_ready_o : out   std_logic;
    s_valid_i : in    std_logic;
    s_data_i  : in    std_logic_vector(G_DATA_BYTES * 8 - 1 downto 0);
    s_last_i  : in    std_logic;
    s_bytes_i : in    natural range 0 to G_DATA_BYTES
  );
end entity axip_sim;

architecture simulation of axip_sim is

begin

  axip_master_sim_inst : entity work.axip_master_sim
    generic map (
      G_SEED       => G_SEED,
      G_NAME       => G_NAME,
      G_DEBUG      => G_DEBUG,
      G_RANDOM     => G_RANDOM,
      G_FAST       => G_FAST,
      G_MIN_LENGTH => G_MIN_LENGTH,
      G_MAX_LENGTH => G_MAX_LENGTH,
      G_CNT_SIZE   => G_CNT_SIZE,
      G_DATA_BYTES => G_DATA_BYTES
    )
    port map (
      clk_i     => clk_i,
      rst_i     => rst_i,
      m_ready_i => m_ready_i,
      m_valid_o => m_valid_o,
      m_data_o  => m_data_o,
      m_last_o  => m_last_o,
      m_bytes_o => m_bytes_o
    ); -- axip_master_sim_inst : entity work.axip_master_sim

  axip_slave_sim_inst : entity work.axip_slave_sim
    generic map (
      G_SEED       => G_SEED,
      G_NAME       => G_NAME,
      G_DEBUG      => G_DEBUG,
      G_RANDOM     => G_RANDOM,
      G_MIN_LENGTH => G_MIN_LENGTH,
      G_MAX_LENGTH => G_MAX_LENGTH,
      G_CNT_SIZE   => G_CNT_SIZE,
      G_DATA_BYTES => G_DATA_BYTES
    )
    port map (
      clk_i     => clk_i,
      rst_i     => rst_i,
      s_ready_o => s_ready_o,
      s_valid_i => s_valid_i,
      s_data_i  => s_data_i,
      s_last_i  => s_last_i,
      s_bytes_i => s_bytes_i
    ); -- axip_slave_sim_inst : entity work.axip_slave_sim

end architecture simulation;

