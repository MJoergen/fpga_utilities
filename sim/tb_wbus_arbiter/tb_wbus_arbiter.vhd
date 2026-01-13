-- ---------------------------------------------------------------------------------------
-- Description: Verify wbus_arbiter
-- ---------------------------------------------------------------------------------------

library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std.all;

library work;
  use work.wbus_pkg.slv32_array_type;

entity tb_wbus_arbiter is
  generic (
    G_DEBUG     : boolean;
    G_DO_ABORT  : boolean;
    G_LATENCY   : natural;
    G_ADDR_SIZE : natural
  );
end entity tb_wbus_arbiter;

architecture simulation of tb_wbus_arbiter is

  signal clk : std_logic := '1';
  signal rst : std_logic := '1';

  signal s0_cyc   : std_logic;
  signal s0_stall : std_logic;
  signal s0_stb   : std_logic;
  signal s0_addr  : std_logic_vector(G_ADDR_SIZE - 1 downto 0);
  signal s0_we    : std_logic;
  signal s0_wrdat : std_logic_vector(31 downto 0);
  signal s0_ack   : std_logic;
  signal s0_rddat : std_logic_vector(31 downto 0);

  signal s1_cyc   : std_logic;
  signal s1_stall : std_logic;
  signal s1_stb   : std_logic;
  signal s1_addr  : std_logic_vector(G_ADDR_SIZE - 1 downto 0);
  signal s1_we    : std_logic;
  signal s1_wrdat : std_logic_vector(31 downto 0);
  signal s1_ack   : std_logic;
  signal s1_rddat : std_logic_vector(31 downto 0);

  signal m_cyc   : std_logic;
  signal m_stall : std_logic;
  signal m_stb   : std_logic;
  signal m_addr  : std_logic_vector(G_ADDR_SIZE downto 0);
  signal m_we    : std_logic;
  signal m_wrdat : std_logic_vector(31 downto 0);
  signal m_ack   : std_logic;
  signal m_rddat : std_logic_vector(31 downto 0);

  signal map_rst   : std_logic_vector(1 downto 0);
  signal map_cyc   : std_logic;
  signal map_stall : std_logic_vector(1 downto 0);
  signal map_stb   : std_logic_vector(1 downto 0);
  signal map_addr  : std_logic_vector(G_ADDR_SIZE - 1 downto 0);
  signal map_we    : std_logic;
  signal map_wrdat : std_logic_vector(31 downto 0);
  signal map_ack   : std_logic_vector(1 downto 0);
  signal map_rddat : slv32_array_type(1 downto 0);

begin

  --------------------------------
  -- Clock and Reset
  --------------------------------

  clk <= not clk after 5 ns;
  rst <= '1', '0' after 100 ns;


  --------------------------------
  -- Instantiate DUT
  --------------------------------

  wbus_arbiter_inst : entity work.wbus_arbiter
    generic map (
      G_ADDR_SIZE => G_ADDR_SIZE + 1,
      G_DATA_SIZE => 32
    )
    port map (
      clk_i      => clk,
      rst_i      => rst,
      s0_cyc_i   => s0_cyc,
      s0_stall_o => s0_stall,
      s0_stb_i   => s0_stb,
      s0_addr_i  => "0" & s0_addr,
      s0_we_i    => s0_we,
      s0_wrdat_i => s0_wrdat,
      s0_ack_o   => s0_ack,
      s0_rddat_o => s0_rddat,
      s1_cyc_i   => s1_cyc,
      s1_stall_o => s1_stall,
      s1_stb_i   => s1_stb,
      s1_addr_i  => "1" & s1_addr,
      s1_we_i    => s1_we,
      s1_wrdat_i => s1_wrdat,
      s1_ack_o   => s1_ack,
      s1_rddat_o => s1_rddat,
      m_cyc_o    => m_cyc,
      m_stall_i  => m_stall,
      m_stb_o    => m_stb,
      m_addr_o   => m_addr,
      m_we_o     => m_we,
      m_wrdat_o  => m_wrdat,
      m_ack_i    => m_ack,
      m_rddat_i  => m_rddat
    ); -- wbus_arbiter_inst : entity work.wbus_arbiter

  wbus_mapper_inst : entity work.wbus_mapper
    generic map (
      G_NUM_SLAVES       => 2,
      G_MASTER_ADDR_SIZE => G_ADDR_SIZE + 1,
      G_SLAVE_ADDR_SIZE  => G_ADDR_SIZE
    )
    port map (
      clk_i     => clk,
      rst_i     => rst,
      s_cyc_i   => m_cyc,
      s_stall_o => m_stall,
      s_stb_i   => m_stb,
      s_addr_i  => m_addr,
      s_we_i    => m_we,
      s_wrdat_i => m_wrdat,
      s_ack_o   => m_ack,
      s_rddat_o => m_rddat,
      m_rst_o   => map_rst,
      m_cyc_o   => map_cyc,
      m_stall_i => map_stall,
      m_stb_o   => map_stb,
      m_addr_o  => map_addr,
      m_we_o    => map_we,
      m_wrdat_o => map_wrdat,
      m_ack_i   => map_ack,
      m_rddat_i => map_rddat
    ); -- wbus_mapper_inst : entity work.wbus_mapper


  --------------------------------
  -- Instantiate Stimuli
  --------------------------------

  wbus_sim_0_inst : entity work.wbus_sim
    generic map (
      G_SEED        => X"1234567812345678",
      G_NAME        => "",
      G_TIMEOUT_MAX => 100,
      G_DEBUG       => G_DEBUG,
      G_TIMEOUT     => false,
      G_LATENCY     => G_LATENCY,
      G_OFFSET      => 1234,
      G_DO_ABORT    => G_DO_ABORT,
      G_ADDR_SIZE   => G_ADDR_SIZE,
      G_DATA_SIZE   => 32
    )
    port map (
      clk_i     => clk,
      rst_i     => rst,
      m_cyc_o   => s0_cyc,
      m_stall_i => s0_stall,
      m_stb_o   => s0_stb,
      m_addr_o  => s0_addr,
      m_we_o    => s0_we,
      m_wrdat_o => s0_wrdat,
      m_ack_i   => s0_ack,
      m_rddat_i => s0_rddat,
      s_cyc_i   => map_cyc,
      s_stall_o => map_stall(0),
      s_stb_i   => map_stb(0),
      s_addr_i  => map_addr,
      s_we_i    => map_we,
      s_wrdat_i => map_wrdat,
      s_ack_o   => map_ack(0),
      s_rddat_o => map_rddat(0)
    ); -- wbus_sim_0_inst : entity work.wbus_sim

  wbus_sim_1_inst : entity work.wbus_sim
    generic map (
      G_SEED        => X"1122334455667788",
      G_NAME        => "",
      G_TIMEOUT_MAX => 100,
      G_DEBUG       => G_DEBUG,
      G_TIMEOUT     => false,
      G_LATENCY     => G_LATENCY,
      G_OFFSET      => 4321,
      G_DO_ABORT    => G_DO_ABORT,
      G_ADDR_SIZE   => G_ADDR_SIZE,
      G_DATA_SIZE   => 32
    )
    port map (
      clk_i     => clk,
      rst_i     => rst,
      m_cyc_o   => s1_cyc,
      m_stall_i => s1_stall,
      m_stb_o   => s1_stb,
      m_addr_o  => s1_addr,
      m_we_o    => s1_we,
      m_wrdat_o => s1_wrdat,
      m_ack_i   => s1_ack,
      m_rddat_i => s1_rddat,
      s_cyc_i   => map_cyc,
      s_stall_o => map_stall(1),
      s_stb_i   => map_stb(1),
      s_addr_i  => map_addr,
      s_we_i    => map_we,
      s_wrdat_i => map_wrdat,
      s_ack_o   => map_ack(1),
      s_rddat_o => map_rddat(1)
    ); -- wbus_sim_1_inst : entity work.wbus_sim

end architecture simulation;

