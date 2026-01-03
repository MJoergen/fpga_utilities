library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std_unsigned.all;

library std;
  use std.env.stop;

entity tb_axip_fixed_header is
  generic (
    G_PAUSE_SIZE   : natural;
    G_DEBUG        : boolean;
    G_MAX_LENGTH   : natural;
    G_CNT_SIZE     : natural;
    G_FAST         : boolean;
    G_RANDOM       : boolean;
    G_DATA_BYTES   : natural;
    G_HEADER_BYTES : natural
  );
end entity tb_axip_fixed_header;

architecture simulation of tb_axip_fixed_header is

  signal   clk : std_logic  := '1';
  signal   rst : std_logic  := '1';

  signal   tb_m_ready : std_logic;
  signal   tb_m_valid : std_logic;
  signal   tb_m_data  : std_logic_vector(G_DATA_BYTES * 8 - 1 downto 0);
  signal   tb_m_last  : std_logic;
  signal   tb_m_bytes : natural range 0 to G_DATA_BYTES;

  signal   tb_s_ready : std_logic;
  signal   tb_s_valid : std_logic;
  signal   tb_s_data  : std_logic_vector(G_DATA_BYTES * 8 - 1 downto 0);
  signal   tb_s_last  : std_logic;
  signal   tb_s_bytes : natural range 0 to G_DATA_BYTES;

  signal   h_ready : std_logic;
  signal   h_valid : std_logic;
  signal   h_data  : std_logic_vector(G_HEADER_BYTES * 8 - 1 downto 0);

  signal   d_ready : std_logic;
  signal   d_valid : std_logic;
  signal   d_data  : std_logic_vector(G_DATA_BYTES * 8 - 1 downto 0);
  signal   d_last  : std_logic;
  signal   d_bytes : natural range 0 to G_DATA_BYTES;

  signal   h_pause_ready : std_logic;
  signal   h_pause_valid : std_logic;
  signal   h_pause_data  : std_logic_vector(G_HEADER_BYTES * 8 - 1 downto 0);

  signal   d_pause_ready : std_logic;
  signal   d_pause_valid : std_logic;
  signal   d_pause_data  : std_logic_vector(G_DATA_BYTES * 8 - 1 downto 0);
  signal   d_pause_last  : std_logic;
  signal   d_pause_bytes : natural range 0 to G_DATA_BYTES;

begin

  --------------------------------------------
  -- Clock and reset
  --------------------------------------------

  clk <= not clk after 5 ns;
  rst <= '1', '0' after 100 ns;


  --------------------------------------------
  -- Instantiate first DUT
  --------------------------------------------

  axip_remove_fixed_header_inst : entity work.axip_remove_fixed_header
    generic map (
      G_DATA_BYTES   => G_DATA_BYTES,
      G_HEADER_BYTES => G_HEADER_BYTES
    )
    port map (
      clk_i     => clk,
      rst_i     => rst,
      s_ready_o => tb_m_ready,
      s_valid_i => tb_m_valid,
      s_data_i  => tb_m_data,
      s_last_i  => tb_m_last,
      s_bytes_i => tb_m_bytes,
      m_ready_i => d_ready,
      m_valid_o => d_valid,
      m_data_o  => d_data,
      m_last_o  => d_last,
      m_bytes_o => d_bytes,
      h_ready_i => h_ready,
      h_valid_o => h_valid,
      h_data_o  => h_data
    ); -- axip_remove_fixed_header_inst : entity work.axip_remove_fixed_header


  --------------------------------------------
  -- Instantiate random breaks in stream
  --------------------------------------------

  axis_pause_h_inst : entity work.axis_pause
    generic map (
      G_SEED       => X"0011223344556677",
      G_DATA_SIZE  => G_HEADER_BYTES * 8,
      G_PAUSE_SIZE => G_PAUSE_SIZE
    )
    port map (
      clk_i     => clk,
      rst_i     => rst,
      s_ready_o => h_ready,
      s_valid_i => h_valid,
      s_data_i  => h_data,
      m_ready_i => h_pause_ready,
      m_valid_o => h_pause_valid,
      m_data_o  => h_pause_data
    ); -- axis_pause_h_inst : entity work.axis_pause

  axip_pause_d_inst : entity work.axip_pause
    generic map (
      G_SEED       => X"0123456701234567",
      G_DATA_BYTES => G_DATA_BYTES,
      G_PAUSE_SIZE => G_PAUSE_SIZE
    )
    port map (
      clk_i     => clk,
      rst_i     => rst,
      s_ready_o => d_ready,
      s_valid_i => d_valid,
      s_data_i  => d_data,
      s_last_i  => d_last,
      s_bytes_i => d_bytes,
      m_ready_i => d_pause_ready,
      m_valid_o => d_pause_valid,
      m_data_o  => d_pause_data,
      m_last_o  => d_pause_last,
      m_bytes_o => d_pause_bytes
    ); -- axis_pause_d_inst : entity work.axis_pause


  --------------------------------------------
  -- Instantiate second DUT
  --------------------------------------------

  axip_insert_fixed_header_inst : entity work.axip_insert_fixed_header
    generic map (
      G_DATA_BYTES   => G_DATA_BYTES,
      G_HEADER_BYTES => G_HEADER_BYTES
    )
    port map (
      clk_i     => clk,
      rst_i     => rst,
      h_ready_o => h_pause_ready,
      h_valid_i => h_pause_valid,
      h_data_i  => h_pause_data,
      s_ready_o => d_pause_ready,
      s_valid_i => d_pause_valid,
      s_data_i  => d_pause_data,
      s_last_i  => d_pause_last,
      s_bytes_i => d_pause_bytes,
      m_ready_i => tb_s_ready,
      m_valid_o => tb_s_valid,
      m_data_o  => tb_s_data,
      m_last_o  => tb_s_last,
      m_bytes_o => tb_s_bytes
    ); -- axip_insert_fixed_header_inst : entity work.axip_insert_fixed_header


  --------------------------------------------
  -- Generate stimuli and verify response
  --------------------------------------------

  axip_sim_inst : entity work.axip_sim
    generic map (
      G_DEBUG      => G_DEBUG,
      G_RANDOM     => G_RANDOM,
      G_FAST       => G_FAST,
      G_MIN_LENGTH => G_HEADER_BYTES,
      G_MAX_LENGTH => G_MAX_LENGTH,
      G_CNT_SIZE   => G_CNT_SIZE,
      G_DATA_BYTES => G_DATA_BYTES
    )
    port map (
      clk_i     => clk,
      rst_i     => rst,
      m_ready_i => tb_m_ready,
      m_valid_o => tb_m_valid,
      m_data_o  => tb_m_data,
      m_last_o  => tb_m_last,
      m_bytes_o => tb_m_bytes,
      s_ready_o => tb_s_ready,
      s_valid_i => tb_s_valid,
      s_data_i  => tb_s_data,
      s_last_i  => tb_s_last,
      s_bytes_i => tb_s_bytes
    ); -- axip_sim_inst : entity work.axip_sim

end architecture simulation;

