-- ---------------------------------------------------------------------------------------
-- Description: Verify axis_arbiter
-- ---------------------------------------------------------------------------------------

library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std.all;

entity tb_axip_arbiter is
  generic (
    G_RANDOM     : boolean;
    G_DEBUG      : boolean;
    G_MIN_LENGTH : natural;
    G_MAX_LENGTH : natural;
    G_FAST       : boolean;
    G_CNT_SIZE   : natural;
    G_DATA_BYTES : natural
  );
end entity tb_axip_arbiter;

architecture simulation of tb_axip_arbiter is

  signal clk : std_logic := '1';
  signal rst : std_logic := '1';

  signal s0_ready : std_logic;
  signal s0_valid : std_logic;
  signal s0_data  : std_logic_vector(G_DATA_BYTES * 8 - 1 downto 0);
  signal s0_last  : std_logic;
  signal s0_bytes : natural range 0 to G_DATA_BYTES;

  signal s1_ready : std_logic;
  signal s1_valid : std_logic;
  signal s1_data  : std_logic_vector(G_DATA_BYTES * 8 - 1 downto 0);
  signal s1_last  : std_logic;
  signal s1_bytes : natural range 0 to G_DATA_BYTES;

  signal d_ready : std_logic;
  signal d_valid : std_logic;
  signal d_data  : std_logic_vector(G_DATA_BYTES * 8 - 1 downto 0);
  signal d_last  : std_logic;
  signal d_bytes : natural range 0 to G_DATA_BYTES;

  signal sh0_ready : std_logic;
  signal sh0_valid : std_logic;
  signal sh0_data  : std_logic_vector(G_DATA_BYTES * 8 - 1 downto 0);
  signal sh0_last  : std_logic;
  signal sh0_bytes : natural range 0 to G_DATA_BYTES;

  signal sh1_ready : std_logic;
  signal sh1_valid : std_logic;
  signal sh1_data  : std_logic_vector(G_DATA_BYTES * 8 - 1 downto 0);
  signal sh1_last  : std_logic;
  signal sh1_bytes : natural range 0 to G_DATA_BYTES;

  signal dh_ready : std_logic;
  signal dh_valid : std_logic;
  signal dh_data  : std_logic_vector(G_DATA_BYTES * 8 - 1 downto 0);
  signal dh_last  : std_logic;
  signal dh_bytes : natural range 0 to G_DATA_BYTES;

  signal m0_ready : std_logic;
  signal m0_valid : std_logic;
  signal m0_data  : std_logic_vector(G_DATA_BYTES * 8 - 1 downto 0);
  signal m0_last  : std_logic;
  signal m0_bytes : natural range 0 to G_DATA_BYTES;

  signal m1_ready : std_logic;
  signal m1_valid : std_logic;
  signal m1_data  : std_logic_vector(G_DATA_BYTES * 8 - 1 downto 0);
  signal m1_last  : std_logic;
  signal m1_bytes : natural range 0 to G_DATA_BYTES;

  signal h_valid : std_logic;
  signal h_data  : std_logic_vector(7 downto 0);

begin

  --------------------------------
  -- Clock and Reset
  --------------------------------

  clk <= not clk after 5 ns;
  rst <= '1', '0' after 100 ns;


  --------------------------------
  -- Instantiate DUT
  --------------------------------

  axip_arbiter_inst : entity work.axip_arbiter
    generic map (
      G_DATA_BYTES => G_DATA_BYTES
    )
    port map (
      clk_i      => clk,
      rst_i      => rst,
      s0_ready_o => sh0_ready,
      s0_valid_i => sh0_valid,
      s0_data_i  => sh0_data,
      s0_last_i  => sh0_last,
      s0_bytes_i => sh0_bytes,
      s1_ready_o => sh1_ready,
      s1_valid_i => sh1_valid,
      s1_data_i  => sh1_data,
      s1_last_i  => sh1_last,
      s1_bytes_i => sh1_bytes,
      m_ready_i  => d_ready,
      m_valid_o  => d_valid,
      m_data_o   => d_data,
      m_last_o   => d_last,
      m_bytes_o  => d_bytes
    ); -- axip_arbiter_inst : entity work.axip_arbiter

  axip_remove_fixed_header_inst : entity work.axip_remove_fixed_header
    generic map (
      G_DATA_BYTES   => G_DATA_BYTES,
      G_HEADER_BYTES => 1
    )
    port map (
      clk_i     => clk,
      rst_i     => rst,
      s_ready_o => d_ready,
      s_valid_i => d_valid,
      s_data_i  => d_data,
      s_last_i  => d_last,
      s_bytes_i => d_bytes,
      m_ready_i => dh_ready,
      m_valid_o => dh_valid,
      m_data_o  => dh_data,
      m_last_o  => dh_last,
      m_bytes_o => dh_bytes,
      h_ready_i => '1',
      h_valid_o => h_valid,
      h_data_o  => h_data
    ); -- axip_remove_fixed_header_inst : entity work.axip_remove_fixed_header


  --------------------------------
  -- Instantiate AXI distributor
  --------------------------------

  axip_distributor_inst : entity work.axip_distributor
    generic map (
      G_DATA_BYTES => G_DATA_BYTES
    )
    port map (
      clk_i      => clk,
      rst_i      => rst,
      s_ready_o  => dh_ready,
      s_valid_i  => dh_valid,
      s_data_i   => dh_data(G_DATA_BYTES * 8 - 1 downto 0),
      s_last_i   => dh_last,
      s_bytes_i  => dh_bytes,
      s_dst_i    => h_data(0),
      m0_ready_i => m0_ready,
      m0_valid_o => m0_valid,
      m0_data_o  => m0_data,
      m0_last_o  => m0_last,
      m0_bytes_o => m0_bytes,
      m1_ready_i => m1_ready,
      m1_valid_o => m1_valid,
      m1_data_o  => m1_data,
      m1_last_o  => m1_last,
      m1_bytes_o => m1_bytes
    ); -- axis_distributor_inst : entity work.axis_distributor


  --------------------------------
  -- Instantiate AXI streaming stimulus
  --------------------------------

  axip_sim_0_inst : entity work.axip_sim
    generic map (
      G_SEED       => X"1122334455667788",
      G_NAME       => "0",
      G_DEBUG      => G_DEBUG,
      G_MIN_LENGTH => G_MIN_LENGTH,
      G_MAX_LENGTH => G_MAX_LENGTH,
      G_RANDOM     => G_RANDOM,
      G_FAST       => G_FAST,
      G_CNT_SIZE   => G_CNT_SIZE,
      G_DATA_BYTES => G_DATA_BYTES
    )
    port map (
      clk_i     => clk,
      rst_i     => rst,
      m_ready_i => s0_ready,
      m_valid_o => s0_valid,
      m_data_o  => s0_data,
      m_last_o  => s0_last,
      m_bytes_o => s0_bytes,
      s_ready_o => m0_ready,
      s_valid_i => m0_valid,
      s_data_i  => m0_data,
      s_last_i  => m0_last,
      s_bytes_i => m0_bytes
    ); -- axip_sim_0_inst : entity work.axip_sim

  axip_insert_fixed_header_0_inst : entity work.axip_insert_fixed_header
    generic map (
      G_DATA_BYTES   => G_DATA_BYTES,
      G_HEADER_BYTES => 1
    )
    port map (
      clk_i     => clk,
      rst_i     => rst,
      h_ready_o => open,
      h_valid_i => '1',
      h_data_i  => X"00",
      s_ready_o => s0_ready,
      s_valid_i => s0_valid,
      s_data_i  => s0_data,
      s_last_i  => s0_last,
      s_bytes_i => s0_bytes,
      m_ready_i => sh0_ready,
      m_valid_o => sh0_valid,
      m_data_o  => sh0_data,
      m_last_o  => sh0_last,
      m_bytes_o => sh0_bytes
    ); -- axip_insert_fixed_header_0_inst : entity work.axip_insert_fixed_header


  axip_sim_1_inst : entity work.axip_sim
    generic map (
      G_SEED       => X"1234567812345678",
      G_NAME       => "1",
      G_DEBUG      => G_DEBUG,
      G_MIN_LENGTH => G_MIN_LENGTH,
      G_MAX_LENGTH => G_MAX_LENGTH,
      G_RANDOM     => G_RANDOM,
      G_FAST       => G_FAST,
      G_CNT_SIZE   => G_CNT_SIZE,
      G_DATA_BYTES => G_DATA_BYTES
    )
    port map (
      clk_i     => clk,
      rst_i     => rst,
      m_ready_i => s1_ready,
      m_valid_o => s1_valid,
      m_data_o  => s1_data,
      m_last_o  => s1_last,
      m_bytes_o => s1_bytes,
      s_ready_o => m1_ready,
      s_valid_i => m1_valid,
      s_data_i  => m1_data,
      s_last_i  => m1_last,
      s_bytes_i => m1_bytes
    ); -- axip_sim_1_inst : entity work.axip_sim

  axip_insert_fixed_header_1_inst : entity work.axip_insert_fixed_header
    generic map (
      G_DATA_BYTES   => G_DATA_BYTES,
      G_HEADER_BYTES => 1
    )
    port map (
      clk_i     => clk,
      rst_i     => rst,
      h_ready_o => open,
      h_valid_i => '1',
      h_data_i  => X"FF",
      s_ready_o => s1_ready,
      s_valid_i => s1_valid,
      s_data_i  => s1_data,
      s_last_i  => s1_last,
      s_bytes_i => s1_bytes,
      m_ready_i => sh1_ready,
      m_valid_o => sh1_valid,
      m_data_o  => sh1_data,
      m_last_o  => sh1_last,
      m_bytes_o => sh1_bytes
    ); -- axip_insert_fixed_header_1_inst : entity work.axip_insert_fixed_header

end architecture simulation;

