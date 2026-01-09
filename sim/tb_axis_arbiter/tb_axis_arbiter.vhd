-- ---------------------------------------------------------------------------------------
-- Description: Verify axis_arbiter
-- ---------------------------------------------------------------------------------------

library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std.all;

entity tb_axis_arbiter is
  generic (
    G_RANDOM     : boolean;
    G_FAST       : boolean;
    G_CNT_SIZE   : natural;
    G_DATA_BYTES : natural
  );
end entity tb_axis_arbiter;

architecture simulation of tb_axis_arbiter is

  signal clk : std_logic := '1';
  signal rst : std_logic := '1';

  signal s0_ready : std_logic;
  signal s0_valid : std_logic;
  signal s0_data  : std_logic_vector(G_DATA_BYTES * 8 - 1 downto 0);

  signal s1_ready : std_logic;
  signal s1_valid : std_logic;
  signal s1_data  : std_logic_vector(G_DATA_BYTES * 8 - 1 downto 0);

  signal d_ready : std_logic;
  signal d_valid : std_logic;
  signal d_data  : std_logic_vector(G_DATA_BYTES * 8 downto 0);

  signal m0_ready : std_logic;
  signal m0_valid : std_logic;
  signal m0_data  : std_logic_vector(G_DATA_BYTES * 8 - 1 downto 0);

  signal m1_ready : std_logic;
  signal m1_valid : std_logic;
  signal m1_data  : std_logic_vector(G_DATA_BYTES * 8 - 1 downto 0);

begin

  --------------------------------
  -- Clock and Reset
  --------------------------------

  clk <= not clk after 5 ns;
  rst <= '1', '0' after 100 ns;


  --------------------------------
  -- Instantiate DUT
  --------------------------------

  axis_arbiter_inst : entity work.axis_arbiter
    generic map (
      G_DATA_SIZE => G_DATA_BYTES * 8 + 1
    )
    port map (
      clk_i      => clk,
      rst_i      => rst,
      s0_ready_o => s0_ready,
      s0_valid_i => s0_valid,
      s0_data_i  => "0" & s0_data,
      s1_ready_o => s1_ready,
      s1_valid_i => s1_valid,
      s1_data_i  => "1" & s1_data,
      m_ready_i  => d_ready,
      m_valid_o  => d_valid,
      m_data_o   => d_data
    ); -- axis_arbiter_inst : entity work.axis_arbiter


  --------------------------------
  -- Instantiate AXI distributor
  --------------------------------

  axis_distributor_inst : entity work.axis_distributor
    generic map (
      G_DATA_SIZE => G_DATA_BYTES * 8
    )
    port map (
      clk_i      => clk,
      rst_i      => rst,
      s_ready_o  => d_ready,
      s_valid_i  => d_valid,
      s_data_i   => d_data(G_DATA_BYTES * 8 - 1 downto 0),
      s_dst_i    => d_data(G_DATA_BYTES * 8),
      m0_ready_i => m0_ready,
      m0_valid_o => m0_valid,
      m0_data_o  => m0_data,
      m1_ready_i => m1_ready,
      m1_valid_o => m1_valid,
      m1_data_o  => m1_data
    ); -- axis_distributor_inst : entity work.axis_distributor


  --------------------------------
  -- Instantiate AXI streaming stimulus
  --------------------------------

  axis_sim_0_inst : entity work.axis_sim
    generic map (
      G_SEED       => X"1122334455667788",
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
      s_ready_o => m0_ready,
      s_valid_i => m0_valid,
      s_data_i  => m0_data
    ); -- axis_sim_0_inst : entity work.axis_sim

  axis_sim_1_inst : entity work.axis_sim
    generic map (
      G_SEED       => X"1234567812345678",
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
      s_ready_o => m1_ready,
      s_valid_i => m1_valid,
      s_data_i  => m1_data
    ); -- axis_sim_1_inst : entity work.axis_sim

end architecture simulation;

