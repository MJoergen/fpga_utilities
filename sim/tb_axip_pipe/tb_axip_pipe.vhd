-- ---------------------------------------------------------------------------------------
-- Description: Verify axip_pipe
-- ---------------------------------------------------------------------------------------

library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std.all;

entity tb_axip_pipe is
  generic (
    G_DEBUG      : boolean;
    G_RANDOM     : boolean;
    G_FAST       : boolean;
    G_MIN_LENGTH : natural;
    G_MAX_LENGTH : natural;
    G_CNT_SIZE   : natural;
    G_DATA_BYTES : natural
  );
end entity tb_axip_pipe;

architecture simulation of tb_axip_pipe is

  signal clk : std_logic := '1';
  signal rst : std_logic := '1';

  signal s_ready : std_logic;
  signal s_valid : std_logic;
  signal s_data  : std_logic_vector(G_DATA_BYTES * 8 - 1 downto 0);
  signal s_last  : std_logic;
  signal s_bytes : natural range 0 to G_DATA_BYTES;

  signal m_ready : std_logic;
  signal m_valid : std_logic;
  signal m_data  : std_logic_vector(G_DATA_BYTES * 8 - 1 downto 0);
  signal m_last  : std_logic;
  signal m_bytes : natural range 0 to G_DATA_BYTES;

begin

  ----------------------------------------------
  -- Clock and Reset
  ----------------------------------------------

  clk <= not clk after 5 ns;
  rst <= '1', '0' after 100 ns;


  ----------------------------------------------
  -- Instantiate DUT
  ----------------------------------------------

  axip_pipe_inst : entity work.axip_pipe
    generic map (
      G_DATA_BYTES => G_DATA_BYTES
    )
    port map (
      clk_i     => clk,
      rst_i     => rst,
      s_ready_o => s_ready,
      s_valid_i => s_valid,
      s_data_i  => s_data,
      s_last_i  => s_last,
      s_bytes_i => s_bytes,
      m_ready_i => m_ready,
      m_valid_o => m_valid,
      m_data_o  => m_data,
      m_last_o  => m_last,
      m_bytes_o => m_bytes
    ); -- axip_pipe_inst : entity work.axip_pipe


  ----------------------------------------------
  -- Generate stimulus and verify response
  ----------------------------------------------

  axip_sim_inst : entity work.axip_sim
    generic map (
      G_DEBUG      => G_DEBUG,
      G_RANDOM     => G_RANDOM,
      G_FAST       => G_FAST,
      G_MIN_LENGTH => G_MIN_LENGTH,
      G_MAX_LENGTH => G_MAX_LENGTH,
      G_CNT_SIZE   => G_CNT_SIZE,
      G_DATA_BYTES => G_DATA_BYTES
    )
    port map (
      clk_i     => clk,
      rst_i     => rst,
      m_ready_i => s_ready,
      m_valid_o => s_valid,
      m_data_o  => s_data,
      m_last_o  => s_last,
      m_bytes_o => s_bytes,
      s_ready_o => m_ready,
      s_valid_i => m_valid,
      s_data_i  => m_data,
      s_last_i  => m_last,
      s_bytes_i => m_bytes
    ); -- axip_sim_inst : entity work.axip_sim

end architecture simulation;

