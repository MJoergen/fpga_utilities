-- ---------------------------------------------------------------------------------------
-- Description: A simple testbench to verify the two converters: axip_to_axis.vhd and
-- axis_to_axip.vhd.
-- ---------------------------------------------------------------------------------------

library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std.all;

entity tb_axip_axis_axip is
  generic (
    G_PAUSE_SIZE : natural;
    G_DEBUG      : boolean;
    G_RANDOM     : boolean;
    G_FAST       : boolean;
    G_MIN_LENGTH : natural;
    G_MAX_LENGTH : natural;
    G_CNT_SIZE   : natural;
    G_DATA_BYTES : natural
  );
end entity tb_axip_axis_axip;

architecture simulation of tb_axip_axis_axip is

  signal   clk : std_logic  := '1';
  signal   rst : std_logic  := '1';

  signal   s_ready : std_logic;
  signal   s_valid : std_logic;
  signal   s_data  : std_logic_vector(G_DATA_BYTES * 8 - 1 downto 0);
  signal   s_last  : std_logic;
  signal   s_bytes : natural range 0 to G_DATA_BYTES;

  signal   d_ready : std_logic;
  signal   d_valid : std_logic;
  signal   d_data  : std_logic_vector(7 downto 0);
  signal   d_last  : std_logic;

  signal   p_ready : std_logic;
  signal   p_valid : std_logic;
  signal   p_data  : std_logic_vector(7 downto 0);
  signal   p_last  : std_logic;

  signal   d_in  : std_logic_vector(8 downto 0);
  signal   p_out : std_logic_vector(8 downto 0);

  subtype  R_DATA is natural range 7 downto 0;

  constant C_LAST : natural := 8;

  signal   m_ready : std_logic;
  signal   m_valid : std_logic;
  signal   m_data  : std_logic_vector(G_DATA_BYTES * 8 - 1 downto 0);
  signal   m_last  : std_logic;
  signal   m_bytes : natural range 0 to G_DATA_BYTES;

begin

  ----------------------------------------------
  -- Clock and Reset
  ----------------------------------------------

  clk <= not clk after 5 ns;
  rst <= '1', '0' after 100 ns;


  ----------------------------------------------
  -- Instantiate AXI packet to AXI stream
  ----------------------------------------------

  axip_to_axis_inst : entity work.axip_to_axis
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
      m_ready_i => d_ready,
      m_valid_o => d_valid,
      m_data_o  => d_data,
      m_last_o  => d_last
    ); -- axip_to_axis_inst : entity work.axip_to_axis


  ----------------------------------------------
  -- Add additional random delays
  ----------------------------------------------

  axis_pause_inst : entity work.axis_pause
    generic map (
      G_SEED       => X"CAFEBABE666B00B5",
      G_DATA_SIZE  => 9,
      G_PAUSE_SIZE => G_PAUSE_SIZE
    )
    port map (
      clk_i     => clk,
      rst_i     => rst,
      s_ready_o => d_ready,
      s_valid_i => d_valid,
      s_data_i  => d_in,
      m_ready_i => p_ready,
      m_valid_o => p_valid,
      m_data_o  => p_out
    ); -- axis_pause_inst : entity work.axis_pause

  d_in(R_DATA) <= d_data;
  d_in(C_LAST) <= d_last;

  p_data       <= p_out(R_DATA);
  p_last       <= p_out(C_LAST);


  ----------------------------------------------
  -- Instantiate AXI stream to AXI packet
  ----------------------------------------------

  axis_to_axip_inst : entity work.axis_to_axip
    generic map (
      G_DATA_BYTES => G_DATA_BYTES
    )
    port map (
      clk_i     => clk,
      rst_i     => rst,
      s_ready_o => p_ready,
      s_valid_i => p_valid,
      s_data_i  => p_data,
      s_last_i  => p_last,
      m_ready_i => m_ready,
      m_valid_o => m_valid,
      m_data_o  => m_data,
      m_last_o  => m_last,
      m_bytes_o => m_bytes
    ); -- axis_to_axip_inst : entity work.axis_to_axip


  ----------------------------------------------
  -- Generate stimuli and verify response
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

