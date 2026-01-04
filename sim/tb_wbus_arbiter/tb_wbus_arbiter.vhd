library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std.all;

entity tb_wbus_arbiter is
  generic (
    G_DEBUG      : boolean;
    G_DO_ABORT   : boolean;
    G_ADDR_SIZE  : natural;
    G_DATA_SIZE  : natural
  );
end entity tb_wbus_arbiter;

architecture simulation of tb_wbus_arbiter is

  signal   running : std_logic   := '1';
  signal   clk     : std_logic   := '1';
  signal   rst     : std_logic   := '1';

  signal   s0_wbus_cyc   : std_logic;
  signal   s0_wbus_stall : std_logic;
  signal   s0_wbus_stb   : std_logic;
  signal   s0_wbus_addr  : std_logic_vector(G_ADDR_SIZE - 1 downto 0);
  signal   s0_wbus_we    : std_logic;
  signal   s0_wbus_wrdat : std_logic_vector(G_DATA_SIZE - 1 downto 0);
  signal   s0_wbus_ack   : std_logic;
  signal   s0_wbus_rddat : std_logic_vector(G_DATA_SIZE - 1 downto 0);

  signal   s1_wbus_cyc   : std_logic;
  signal   s1_wbus_stall : std_logic;
  signal   s1_wbus_stb   : std_logic;
  signal   s1_wbus_addr  : std_logic_vector(G_ADDR_SIZE - 1 downto 0);
  signal   s1_wbus_we    : std_logic;
  signal   s1_wbus_wrdat : std_logic_vector(G_DATA_SIZE - 1 downto 0);
  signal   s1_wbus_ack   : std_logic;
  signal   s1_wbus_rddat : std_logic_vector(G_DATA_SIZE - 1 downto 0);

  signal   m_wbus_cyc   : std_logic;
  signal   m_wbus_stall : std_logic;
  signal   m_wbus_stb   : std_logic;
  signal   m_wbus_addr  : std_logic_vector(G_ADDR_SIZE downto 0);
  signal   m_wbus_we    : std_logic;
  signal   m_wbus_wrdat : std_logic_vector(G_DATA_SIZE - 1 downto 0);
  signal   m_wbus_ack   : std_logic;
  signal   m_wbus_rddat : std_logic_vector(G_DATA_SIZE - 1 downto 0);

begin

  --------------------------------
  -- Clock and Reset
  --------------------------------

  clk <= running and not clk after 5 ns;
  rst <= '1', '0' after 100 ns;


  --------------------------------
  -- Instantiate DUT
  --------------------------------

  wbus_arbiter_inst : entity work.wbus_arbiter
    generic map (
      G_ADDR_SIZE => G_ADDR_SIZE+1,
      G_DATA_SIZE => G_DATA_SIZE
    )
    port map (
      clk_i           => clk,
      rst_i           => rst,
      s0_wbus_cyc_i   => s0_wbus_cyc,
      s0_wbus_stall_o => s0_wbus_stall,
      s0_wbus_stb_i   => s0_wbus_stb,
      s0_wbus_addr_i  => "0" & s0_wbus_addr,
      s0_wbus_we_i    => s0_wbus_we,
      s0_wbus_wrdat_i => s0_wbus_wrdat,
      s0_wbus_ack_o   => s0_wbus_ack,
      s0_wbus_rddat_o => s0_wbus_rddat,
      s1_wbus_cyc_i   => s1_wbus_cyc,
      s1_wbus_stall_o => s1_wbus_stall,
      s1_wbus_stb_i   => s1_wbus_stb,
      s1_wbus_addr_i  => "1" & s1_wbus_addr,
      s1_wbus_we_i    => s1_wbus_we,
      s1_wbus_wrdat_i => s1_wbus_wrdat,
      s1_wbus_ack_o   => s1_wbus_ack,
      s1_wbus_rddat_o => s1_wbus_rddat,
      m_wbus_cyc_o    => m_wbus_cyc,
      m_wbus_stall_i  => m_wbus_stall,
      m_wbus_stb_o    => m_wbus_stb,
      m_wbus_addr_o   => m_wbus_addr,
      m_wbus_we_o     => m_wbus_we,
      m_wbus_wrdat_o  => m_wbus_wrdat,
      m_wbus_ack_i    => m_wbus_ack,
      m_wbus_rddat_i  => m_wbus_rddat
    ); -- wbus_arbiter_inst : entity work.wbus_arbiter


  --------------------------------
  -- Instantiate Wishbone masters
  --------------------------------

  wbus_master_sim_0_inst : entity work.wbus_master_sim
    generic map (
      G_SEED      => X"1234567812345678",
      G_OFFSET    => 1234,
      G_DO_ABORT  => G_DO_ABORT,
      G_ADDR_SIZE => G_ADDR_SIZE,
      G_DATA_SIZE => G_DATA_SIZE
    )
    port map (
      clk_i          => clk,
      rst_i          => rst,
      m_wbus_cyc_o   => s0_wbus_cyc,
      m_wbus_stall_i => s0_wbus_stall,
      m_wbus_stb_o   => s0_wbus_stb,
      m_wbus_addr_o  => s0_wbus_addr,
      m_wbus_we_o    => s0_wbus_we,
      m_wbus_wrdat_o => s0_wbus_wrdat,
      m_wbus_ack_i   => s0_wbus_ack,
      m_wbus_rddat_i => s0_wbus_rddat
    ); -- wbus_master_sim_0_inst : entity work.wbus_master_sim

  wbus_master_sim_1_inst : entity work.wbus_master_sim
    generic map (
      G_SEED      => X"1122334455667788",
      G_OFFSET    => 4321,
      G_DO_ABORT  => G_DO_ABORT,
      G_ADDR_SIZE => G_ADDR_SIZE,
      G_DATA_SIZE => G_DATA_SIZE
    )
    port map (
      clk_i          => clk,
      rst_i          => rst,
      m_wbus_cyc_o   => s1_wbus_cyc,
      m_wbus_stall_i => s1_wbus_stall,
      m_wbus_stb_o   => s1_wbus_stb,
      m_wbus_addr_o  => s1_wbus_addr,
      m_wbus_we_o    => s1_wbus_we,
      m_wbus_wrdat_o => s1_wbus_wrdat,
      m_wbus_ack_i   => s1_wbus_ack,
      m_wbus_rddat_i => s1_wbus_rddat
    ); -- wbus_master_sim_1_inst : entity work.wbus_master_sim


  --------------------------------
  -- Instantiate Wishbone slave
  --------------------------------

  wbus_slave_sim_inst : entity work.wbus_slave_sim
    generic map (
      G_DEBUG     => G_DEBUG,
      G_TIMEOUT   => false,
      G_ADDR_SIZE => G_ADDR_SIZE+1,
      G_DATA_SIZE => G_DATA_SIZE
    )
    port map (
      clk_i          => clk,
      rst_i          => rst,
      s_wbus_cyc_i   => m_wbus_cyc,
      s_wbus_stall_o => m_wbus_stall,
      s_wbus_stb_i   => m_wbus_stb,
      s_wbus_addr_i  => m_wbus_addr,
      s_wbus_we_i    => m_wbus_we,
      s_wbus_wrdat_i => m_wbus_wrdat,
      s_wbus_ack_o   => m_wbus_ack,
      s_wbus_rddat_o => m_wbus_rddat
    ); -- wbus_slave_sim_inst : entity work.wbus_slave_sim

end architecture simulation;

