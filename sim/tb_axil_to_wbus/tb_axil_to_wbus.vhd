library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std.all;

entity tb_axil_to_wbus is
  generic (
    G_DEBUG      : boolean;
    G_PAUSE_SIZE : natural;
    G_ID_SIZE    : natural;
    G_ADDR_SIZE  : natural;
    G_DATA_SIZE  : natural
  );
end entity tb_axil_to_wbus;

architecture simulation of tb_axil_to_wbus is

  signal running : std_logic := '1';
  signal clk     : std_logic := '1';
  signal rst     : std_logic := '1';

  signal s0_axil_awready : std_logic;
  signal s0_axil_awvalid : std_logic;
  signal s0_axil_awaddr  : std_logic_vector(G_ADDR_SIZE - 1 downto 0);
  signal s0_axil_awid    : std_logic_vector(G_ID_SIZE - 1 downto 0);
  signal s0_axil_wready  : std_logic;
  signal s0_axil_wvalid  : std_logic;
  signal s0_axil_wdata   : std_logic_vector(G_DATA_SIZE - 1 downto 0);
  signal s0_axil_wstrb   : std_logic_vector(G_DATA_SIZE / 8 - 1 downto 0);
  signal s0_axil_bready  : std_logic;
  signal s0_axil_bvalid  : std_logic;
  signal s0_axil_bid     : std_logic_vector(G_ID_SIZE - 1 downto 0);
  signal s0_axil_arready : std_logic;
  signal s0_axil_arvalid : std_logic;
  signal s0_axil_araddr  : std_logic_vector(G_ADDR_SIZE - 1 downto 0);
  signal s0_axil_arid    : std_logic_vector(G_ID_SIZE - 1 downto 0);
  signal s0_axil_rready  : std_logic;
  signal s0_axil_rvalid  : std_logic;
  signal s0_axil_rdata   : std_logic_vector(G_DATA_SIZE - 1 downto 0);
  signal s0_axil_rid     : std_logic_vector(G_ID_SIZE - 1 downto 0);
  signal s1_axil_awready : std_logic;
  signal s1_axil_awvalid : std_logic;
  signal s1_axil_awaddr  : std_logic_vector(G_ADDR_SIZE - 1 downto 0);
  signal s1_axil_awid    : std_logic_vector(G_ID_SIZE - 1 downto 0);
  signal s1_axil_wready  : std_logic;
  signal s1_axil_wvalid  : std_logic;
  signal s1_axil_wdata   : std_logic_vector(G_DATA_SIZE - 1 downto 0);
  signal s1_axil_wstrb   : std_logic_vector(G_DATA_SIZE / 8 - 1 downto 0);
  signal s1_axil_bready  : std_logic;
  signal s1_axil_bvalid  : std_logic;
  signal s1_axil_bid     : std_logic_vector(G_ID_SIZE - 1 downto 0);
  signal s1_axil_arready : std_logic;
  signal s1_axil_arvalid : std_logic;
  signal s1_axil_araddr  : std_logic_vector(G_ADDR_SIZE - 1 downto 0);
  signal s1_axil_arid    : std_logic_vector(G_ID_SIZE - 1 downto 0);
  signal s1_axil_rready  : std_logic;
  signal s1_axil_rvalid  : std_logic;
  signal s1_axil_rdata   : std_logic_vector(G_DATA_SIZE - 1 downto 0);
  signal s1_axil_rid     : std_logic_vector(G_ID_SIZE - 1 downto 0);
  signal m_axil_awready  : std_logic;
  signal m_axil_awvalid  : std_logic;
  signal m_axil_awaddr   : std_logic_vector(G_ADDR_SIZE downto 0);
  signal m_axil_awid     : std_logic_vector(G_ID_SIZE downto 0);
  signal m_axil_wready   : std_logic;
  signal m_axil_wvalid   : std_logic;
  signal m_axil_wdata    : std_logic_vector(G_DATA_SIZE - 1 downto 0);
  signal m_axil_wstrb    : std_logic_vector(G_DATA_SIZE / 8 - 1 downto 0);
  signal m_axil_bready   : std_logic;
  signal m_axil_bvalid   : std_logic;
  signal m_axil_bid      : std_logic_vector(G_ID_SIZE downto 0);
  signal m_axil_arready  : std_logic;
  signal m_axil_arvalid  : std_logic;
  signal m_axil_araddr   : std_logic_vector(G_ADDR_SIZE downto 0);
  signal m_axil_arid     : std_logic_vector(G_ID_SIZE downto 0);
  signal m_axil_rready   : std_logic;
  signal m_axil_rvalid   : std_logic;
  signal m_axil_rdata    : std_logic_vector(G_DATA_SIZE - 1 downto 0);
  signal m_axil_rid      : std_logic_vector(G_ID_SIZE downto 0);

  signal s0_axil_pause_awready : std_logic;
  signal s0_axil_pause_awvalid : std_logic;
  signal s0_axil_pause_awaddr  : std_logic_vector(G_ADDR_SIZE - 1 downto 0);
  signal s0_axil_pause_awid    : std_logic_vector(G_ID_SIZE - 1 downto 0);
  signal s0_axil_pause_wready  : std_logic;
  signal s0_axil_pause_wvalid  : std_logic;
  signal s0_axil_pause_wdata   : std_logic_vector(G_DATA_SIZE - 1 downto 0);
  signal s0_axil_pause_wstrb   : std_logic_vector(G_DATA_SIZE / 8 - 1 downto 0);
  signal s0_axil_pause_bready  : std_logic;
  signal s0_axil_pause_bvalid  : std_logic;
  signal s0_axil_pause_bid     : std_logic_vector(G_ID_SIZE - 1 downto 0);
  signal s0_axil_pause_arready : std_logic;
  signal s0_axil_pause_arvalid : std_logic;
  signal s0_axil_pause_araddr  : std_logic_vector(G_ADDR_SIZE - 1 downto 0);
  signal s0_axil_pause_arid    : std_logic_vector(G_ID_SIZE - 1 downto 0);
  signal s0_axil_pause_rready  : std_logic;
  signal s0_axil_pause_rvalid  : std_logic;
  signal s0_axil_pause_rdata   : std_logic_vector(G_DATA_SIZE - 1 downto 0);
  signal s0_axil_pause_rid     : std_logic_vector(G_ID_SIZE - 1 downto 0);
  signal s1_axil_pause_awready : std_logic;
  signal s1_axil_pause_awvalid : std_logic;
  signal s1_axil_pause_awaddr  : std_logic_vector(G_ADDR_SIZE - 1 downto 0);
  signal s1_axil_pause_awid    : std_logic_vector(G_ID_SIZE - 1 downto 0);
  signal s1_axil_pause_wready  : std_logic;
  signal s1_axil_pause_wvalid  : std_logic;
  signal s1_axil_pause_wdata   : std_logic_vector(G_DATA_SIZE - 1 downto 0);
  signal s1_axil_pause_wstrb   : std_logic_vector(G_DATA_SIZE / 8 - 1 downto 0);
  signal s1_axil_pause_bready  : std_logic;
  signal s1_axil_pause_bvalid  : std_logic;
  signal s1_axil_pause_bid     : std_logic_vector(G_ID_SIZE - 1 downto 0);
  signal s1_axil_pause_arready : std_logic;
  signal s1_axil_pause_arvalid : std_logic;
  signal s1_axil_pause_araddr  : std_logic_vector(G_ADDR_SIZE - 1 downto 0);
  signal s1_axil_pause_arid    : std_logic_vector(G_ID_SIZE - 1 downto 0);
  signal s1_axil_pause_rready  : std_logic;
  signal s1_axil_pause_rvalid  : std_logic;
  signal s1_axil_pause_rdata   : std_logic_vector(G_DATA_SIZE - 1 downto 0);
  signal s1_axil_pause_rid     : std_logic_vector(G_ID_SIZE - 1 downto 0);

  signal s0_wbus_cyc   : std_logic;
  signal s0_wbus_stall : std_logic;
  signal s0_wbus_stb   : std_logic;
  signal s0_wbus_addr  : std_logic_vector(G_ADDR_SIZE - 1 downto 0);
  signal s0_wbus_we    : std_logic;
  signal s0_wbus_wrdat : std_logic_vector(G_DATA_SIZE - 1 downto 0);
  signal s0_wbus_ack   : std_logic;
  signal s0_wbus_rddat : std_logic_vector(G_DATA_SIZE - 1 downto 0);

  signal s1_wbus_cyc   : std_logic;
  signal s1_wbus_stall : std_logic;
  signal s1_wbus_stb   : std_logic;
  signal s1_wbus_addr  : std_logic_vector(G_ADDR_SIZE - 1 downto 0);
  signal s1_wbus_we    : std_logic;
  signal s1_wbus_wrdat : std_logic_vector(G_DATA_SIZE - 1 downto 0);
  signal s1_wbus_ack   : std_logic;
  signal s1_wbus_rddat : std_logic_vector(G_DATA_SIZE - 1 downto 0);

  signal m_wbus_cyc   : std_logic;
  signal m_wbus_stall : std_logic;
  signal m_wbus_stb   : std_logic;
  signal m_wbus_addr  : std_logic_vector(G_ADDR_SIZE downto 0);
  signal m_wbus_we    : std_logic;
  signal m_wbus_wrdat : std_logic_vector(G_DATA_SIZE - 1 downto 0);
  signal m_wbus_ack   : std_logic;
  signal m_wbus_rddat : std_logic_vector(G_DATA_SIZE - 1 downto 0);

begin

  --------------------------------
  -- Clock and Reset
  --------------------------------

  clk <= running and not clk after 5 ns;
  rst <= '1', '0' after 100 ns;


  --------------------------------
  -- Instantiate DUT
  --------------------------------

  axil_arbiter_inst : entity work.axil_arbiter
    generic map (
      G_ID_SIZE   => G_ID_SIZE,
      G_ADDR_SIZE => G_ADDR_SIZE + 1,
      G_DATA_SIZE => G_DATA_SIZE
    )
    port map (
      clk_i        => clk,
      rst_i        => rst,
      s0_awready_o => s0_axil_pause_awready,
      s0_awvalid_i => s0_axil_pause_awvalid,
      s0_awaddr_i  => "0" & s0_axil_pause_awaddr,
      s0_awid_i    => s0_axil_pause_awid,
      s0_wready_o  => s0_axil_pause_wready,
      s0_wvalid_i  => s0_axil_pause_wvalid,
      s0_wdata_i   => s0_axil_pause_wdata,
      s0_wstrb_i   => s0_axil_pause_wstrb,
      s0_bready_i  => s0_axil_pause_bready,
      s0_bvalid_o  => s0_axil_pause_bvalid,
      s0_bid_o     => s0_axil_pause_bid,
      s0_arready_o => s0_axil_pause_arready,
      s0_arvalid_i => s0_axil_pause_arvalid,
      s0_araddr_i  => "0" & s0_axil_pause_araddr,
      s0_arid_i    => s0_axil_pause_arid,
      s0_rready_i  => s0_axil_pause_rready,
      s0_rvalid_o  => s0_axil_pause_rvalid,
      s0_rdata_o   => s0_axil_pause_rdata,
      s0_rid_o     => s0_axil_pause_rid,
      s1_awready_o => s1_axil_pause_awready,
      s1_awvalid_i => s1_axil_pause_awvalid,
      s1_awaddr_i  => "1" & s1_axil_pause_awaddr,
      s1_awid_i    => s1_axil_pause_awid,
      s1_wready_o  => s1_axil_pause_wready,
      s1_wvalid_i  => s1_axil_pause_wvalid,
      s1_wdata_i   => s1_axil_pause_wdata,
      s1_wstrb_i   => s1_axil_pause_wstrb,
      s1_bready_i  => s1_axil_pause_bready,
      s1_bvalid_o  => s1_axil_pause_bvalid,
      s1_bid_o     => s1_axil_pause_bid,
      s1_arready_o => s1_axil_pause_arready,
      s1_arvalid_i => s1_axil_pause_arvalid,
      s1_araddr_i  => "1" & s1_axil_pause_araddr,
      s1_arid_i    => s1_axil_pause_arid,
      s1_rready_i  => s1_axil_pause_rready,
      s1_rvalid_o  => s1_axil_pause_rvalid,
      s1_rdata_o   => s1_axil_pause_rdata,
      s1_rid_o     => s1_axil_pause_rid,
      m_awready_i  => m_axil_awready,
      m_awvalid_o  => m_axil_awvalid,
      m_awaddr_o   => m_axil_awaddr,
      m_awid_o     => m_axil_awid,
      m_wready_i   => m_axil_wready,
      m_wvalid_o   => m_axil_wvalid,
      m_wdata_o    => m_axil_wdata,
      m_wstrb_o    => m_axil_wstrb,
      m_bready_o   => m_axil_bready,
      m_bvalid_i   => m_axil_bvalid,
      m_bid_i      => m_axil_bid,
      m_arready_i  => m_axil_arready,
      m_arvalid_o  => m_axil_arvalid,
      m_araddr_o   => m_axil_araddr,
      m_arid_o     => m_axil_arid,
      m_rready_o   => m_axil_rready,
      m_rvalid_i   => m_axil_rvalid,
      m_rdata_i    => m_axil_rdata,
      m_rid_i      => m_axil_rid
    ); -- axil_arbiter_inst : entity work.axil_arbiter


  --------------------------------
  -- Instantiate Wishbone masters
  --------------------------------

  wbus_master_sim_0_inst : entity work.wbus_master_sim
    generic map (
      G_OFFSET    => 1234,
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

  wbus_to_axil_0_inst : entity work.wbus_to_axil
    generic map (
      G_ADDR_SIZE => G_ADDR_SIZE,
      G_DATA_SIZE => G_DATA_SIZE
    )
    port map (
      clk_i            => clk,
      rst_i            => rst,
      s_wbus_cyc_i     => s0_wbus_cyc,
      s_wbus_stall_o   => s0_wbus_stall,
      s_wbus_stb_i     => s0_wbus_stb,
      s_wbus_addr_i    => s0_wbus_addr,
      s_wbus_we_i      => s0_wbus_we,
      s_wbus_wrdat_i   => s0_wbus_wrdat,
      s_wbus_ack_o     => s0_wbus_ack,
      s_wbus_rddat_o   => s0_wbus_rddat,
      m_axil_awready_i => s0_axil_awready,
      m_axil_awvalid_o => s0_axil_awvalid,
      m_axil_awaddr_o  => s0_axil_awaddr,
      m_axil_wready_i  => s0_axil_wready,
      m_axil_wvalid_o  => s0_axil_wvalid,
      m_axil_wdata_o   => s0_axil_wdata,
      m_axil_wstrb_o   => s0_axil_wstrb,
      m_axil_bready_o  => s0_axil_bready,
      m_axil_bvalid_i  => s0_axil_bvalid,
      m_axil_arready_i => s0_axil_arready,
      m_axil_arvalid_o => s0_axil_arvalid,
      m_axil_araddr_o  => s0_axil_araddr,
      m_axil_rready_o  => s0_axil_rready,
      m_axil_rvalid_i  => s0_axil_rvalid,
      m_axil_rdata_i   => s0_axil_rdata
    ); -- wbus_to_axil_0_inst : entity work.wbus_to_axil

  axil_pause_0_inst : entity work.axil_pause
    generic map (
      G_SEED       => (others => '0'),
      G_ADDR_SIZE  => G_ADDR_SIZE,
      G_ID_SIZE    => G_ID_SIZE,
      G_DATA_SIZE  => G_DATA_SIZE,
      G_PAUSE_SIZE => G_PAUSE_SIZE
    )
    port map (
      clk_i       => clk,
      rst_i       => rst,
      s_awready_o => s0_axil_awready,
      s_awvalid_i => s0_axil_awvalid,
      s_awaddr_i  => s0_axil_awaddr,
      s_awid_i    => s0_axil_awid,
      s_wready_o  => s0_axil_wready,
      s_wvalid_i  => s0_axil_wvalid,
      s_wdata_i   => s0_axil_wdata,
      s_wstrb_i   => s0_axil_wstrb,
      s_bready_i  => s0_axil_bready,
      s_bvalid_o  => s0_axil_bvalid,
      s_bid_o     => s0_axil_rid,
      s_arready_o => s0_axil_arready,
      s_arvalid_i => s0_axil_arvalid,
      s_araddr_i  => s0_axil_araddr,
      s_arid_i    => s0_axil_arid,
      s_rready_i  => s0_axil_rready,
      s_rvalid_o  => s0_axil_rvalid,
      s_rdata_o   => s0_axil_rdata,
      s_rid_o     => s0_axil_rid,
      m_awready_i => s0_axil_pause_awready,
      m_awvalid_o => s0_axil_pause_awvalid,
      m_awaddr_o  => s0_axil_pause_awaddr,
      m_awid_o    => s0_axil_pause_awid,
      m_wready_i  => s0_axil_pause_wready,
      m_wvalid_o  => s0_axil_pause_wvalid,
      m_wdata_o   => s0_axil_pause_wdata,
      m_wstrb_o   => s0_axil_pause_wstrb,
      m_bready_o  => s0_axil_pause_bready,
      m_bvalid_i  => s0_axil_pause_bvalid,
      m_bid_i     => s0_axil_pause_bid,
      m_arready_i => s0_axil_pause_arready,
      m_arvalid_o => s0_axil_pause_arvalid,
      m_araddr_o  => s0_axil_pause_araddr,
      m_arid_o    => s0_axil_pause_arid,
      m_rready_o  => s0_axil_pause_rready,
      m_rvalid_i  => s0_axil_pause_rvalid,
      m_rdata_i   => s0_axil_pause_rdata,
      m_rid_i     => s0_axil_pause_rid
    ); -- axil_pause_0_inst : entity work.axil_pause


  wbus_master_sim_1_inst : entity work.wbus_master_sim
    generic map (
      G_OFFSET    => 4321,
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

  wbus_to_axil_1_inst : entity work.wbus_to_axil
    generic map (
      G_ADDR_SIZE => G_ADDR_SIZE,
      G_DATA_SIZE => G_DATA_SIZE
    )
    port map (
      clk_i            => clk,
      rst_i            => rst,
      s_wbus_cyc_i     => s1_wbus_cyc,
      s_wbus_stall_o   => s1_wbus_stall,
      s_wbus_stb_i     => s1_wbus_stb,
      s_wbus_addr_i    => s1_wbus_addr,
      s_wbus_we_i      => s1_wbus_we,
      s_wbus_wrdat_i   => s1_wbus_wrdat,
      s_wbus_ack_o     => s1_wbus_ack,
      s_wbus_rddat_o   => s1_wbus_rddat,
      m_axil_awready_i => s1_axil_awready,
      m_axil_awvalid_o => s1_axil_awvalid,
      m_axil_awaddr_o  => s1_axil_awaddr,
      m_axil_wready_i  => s1_axil_wready,
      m_axil_wvalid_o  => s1_axil_wvalid,
      m_axil_wdata_o   => s1_axil_wdata,
      m_axil_wstrb_o   => s1_axil_wstrb,
      m_axil_bready_o  => s1_axil_bready,
      m_axil_bvalid_i  => s1_axil_bvalid,
      m_axil_arready_i => s1_axil_arready,
      m_axil_arvalid_o => s1_axil_arvalid,
      m_axil_araddr_o  => s1_axil_araddr,
      m_axil_rready_o  => s1_axil_rready,
      m_axil_rvalid_i  => s1_axil_rvalid,
      m_axil_rdata_i   => s1_axil_rdata
    ); -- wbus_to_axil_1_inst : entity work.wbus_to_axil

  axil_pause_1_inst : entity work.axil_pause
    generic map (
      G_SEED       => (others => '1'),
      G_ID_SIZE    => G_ID_SIZE,
      G_ADDR_SIZE  => G_ADDR_SIZE,
      G_DATA_SIZE  => G_DATA_SIZE,
      G_PAUSE_SIZE => G_PAUSE_SIZE
    )
    port map (
      clk_i       => clk,
      rst_i       => rst,
      s_awready_o => s1_axil_awready,
      s_awvalid_i => s1_axil_awvalid,
      s_awaddr_i  => s1_axil_awaddr,
      s_awid_i    => s1_axil_awid,
      s_wready_o  => s1_axil_wready,
      s_wvalid_i  => s1_axil_wvalid,
      s_wdata_i   => s1_axil_wdata,
      s_wstrb_i   => s1_axil_wstrb,
      s_bready_i  => s1_axil_bready,
      s_bvalid_o  => s1_axil_bvalid,
      s_bid_o     => s1_axil_bid,
      s_arready_o => s1_axil_arready,
      s_arvalid_i => s1_axil_arvalid,
      s_araddr_i  => s1_axil_araddr,
      s_arid_i    => s1_axil_arid,
      s_rready_i  => s1_axil_rready,
      s_rvalid_o  => s1_axil_rvalid,
      s_rdata_o   => s1_axil_rdata,
      s_rid_o     => s1_axil_rid,
      m_awready_i => s1_axil_pause_awready,
      m_awvalid_o => s1_axil_pause_awvalid,
      m_awaddr_o  => s1_axil_pause_awaddr,
      m_awid_o    => s1_axil_pause_awid,
      m_wready_i  => s1_axil_pause_wready,
      m_wvalid_o  => s1_axil_pause_wvalid,
      m_wdata_o   => s1_axil_pause_wdata,
      m_wstrb_o   => s1_axil_pause_wstrb,
      m_bready_o  => s1_axil_pause_bready,
      m_bvalid_i  => s1_axil_pause_bvalid,
      m_bid_i     => s1_axil_pause_bid,
      m_arready_i => s1_axil_pause_arready,
      m_arvalid_o => s1_axil_pause_arvalid,
      m_araddr_o  => s1_axil_pause_araddr,
      m_arid_o    => s1_axil_pause_arid,
      m_rready_o  => s1_axil_pause_rready,
      m_rvalid_i  => s1_axil_pause_rvalid,
      m_rdata_i   => s1_axil_pause_rdata,
      m_rid_i     => s1_axil_pause_rid
    ); -- axil_pause_1_inst : entity work.axil_pause


  --------------------------------
  -- Instantiate Wishbone slave
  --------------------------------

  axil_to_wbus_inst : entity work.axil_to_wbus
    generic map (
      G_TIMEOUT   => 1000,
      G_ID_SIZE   => G_ID_SIZE + 1,
      G_ADDR_SIZE => G_ADDR_SIZE + 1,
      G_DATA_SIZE => G_DATA_SIZE
    )
    port map (
      clk_i            => clk,
      rst_i            => rst,
      s_axil_awready_o => m_axil_awready,
      s_axil_awvalid_i => m_axil_awvalid,
      s_axil_awaddr_i  => m_axil_awaddr,
      s_axil_awid_i    => m_axil_awid,
      s_axil_wready_o  => m_axil_wready,
      s_axil_wvalid_i  => m_axil_wvalid,
      s_axil_wdata_i   => m_axil_wdata,
      s_axil_wstrb_i   => m_axil_wstrb,
      s_axil_bready_i  => m_axil_bready,
      s_axil_bvalid_o  => m_axil_bvalid,
      s_axil_bid_o     => m_axil_bid,
      s_axil_arready_o => m_axil_arready,
      s_axil_arvalid_i => m_axil_arvalid,
      s_axil_araddr_i  => m_axil_araddr,
      s_axil_arid_i    => m_axil_arid,
      s_axil_rready_i  => m_axil_rready,
      s_axil_rvalid_o  => m_axil_rvalid,
      s_axil_rdata_o   => m_axil_rdata,
      s_axil_rid_o     => m_axil_rid,
      m_wbus_cyc_o     => m_wbus_cyc,
      m_wbus_stall_i   => m_wbus_stall,
      m_wbus_stb_o     => m_wbus_stb,
      m_wbus_addr_o    => m_wbus_addr,
      m_wbus_we_o      => m_wbus_we,
      m_wbus_wrdat_o   => m_wbus_wrdat,
      m_wbus_ack_i     => m_wbus_ack,
      m_wbus_rddat_i   => m_wbus_rddat
    ); -- axil_to_wbus_inst : entity work.axil_to_wbus

  wbus_slave_sim_inst : entity work.wbus_slave_sim
    generic map (
      G_DEBUG     => G_DEBUG,
      G_TIMEOUT   => false,
      G_ADDR_SIZE => G_ADDR_SIZE + 1,
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

