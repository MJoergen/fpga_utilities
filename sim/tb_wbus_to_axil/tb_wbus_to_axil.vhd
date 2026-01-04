library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std.all;

entity tb_wbus_to_axil is
  generic (
    G_PAUSE_SIZE : natural;
    G_ID_SIZE    : natural;
    G_ADDR_SIZE  : natural;
    G_DATA_SIZE  : natural
  );
end entity tb_wbus_to_axil;

architecture simulation of tb_wbus_to_axil is

  signal running : std_logic := '1';
  signal clk     : std_logic := '1';
  signal rst     : std_logic := '1';

  signal m_wbus_cyc   : std_logic;
  signal m_wbus_stall : std_logic;
  signal m_wbus_stb   : std_logic;
  signal m_wbus_addr  : std_logic_vector(G_ADDR_SIZE - 1 downto 0);
  signal m_wbus_we    : std_logic;
  signal m_wbus_wrdat : std_logic_vector(G_DATA_SIZE - 1 downto 0);
  signal m_wbus_ack   : std_logic;
  signal m_wbus_rddat : std_logic_vector(G_DATA_SIZE - 1 downto 0);

  signal s_wbus_cyc   : std_logic;
  signal s_wbus_stall : std_logic;
  signal s_wbus_stb   : std_logic;
  signal s_wbus_addr  : std_logic_vector(G_ADDR_SIZE - 1 downto 0);
  signal s_wbus_we    : std_logic;
  signal s_wbus_wrdat : std_logic_vector(G_DATA_SIZE - 1 downto 0);
  signal s_wbus_ack   : std_logic;
  signal s_wbus_rddat : std_logic_vector(G_DATA_SIZE - 1 downto 0);

  signal m_axil_awready : std_logic;
  signal m_axil_awvalid : std_logic;
  signal m_axil_awaddr  : std_logic_vector(G_ADDR_SIZE - 1 downto 0);
  signal m_axil_awid    : std_logic_vector(G_ID_SIZE - 1 downto 0);
  signal m_axil_wready  : std_logic;
  signal m_axil_wvalid  : std_logic;
  signal m_axil_wdata   : std_logic_vector(G_DATA_SIZE - 1 downto 0);
  signal m_axil_wstrb   : std_logic_vector(G_DATA_SIZE / 8 - 1 downto 0);
  signal m_axil_bready  : std_logic;
  signal m_axil_bvalid  : std_logic;
  signal m_axil_bid     : std_logic_vector(G_ID_SIZE - 1 downto 0);
  signal m_axil_arready : std_logic;
  signal m_axil_arvalid : std_logic;
  signal m_axil_araddr  : std_logic_vector(G_ADDR_SIZE - 1 downto 0);
  signal m_axil_arid    : std_logic_vector(G_ID_SIZE - 1 downto 0);
  signal m_axil_rready  : std_logic;
  signal m_axil_rvalid  : std_logic;
  signal m_axil_rdata   : std_logic_vector(G_DATA_SIZE - 1 downto 0);
  signal m_axil_rid     : std_logic_vector(G_ID_SIZE - 1 downto 0);

  signal s_axil_awready : std_logic;
  signal s_axil_awvalid : std_logic;
  signal s_axil_awaddr  : std_logic_vector(G_ADDR_SIZE - 1 downto 0);
  signal s_axil_awid    : std_logic_vector(G_ID_SIZE - 1 downto 0);
  signal s_axil_wready  : std_logic;
  signal s_axil_wvalid  : std_logic;
  signal s_axil_wdata   : std_logic_vector(G_DATA_SIZE - 1 downto 0);
  signal s_axil_wstrb   : std_logic_vector(G_DATA_SIZE / 8 - 1 downto 0);
  signal s_axil_bready  : std_logic;
  signal s_axil_bvalid  : std_logic;
  signal s_axil_bid     : std_logic_vector(G_ID_SIZE - 1 downto 0);
  signal s_axil_arready : std_logic;
  signal s_axil_arvalid : std_logic;
  signal s_axil_araddr  : std_logic_vector(G_ADDR_SIZE - 1 downto 0);
  signal s_axil_arid    : std_logic_vector(G_ID_SIZE - 1 downto 0);
  signal s_axil_rready  : std_logic;
  signal s_axil_rvalid  : std_logic;
  signal s_axil_rdata   : std_logic_vector(G_DATA_SIZE - 1 downto 0);
  signal s_axil_rid     : std_logic_vector(G_ID_SIZE - 1 downto 0);

begin

  --------------------------------
  -- Clock and Reset
  --------------------------------

  clk <= running and not clk after 5 ns;
  rst <= '1', '0' after 100 ns;


  --------------------------------
  -- Instantiate DUTs
  --------------------------------

  wbus_to_axil_inst : entity work.wbus_to_axil
    generic map (
      G_ADDR_SIZE => G_ADDR_SIZE,
      G_DATA_SIZE => G_DATA_SIZE
    )
    port map (
      clk_i            => clk,
      rst_i            => rst,
      s_wbus_cyc_i     => m_wbus_cyc,
      s_wbus_stall_o   => m_wbus_stall,
      s_wbus_stb_i     => m_wbus_stb,
      s_wbus_addr_i    => m_wbus_addr,
      s_wbus_we_i      => m_wbus_we,
      s_wbus_wrdat_i   => m_wbus_wrdat,
      s_wbus_ack_o     => m_wbus_ack,
      s_wbus_rddat_o   => m_wbus_rddat,
      m_axil_awready_i => m_axil_awready,
      m_axil_awvalid_o => m_axil_awvalid,
      m_axil_awaddr_o  => m_axil_awaddr,
      m_axil_wready_i  => m_axil_wready,
      m_axil_wvalid_o  => m_axil_wvalid,
      m_axil_wdata_o   => m_axil_wdata,
      m_axil_wstrb_o   => m_axil_wstrb,
      m_axil_bready_o  => m_axil_bready,
      m_axil_bvalid_i  => m_axil_bvalid,
      m_axil_arready_i => m_axil_arready,
      m_axil_arvalid_o => m_axil_arvalid,
      m_axil_araddr_o  => m_axil_araddr,
      m_axil_rready_o  => m_axil_rready,
      m_axil_rvalid_i  => m_axil_rvalid,
      m_axil_rdata_i   => m_axil_rdata
    ); -- wbus_to_axil_inst : entity work.wbus_to_axil

  axil_pause_inst : entity work.axil_pause
    generic map (
      G_SEED       => (others => '0'),
      G_ID_SIZE    => G_ID_SIZE,
      G_ADDR_SIZE  => G_ADDR_SIZE,
      G_DATA_SIZE  => G_DATA_SIZE,
      G_PAUSE_SIZE => G_PAUSE_SIZE
    )
    port map (
      clk_i       => clk,
      rst_i       => rst,
      s_awready_o => m_axil_awready,
      s_awvalid_i => m_axil_awvalid,
      s_awaddr_i  => m_axil_awaddr,
      s_awid_i    => m_axil_awid,
      s_wready_o  => m_axil_wready,
      s_wvalid_i  => m_axil_wvalid,
      s_wdata_i   => m_axil_wdata,
      s_wstrb_i   => m_axil_wstrb,
      s_bready_i  => m_axil_bready,
      s_bvalid_o  => m_axil_bvalid,
      s_bid_o     => m_axil_bid,
      s_arready_o => m_axil_arready,
      s_arvalid_i => m_axil_arvalid,
      s_araddr_i  => m_axil_araddr,
      s_arid_i    => m_axil_arid,
      s_rready_i  => m_axil_rready,
      s_rvalid_o  => m_axil_rvalid,
      s_rdata_o   => m_axil_rdata,
      s_rid_o     => m_axil_rid,
      m_awready_i => s_axil_awready,
      m_awvalid_o => s_axil_awvalid,
      m_awaddr_o  => s_axil_awaddr,
      m_awid_o    => s_axil_awid,
      m_wready_i  => s_axil_wready,
      m_wvalid_o  => s_axil_wvalid,
      m_wdata_o   => s_axil_wdata,
      m_wstrb_o   => s_axil_wstrb,
      m_bready_o  => s_axil_bready,
      m_bvalid_i  => s_axil_bvalid,
      m_bid_i     => s_axil_bid,
      m_arready_i => s_axil_arready,
      m_arvalid_o => s_axil_arvalid,
      m_araddr_o  => s_axil_araddr,
      m_arid_o    => s_axil_arid,
      m_rready_o  => s_axil_rready,
      m_rvalid_i  => s_axil_rvalid,
      m_rdata_i   => s_axil_rdata,
      m_rid_i     => s_axil_rid
    ); -- axil_pause_inst : entity work.axil_pause


  axil_to_wbus_inst : entity work.axil_to_wbus
    generic map (
      G_TIMEOUT   => 1000,
      G_ID_SIZE   => G_ID_SIZE,
      G_ADDR_SIZE => G_ADDR_SIZE,
      G_DATA_SIZE => G_DATA_SIZE
    )
    port map (
      clk_i            => clk,
      rst_i            => rst,
      s_axil_awready_o => s_axil_awready,
      s_axil_awvalid_i => s_axil_awvalid,
      s_axil_awaddr_i  => s_axil_awaddr,
      s_axil_awid_i    => s_axil_awid,
      s_axil_wready_o  => s_axil_wready,
      s_axil_wvalid_i  => s_axil_wvalid,
      s_axil_wdata_i   => s_axil_wdata,
      s_axil_wstrb_i   => s_axil_wstrb,
      s_axil_bready_i  => s_axil_bready,
      s_axil_bvalid_o  => s_axil_bvalid,
      s_axil_bid_o     => s_axil_bid,
      s_axil_arready_o => s_axil_arready,
      s_axil_arvalid_i => s_axil_arvalid,
      s_axil_araddr_i  => s_axil_araddr,
      s_axil_arid_i    => s_axil_arid,
      s_axil_rready_i  => s_axil_rready,
      s_axil_rvalid_o  => s_axil_rvalid,
      s_axil_rdata_o   => s_axil_rdata,
      s_axil_rid_o     => s_axil_rid,
      m_wbus_cyc_o     => s_wbus_cyc,
      m_wbus_stall_i   => s_wbus_stall,
      m_wbus_stb_o     => s_wbus_stb,
      m_wbus_addr_o    => s_wbus_addr,
      m_wbus_we_o      => s_wbus_we,
      m_wbus_wrdat_o   => s_wbus_wrdat,
      m_wbus_ack_i     => s_wbus_ack,
      m_wbus_rddat_i   => s_wbus_rddat
    ); -- axil_to_wbus_inst : entity work.axil_to_wbus


  --------------------------------
  -- Instantiate Wishbone master
  --------------------------------

  wbus_master_sim_inst : entity work.wbus_master_sim
    generic map (
      G_DEBUG     => false,
      G_OFFSET    => 1234,
      G_ADDR_SIZE => G_ADDR_SIZE,
      G_DATA_SIZE => G_DATA_SIZE
    )
    port map (
      clk_i          => clk,
      rst_i          => rst,
      m_wbus_cyc_o   => m_wbus_cyc,
      m_wbus_stall_i => m_wbus_stall,
      m_wbus_stb_o   => m_wbus_stb,
      m_wbus_addr_o  => m_wbus_addr,
      m_wbus_we_o    => m_wbus_we,
      m_wbus_wrdat_o => m_wbus_wrdat,
      m_wbus_ack_i   => m_wbus_ack,
      m_wbus_rddat_i => m_wbus_rddat
    ); -- wbus_master_sim_inst : entity work.wbus_master_sim


  --------------------------------
  -- Instantiate Wishbone slave
  --------------------------------

  wbus_slave_sim_inst : entity work.wbus_slave_sim
    generic map (
      G_DEBUG     => false,
      G_TIMEOUT   => false,
      G_ADDR_SIZE => G_ADDR_SIZE,
      G_DATA_SIZE => G_DATA_SIZE
    )
    port map (
      clk_i          => clk,
      rst_i          => rst,
      s_wbus_cyc_i   => s_wbus_cyc,
      s_wbus_stall_o => s_wbus_stall,
      s_wbus_stb_i   => s_wbus_stb,
      s_wbus_addr_i  => s_wbus_addr,
      s_wbus_we_i    => s_wbus_we,
      s_wbus_wrdat_i => s_wbus_wrdat,
      s_wbus_ack_o   => s_wbus_ack,
      s_wbus_rddat_o => s_wbus_rddat
    ); -- wbus_mem_sim_inst : entity work.wbus_mem_sim

end architecture simulation;

