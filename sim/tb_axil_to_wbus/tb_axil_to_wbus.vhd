-- Author     : Michael Jørgensen
-- Platform   : Simulation
-- ----------------------------------------------------------------------------
-- Description:
-- Comprehensive test of the AXI-Lite to WBUS.
-- The axil_master_sim module used here generates multiple accesses simultaneously.
-- ----------------------------------------------------------------------------

library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std.all;

entity tb_axil_to_wbus is
  generic (
    G_DEBUG      : boolean;
    G_LATENCY    : natural;
    G_RANDOM     : boolean;
    G_FAST       : boolean;
    G_ADDR_SIZE  : natural;
    G_DATA_SIZE  : natural
  );
end entity tb_axil_to_wbus;

architecture simulation of tb_axil_to_wbus is

  signal clk : std_logic := '1';
  signal rst : std_logic := '1';

  signal axil_awready : std_logic;
  signal axil_awvalid : std_logic;
  signal axil_awaddr  : std_logic_vector(G_ADDR_SIZE - 1 downto 0);
  signal axil_wready  : std_logic;
  signal axil_wvalid  : std_logic;
  signal axil_wdata   : std_logic_vector(G_DATA_SIZE - 1 downto 0);
  signal axil_wstrb   : std_logic_vector(G_DATA_SIZE / 8 - 1 downto 0);
  signal axil_bready  : std_logic;
  signal axil_bvalid  : std_logic;
  signal axil_bresp   : std_logic_vector(1 downto 0);
  signal axil_arready : std_logic;
  signal axil_arvalid : std_logic;
  signal axil_araddr  : std_logic_vector(G_ADDR_SIZE - 1 downto 0);
  signal axil_rready  : std_logic;
  signal axil_rvalid  : std_logic;
  signal axil_rdata   : std_logic_vector(G_DATA_SIZE - 1 downto 0);
  signal axil_rresp   : std_logic_vector(1 downto 0);

  signal wbus_cyc   : std_logic;
  signal wbus_stall : std_logic;
  signal wbus_stb   : std_logic;
  signal wbus_addr  : std_logic_vector(G_ADDR_SIZE - 1 downto 0);
  signal wbus_we    : std_logic;
  signal wbus_wrdat : std_logic_vector(G_DATA_SIZE - 1 downto 0);
  signal wbus_ack   : std_logic;
  signal wbus_rddat : std_logic_vector(G_DATA_SIZE - 1 downto 0);

begin

  ------------------------------------------
  -- Clock and reset
  ------------------------------------------

  clk <= not clk after 5 ns;
  rst <= '1', '0' after 100 ns;


  ------------------------------------------
  -- Generate stimuli
  ------------------------------------------

  axil_master_sim_inst : entity work.axil_master_sim
    generic map (
      G_DEBUG      => G_DEBUG,
      G_OFFSET     => 1234,
      G_RANDOM     => G_RANDOM,
      G_FAST       => G_FAST,
      G_ADDR_SIZE  => G_ADDR_SIZE,
      G_DATA_SIZE  => G_DATA_SIZE
    )
    port map (
      clk_i       => clk,
      rst_i       => rst,
      m_awready_i => axil_awready,
      m_awvalid_o => axil_awvalid,
      m_awaddr_o  => axil_awaddr,
      m_wready_i  => axil_wready,
      m_wvalid_o  => axil_wvalid,
      m_wdata_o   => axil_wdata,
      m_wstrb_o   => axil_wstrb,
      m_bready_o  => axil_bready,
      m_bvalid_i  => axil_bvalid,
      m_bresp_i   => axil_bresp,
      m_arready_i => axil_arready,
      m_arvalid_o => axil_arvalid,
      m_araddr_o  => axil_araddr,
      m_rready_o  => axil_rready,
      m_rvalid_i  => axil_rvalid,
      m_rdata_i   => axil_rdata,
      m_rresp_i   => axil_rresp
    ); -- axil_master_sim_inst : entity work.axil_master_sim


  ------------------------------------------
  -- Instantiate DUT
  ------------------------------------------

  axil_to_wbus_inst : entity work.axil_to_wbus
    generic map (
      G_TIMEOUT   => 100,
      G_ADDR_SIZE => G_ADDR_SIZE,
      G_DATA_SIZE => G_DATA_SIZE
    )
    port map (
      clk_i            => clk,
      rst_i            => rst,
      s_axil_awready_o => axil_awready,
      s_axil_awvalid_i => axil_awvalid,
      s_axil_awaddr_i  => axil_awaddr,
      s_axil_wready_o  => axil_wready,
      s_axil_wvalid_i  => axil_wvalid,
      s_axil_wdata_i   => axil_wdata,
      s_axil_wstrb_i   => axil_wstrb,
      s_axil_bready_i  => axil_bready,
      s_axil_bvalid_o  => axil_bvalid,
      s_axil_bresp_o   => axil_bresp,
      s_axil_arready_o => axil_arready,
      s_axil_arvalid_i => axil_arvalid,
      s_axil_araddr_i  => axil_araddr,
      s_axil_rready_i  => axil_rready,
      s_axil_rvalid_o  => axil_rvalid,
      s_axil_rdata_o   => axil_rdata,
      s_axil_rresp_o   => axil_rresp,
      m_wbus_cyc_o     => wbus_cyc,
      m_wbus_stall_i   => wbus_stall,
      m_wbus_stb_o     => wbus_stb,
      m_wbus_addr_o    => wbus_addr,
      m_wbus_we_o      => wbus_we,
      m_wbus_wrdat_o   => wbus_wrdat,
      m_wbus_ack_i     => wbus_ack,
      m_wbus_rddat_i   => wbus_rddat
    ); -- axil_to_wbus_inst : entity work.axil_to_wbus


  --------..---------------------------
  -- Instantiate Wishbone slave
  ---------..--------------------------

  wbus_slave_sim_inst : entity work.wbus_slave_sim
    generic map (
      G_DEBUG     => G_DEBUG,
      G_LATENCY   => G_LATENCY,
      G_TIMEOUT   => false,
      G_ADDR_SIZE => G_ADDR_SIZE,
      G_DATA_SIZE => G_DATA_SIZE
    )
    port map (
      clk_i          => clk,
      rst_i          => rst,
      s_wbus_cyc_i   => wbus_cyc,
      s_wbus_stall_o => wbus_stall,
      s_wbus_stb_i   => wbus_stb,
      s_wbus_addr_i  => wbus_addr,
      s_wbus_we_i    => wbus_we,
      s_wbus_wrdat_i => wbus_wrdat,
      s_wbus_ack_o   => wbus_ack,
      s_wbus_rddat_o => wbus_rddat
    ); -- wbus_slave_sim_inst : entity work.wbus_slave_sim

end architecture simulation;

