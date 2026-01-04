library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std.all;

library std;
  use std.env.stop;

entity tb_axil_arbiter is
  generic (
    G_DEBUG      : boolean;
    G_PAUSE_SIZE : natural;
    G_RANDOM     : boolean;
    G_FAST       : boolean;
    G_ID_SIZE    : natural;
    G_ADDR_SIZE  : natural;
    G_DATA_SIZE  : natural
  );
end entity tb_axil_arbiter;

architecture simulation of tb_axil_arbiter is

  signal clk : std_logic := '1';
  signal rst : std_logic := '1';

  signal s0_awready : std_logic;
  signal s0_awvalid : std_logic;
  signal s0_awaddr  : std_logic_vector(G_ADDR_SIZE - 1 downto 0);
  signal s0_awid    : std_logic_vector(G_ID_SIZE - 1 downto 0);
  signal s0_wready  : std_logic;
  signal s0_wvalid  : std_logic;
  signal s0_wdata   : std_logic_vector(G_DATA_SIZE - 1 downto 0);
  signal s0_wstrb   : std_logic_vector(G_DATA_SIZE / 8 - 1 downto 0);
  signal s0_bready  : std_logic;
  signal s0_bvalid  : std_logic;
  signal s0_bid     : std_logic_vector(G_ID_SIZE - 1 downto 0);
  signal s0_arready : std_logic;
  signal s0_arvalid : std_logic;
  signal s0_araddr  : std_logic_vector(G_ADDR_SIZE - 1 downto 0);
  signal s0_arid    : std_logic_vector(G_ID_SIZE - 1 downto 0);
  signal s0_rready  : std_logic;
  signal s0_rvalid  : std_logic;
  signal s0_rdata   : std_logic_vector(G_DATA_SIZE - 1 downto 0);
  signal s0_rid     : std_logic_vector(G_ID_SIZE - 1 downto 0);

  signal s1_awready : std_logic;
  signal s1_awvalid : std_logic;
  signal s1_awaddr  : std_logic_vector(G_ADDR_SIZE - 1 downto 0);
  signal s1_awid    : std_logic_vector(G_ID_SIZE - 1 downto 0);
  signal s1_wready  : std_logic;
  signal s1_wvalid  : std_logic;
  signal s1_wdata   : std_logic_vector(G_DATA_SIZE - 1 downto 0);
  signal s1_wstrb   : std_logic_vector(G_DATA_SIZE / 8 - 1 downto 0);
  signal s1_bready  : std_logic;
  signal s1_bvalid  : std_logic;
  signal s1_bid     : std_logic_vector(G_ID_SIZE - 1 downto 0);
  signal s1_arready : std_logic;
  signal s1_arvalid : std_logic;
  signal s1_araddr  : std_logic_vector(G_ADDR_SIZE - 1 downto 0);
  signal s1_arid    : std_logic_vector(G_ID_SIZE - 1 downto 0);
  signal s1_rready  : std_logic;
  signal s1_rvalid  : std_logic;
  signal s1_rdata   : std_logic_vector(G_DATA_SIZE - 1 downto 0);
  signal s1_rid     : std_logic_vector(G_ID_SIZE - 1 downto 0);

  signal p0_awready : std_logic;
  signal p0_awvalid : std_logic;
  signal p0_awaddr  : std_logic_vector(G_ADDR_SIZE - 1 downto 0);
  signal p0_awid    : std_logic_vector(G_ID_SIZE - 1 downto 0);
  signal p0_wready  : std_logic;
  signal p0_wvalid  : std_logic;
  signal p0_wdata   : std_logic_vector(G_DATA_SIZE - 1 downto 0);
  signal p0_wstrb   : std_logic_vector(G_DATA_SIZE / 8 - 1 downto 0);
  signal p0_bready  : std_logic;
  signal p0_bvalid  : std_logic;
  signal p0_bid     : std_logic_vector(G_ID_SIZE - 1 downto 0);
  signal p0_arready : std_logic;
  signal p0_arvalid : std_logic;
  signal p0_araddr  : std_logic_vector(G_ADDR_SIZE - 1 downto 0);
  signal p0_arid    : std_logic_vector(G_ID_SIZE - 1 downto 0);
  signal p0_rready  : std_logic;
  signal p0_rvalid  : std_logic;
  signal p0_rdata   : std_logic_vector(G_DATA_SIZE - 1 downto 0);
  signal p0_rid     : std_logic_vector(G_ID_SIZE - 1 downto 0);

  signal p1_awready : std_logic;
  signal p1_awvalid : std_logic;
  signal p1_awaddr  : std_logic_vector(G_ADDR_SIZE - 1 downto 0);
  signal p1_awid    : std_logic_vector(G_ID_SIZE - 1 downto 0);
  signal p1_wready  : std_logic;
  signal p1_wvalid  : std_logic;
  signal p1_wdata   : std_logic_vector(G_DATA_SIZE - 1 downto 0);
  signal p1_wstrb   : std_logic_vector(G_DATA_SIZE / 8 - 1 downto 0);
  signal p1_bready  : std_logic;
  signal p1_bvalid  : std_logic;
  signal p1_bid     : std_logic_vector(G_ID_SIZE - 1 downto 0);
  signal p1_arready : std_logic;
  signal p1_arvalid : std_logic;
  signal p1_araddr  : std_logic_vector(G_ADDR_SIZE - 1 downto 0);
  signal p1_arid    : std_logic_vector(G_ID_SIZE - 1 downto 0);
  signal p1_rready  : std_logic;
  signal p1_rvalid  : std_logic;
  signal p1_rdata   : std_logic_vector(G_DATA_SIZE - 1 downto 0);
  signal p1_rid     : std_logic_vector(G_ID_SIZE - 1 downto 0);

  signal d_awready : std_logic;
  signal d_awvalid : std_logic;
  signal d_awaddr  : std_logic_vector(G_ADDR_SIZE downto 0);
  signal d_awid    : std_logic_vector(G_ID_SIZE downto 0);
  signal d_wready  : std_logic;
  signal d_wvalid  : std_logic;
  signal d_wdata   : std_logic_vector(G_DATA_SIZE - 1 downto 0);
  signal d_wstrb   : std_logic_vector(G_DATA_SIZE / 8 - 1 downto 0);
  signal d_bready  : std_logic;
  signal d_bvalid  : std_logic;
  signal d_bid     : std_logic_vector(G_ID_SIZE downto 0);
  signal d_arready : std_logic;
  signal d_arvalid : std_logic;
  signal d_araddr  : std_logic_vector(G_ADDR_SIZE downto 0);
  signal d_arid    : std_logic_vector(G_ID_SIZE downto 0);
  signal d_rready  : std_logic;
  signal d_rvalid  : std_logic;
  signal d_rdata   : std_logic_vector(G_DATA_SIZE - 1 downto 0);
  signal d_rid     : std_logic_vector(G_ID_SIZE downto 0);

  signal p_awready : std_logic;
  signal p_awvalid : std_logic;
  signal p_awaddr  : std_logic_vector(G_ADDR_SIZE downto 0);
  signal p_awid    : std_logic_vector(G_ID_SIZE downto 0);
  signal p_wready  : std_logic;
  signal p_wvalid  : std_logic;
  signal p_wdata   : std_logic_vector(G_DATA_SIZE - 1 downto 0);
  signal p_wstrb   : std_logic_vector(G_DATA_SIZE / 8 - 1 downto 0);
  signal p_bready  : std_logic;
  signal p_bvalid  : std_logic;
  signal p_bid     : std_logic_vector(G_ID_SIZE downto 0);
  signal p_arready : std_logic;
  signal p_arvalid : std_logic;
  signal p_araddr  : std_logic_vector(G_ADDR_SIZE downto 0);
  signal p_arid    : std_logic_vector(G_ID_SIZE downto 0);
  signal p_rready  : std_logic;
  signal p_rvalid  : std_logic;
  signal p_rdata   : std_logic_vector(G_DATA_SIZE - 1 downto 0);
  signal p_rid     : std_logic_vector(G_ID_SIZE downto 0);

  signal m0_awready : std_logic;
  signal m0_awvalid : std_logic;
  signal m0_awaddr  : std_logic_vector(G_ADDR_SIZE - 1 downto 0);
  signal m0_awid    : std_logic_vector(G_ID_SIZE - 1 downto 0);
  signal m0_wready  : std_logic;
  signal m0_wvalid  : std_logic;
  signal m0_wdata   : std_logic_vector(G_DATA_SIZE - 1 downto 0);
  signal m0_wstrb   : std_logic_vector(G_DATA_SIZE / 8 - 1 downto 0);
  signal m0_bready  : std_logic;
  signal m0_bvalid  : std_logic;
  signal m0_bid     : std_logic_vector(G_ID_SIZE - 1 downto 0);
  signal m0_arready : std_logic;
  signal m0_arvalid : std_logic;
  signal m0_araddr  : std_logic_vector(G_ADDR_SIZE - 1 downto 0);
  signal m0_arid    : std_logic_vector(G_ID_SIZE - 1 downto 0);
  signal m0_rready  : std_logic;
  signal m0_rvalid  : std_logic;
  signal m0_rdata   : std_logic_vector(G_DATA_SIZE - 1 downto 0);
  signal m0_rid     : std_logic_vector(G_ID_SIZE - 1 downto 0);

  signal m1_awready : std_logic;
  signal m1_awvalid : std_logic;
  signal m1_awaddr  : std_logic_vector(G_ADDR_SIZE - 1 downto 0);
  signal m1_awid    : std_logic_vector(G_ID_SIZE - 1 downto 0);
  signal m1_wready  : std_logic;
  signal m1_wvalid  : std_logic;
  signal m1_wdata   : std_logic_vector(G_DATA_SIZE - 1 downto 0);
  signal m1_wstrb   : std_logic_vector(G_DATA_SIZE / 8 - 1 downto 0);
  signal m1_bready  : std_logic;
  signal m1_bvalid  : std_logic;
  signal m1_bid     : std_logic_vector(G_ID_SIZE - 1 downto 0);
  signal m1_arready : std_logic;
  signal m1_arvalid : std_logic;
  signal m1_araddr  : std_logic_vector(G_ADDR_SIZE - 1 downto 0);
  signal m1_arid    : std_logic_vector(G_ID_SIZE - 1 downto 0);
  signal m1_rready  : std_logic;
  signal m1_rvalid  : std_logic;
  signal m1_rdata   : std_logic_vector(G_DATA_SIZE - 1 downto 0);
  signal m1_rid     : std_logic_vector(G_ID_SIZE - 1 downto 0);

  signal s0_busy : std_logic;
  signal s1_busy : std_logic;

begin

  ----------------------------------------------
  -- Clock and Reset
  ----------------------------------------------

  clk <= not clk after 5 ns;
  rst <= '1', '0' after 100 ns;


  ----------------------------------------------
  -- Instantiate DUT
  ----------------------------------------------

  axil_arbiter_inst : entity work.axil_arbiter
    generic map (
      G_ID_SIZE   => G_ID_SIZE,
      G_ADDR_SIZE => G_ADDR_SIZE + 1,
      G_DATA_SIZE => G_DATA_SIZE
    )
    port map (
      clk_i        => clk,
      rst_i        => rst,
      s0_awready_o => p0_awready,
      s0_awvalid_i => p0_awvalid,
      s0_awaddr_i  => "0" & p0_awaddr,
      s0_awid_i    => p0_awid,
      s0_wready_o  => p0_wready,
      s0_wvalid_i  => p0_wvalid,
      s0_wdata_i   => p0_wdata,
      s0_wstrb_i   => p0_wstrb,
      s0_bready_i  => p0_bready,
      s0_bvalid_o  => p0_bvalid,
      s0_bid_o     => p0_bid,
      s0_arready_o => p0_arready,
      s0_arvalid_i => p0_arvalid,
      s0_araddr_i  => "0" & p0_araddr,
      s0_arid_i    => p0_arid,
      s0_rready_i  => p0_rready,
      s0_rvalid_o  => p0_rvalid,
      s0_rdata_o   => p0_rdata,
      s0_rid_o     => p0_rid,
      s1_awready_o => p1_awready,
      s1_awvalid_i => p1_awvalid,
      s1_awaddr_i  => "1" & p1_awaddr,
      s1_awid_i    => p1_awid,
      s1_wready_o  => p1_wready,
      s1_wvalid_i  => p1_wvalid,
      s1_wdata_i   => p1_wdata,
      s1_wstrb_i   => p1_wstrb,
      s1_bready_i  => p1_bready,
      s1_bvalid_o  => p1_bvalid,
      s1_bid_o     => p1_bid,
      s1_arready_o => p1_arready,
      s1_arvalid_i => p1_arvalid,
      s1_araddr_i  => "1" & p1_araddr,
      s1_arid_i    => p1_arid,
      s1_rready_i  => p1_rready,
      s1_rvalid_o  => p1_rvalid,
      s1_rdata_o   => p1_rdata,
      s1_rid_o     => p1_rid,
      m_awready_i  => d_awready,
      m_awvalid_o  => d_awvalid,
      m_awaddr_o   => d_awaddr,
      m_awid_o     => d_awid,
      m_wready_i   => d_wready,
      m_wvalid_o   => d_wvalid,
      m_wdata_o    => d_wdata,
      m_wstrb_o    => d_wstrb,
      m_bready_o   => d_bready,
      m_bvalid_i   => d_bvalid,
      m_bid_i      => d_bid,
      m_arready_i  => d_arready,
      m_arvalid_o  => d_arvalid,
      m_araddr_o   => d_araddr,
      m_arid_o     => d_arid,
      m_rready_o   => d_rready,
      m_rvalid_i   => d_rvalid,
      m_rdata_i    => d_rdata,
      m_rid_i      => d_rid
    ); -- axil_arbiter_inst : entity work.axil_arbiter


  ----------------------------------------------
  -- Instantiate AXI lite masters
  ----------------------------------------------

  axil_master_sim_0_inst : entity work.axil_master_sim
    generic map (
      G_SEED      => X"1234567887654321",
      G_OFFSET    => 1234,
      G_DEBUG     => G_DEBUG,
      G_RANDOM    => G_RANDOM,
      G_FAST      => G_FAST,
      G_ID_SIZE   => G_ID_SIZE,
      G_ADDR_SIZE => G_ADDR_SIZE,
      G_DATA_SIZE => G_DATA_SIZE
    )
    port map (
      clk_i       => clk,
      rst_i       => rst,
      m_awready_i => s0_awready,
      m_awvalid_o => s0_awvalid,
      m_awaddr_o  => s0_awaddr,
      m_awid_o    => s0_awid,
      m_wready_i  => s0_wready,
      m_wvalid_o  => s0_wvalid,
      m_wdata_o   => s0_wdata,
      m_wstrb_o   => s0_wstrb,
      m_bready_o  => s0_bready,
      m_bvalid_i  => s0_bvalid,
      m_bid_i     => s0_bid,
      m_arready_i => s0_arready,
      m_arvalid_o => s0_arvalid,
      m_araddr_o  => s0_araddr,
      m_arid_o    => s0_arid,
      m_rready_o  => s0_rready,
      m_rvalid_i  => s0_rvalid,
      m_rdata_i   => s0_rdata,
      m_rid_i     => s0_rid
    ); -- axil_master_sim_0_inst : entity work.axil_master_sim

  axil_master_sim_1_inst : entity work.axil_master_sim
    generic map (
      G_SEED      => X"ABCDEFABCDEFABCD",
      G_OFFSET    => 4321,
      G_DEBUG     => G_DEBUG,
      G_RANDOM    => G_RANDOM,
      G_FAST      => G_FAST,
      G_ID_SIZE   => G_ID_SIZE,
      G_ADDR_SIZE => G_ADDR_SIZE,
      G_DATA_SIZE => G_DATA_SIZE
    )
    port map (
      clk_i       => clk,
      rst_i       => rst,
      m_awready_i => s1_awready,
      m_awvalid_o => s1_awvalid,
      m_awaddr_o  => s1_awaddr,
      m_awid_o    => s1_awid,
      m_wready_i  => s1_wready,
      m_wvalid_o  => s1_wvalid,
      m_wdata_o   => s1_wdata,
      m_wstrb_o   => s1_wstrb,
      m_bready_o  => s1_bready,
      m_bvalid_i  => s1_bvalid,
      m_bid_i     => s1_bid,
      m_arready_i => s1_arready,
      m_arvalid_o => s1_arvalid,
      m_araddr_o  => s1_araddr,
      m_arid_o    => s1_arid,
      m_rready_o  => s1_rready,
      m_rvalid_i  => s1_rvalid,
      m_rdata_i   => s1_rdata,
      m_rid_i     => s1_rid
    ); -- axil_master_sim_1_inst : entity work.axil_master_sim


  ----------------------------------------------
  -- Instantiate AXI lite pauses
  ----------------------------------------------

  axil_pause_0_inst : entity work.axil_pause
    generic map (
      G_SEED       => X"8765432112345678",
      G_ID_SIZE    => G_ID_SIZE,
      G_ADDR_SIZE  => G_ADDR_SIZE,
      G_DATA_SIZE  => G_DATA_SIZE,
      G_PAUSE_SIZE => G_PAUSE_SIZE
    )
    port map (
      clk_i       => clk,
      rst_i       => rst,
      s_awready_o => s0_awready,
      s_awvalid_i => s0_awvalid,
      s_awaddr_i  => s0_awaddr,
      s_awid_i    => s0_awid,
      s_wready_o  => s0_wready,
      s_wvalid_i  => s0_wvalid,
      s_wdata_i   => s0_wdata,
      s_wstrb_i   => s0_wstrb,
      s_bready_i  => s0_bready,
      s_bvalid_o  => s0_bvalid,
      s_bid_o     => s0_bid,
      s_arready_o => s0_arready,
      s_arvalid_i => s0_arvalid,
      s_araddr_i  => s0_araddr,
      s_arid_i    => s0_arid,
      s_rready_i  => s0_rready,
      s_rvalid_o  => s0_rvalid,
      s_rdata_o   => s0_rdata,
      s_rid_o     => s0_rid,
      m_awready_i => p0_awready,
      m_awvalid_o => p0_awvalid,
      m_awaddr_o  => p0_awaddr,
      m_awid_o    => p0_awid,
      m_wready_i  => p0_wready,
      m_wvalid_o  => p0_wvalid,
      m_wdata_o   => p0_wdata,
      m_wstrb_o   => p0_wstrb,
      m_bready_o  => p0_bready,
      m_bvalid_i  => p0_bvalid,
      m_bid_i     => p0_bid,
      m_arready_i => p0_arready,
      m_arvalid_o => p0_arvalid,
      m_araddr_o  => p0_araddr,
      m_arid_o    => p0_arid,
      m_rready_o  => p0_rready,
      m_rvalid_i  => p0_rvalid,
      m_rdata_i   => p0_rdata,
      m_rid_i     => p0_rid
    ); -- axil_pause_0_inst : entity work.axil_pause

  axil_pause_1_inst : entity work.axil_pause
    generic map (
      G_SEED       => X"ABCDEFABCDEFABCD",
      G_ID_SIZE    => G_ID_SIZE,
      G_ADDR_SIZE  => G_ADDR_SIZE,
      G_DATA_SIZE  => G_DATA_SIZE,
      G_PAUSE_SIZE => G_PAUSE_SIZE
    )
    port map (
      clk_i       => clk,
      rst_i       => rst,
      s_awready_o => s1_awready,
      s_awvalid_i => s1_awvalid,
      s_awaddr_i  => s1_awaddr,
      s_awid_i    => s1_awid,
      s_wready_o  => s1_wready,
      s_wvalid_i  => s1_wvalid,
      s_wdata_i   => s1_wdata,
      s_wstrb_i   => s1_wstrb,
      s_bready_i  => s1_bready,
      s_bvalid_o  => s1_bvalid,
      s_bid_o     => s1_bid,
      s_arready_o => s1_arready,
      s_arvalid_i => s1_arvalid,
      s_araddr_i  => s1_araddr,
      s_arid_i    => s1_arid,
      s_rready_i  => s1_rready,
      s_rvalid_o  => s1_rvalid,
      s_rdata_o   => s1_rdata,
      s_rid_o     => s1_rid,
      m_awready_i => p1_awready,
      m_awvalid_o => p1_awvalid,
      m_awaddr_o  => p1_awaddr,
      m_awid_o    => p1_awid,
      m_wready_i  => p1_wready,
      m_wvalid_o  => p1_wvalid,
      m_wdata_o   => p1_wdata,
      m_wstrb_o   => p1_wstrb,
      m_bready_o  => p1_bready,
      m_bvalid_i  => p1_bvalid,
      m_bid_i     => p1_bid,
      m_arready_i => p1_arready,
      m_arvalid_o => p1_arvalid,
      m_araddr_o  => p1_araddr,
      m_arid_o    => p1_arid,
      m_rready_o  => p1_rready,
      m_rvalid_i  => p1_rvalid,
      m_rdata_i   => p1_rdata,
      m_rid_i     => p1_rid
    ); -- axil_pause_1_inst : entity work.axil_pause

  axil_pause_d_inst : entity work.axil_pause
    generic map (
      G_SEED       => X"DEADBEEFC007BABE",
      G_ID_SIZE    => G_ID_SIZE + 1,
      G_ADDR_SIZE  => G_ADDR_SIZE + 1,
      G_DATA_SIZE  => G_DATA_SIZE,
      G_PAUSE_SIZE => G_PAUSE_SIZE
    )
    port map (
      clk_i       => clk,
      rst_i       => rst,
      s_awready_o => d_awready,
      s_awvalid_i => d_awvalid,
      s_awaddr_i  => d_awaddr,
      s_awid_i    => d_awid,
      s_wready_o  => d_wready,
      s_wvalid_i  => d_wvalid,
      s_wdata_i   => d_wdata,
      s_wstrb_i   => d_wstrb,
      s_bready_i  => d_bready,
      s_bvalid_o  => d_bvalid,
      s_bid_o     => d_bid,
      s_arready_o => d_arready,
      s_arvalid_i => d_arvalid,
      s_araddr_i  => d_araddr,
      s_arid_i    => d_arid,
      s_rready_i  => d_rready,
      s_rvalid_o  => d_rvalid,
      s_rdata_o   => d_rdata,
      s_rid_o     => d_rid,
      m_awready_i => p_awready,
      m_awvalid_o => p_awvalid,
      m_awaddr_o  => p_awaddr,
      m_awid_o    => p_awid,
      m_wready_i  => p_wready,
      m_wvalid_o  => p_wvalid,
      m_wdata_o   => p_wdata,
      m_wstrb_o   => p_wstrb,
      m_bready_o  => p_bready,
      m_bvalid_i  => p_bvalid,
      m_bid_i     => p_bid,
      m_arready_i => p_arready,
      m_arvalid_o => p_arvalid,
      m_araddr_o  => p_araddr,
      m_arid_o    => p_arid,
      m_rready_o  => p_rready,
      m_rvalid_i  => p_rvalid,
      m_rdata_i   => p_rdata,
      m_rid_i     => p_rid
    ); -- axil_pause_d_inst : entity work.axil_pause


  ----------------------------------------------
  -- Instantiate AXI lite slave
  ----------------------------------------------

  axil_slave_sim_inst : entity work.axil_slave_sim
    generic map (
      G_DEBUG     => G_DEBUG,
      G_FAST      => G_FAST,
      G_ID_SIZE   => G_ID_SIZE + 1,
      G_ADDR_SIZE => G_ADDR_SIZE + 1,
      G_DATA_SIZE => G_DATA_SIZE
    )
    port map (
      clk_i       => clk,
      rst_i       => rst,
      s_awready_o => p_awready,
      s_awvalid_i => p_awvalid,
      s_awaddr_i  => p_awaddr,
      s_awid_i    => p_awid,
      s_wready_o  => p_wready,
      s_wvalid_i  => p_wvalid,
      s_wdata_i   => p_wdata,
      s_wstrb_i   => p_wstrb,
      s_bready_i  => p_bready,
      s_bvalid_o  => p_bvalid,
      s_bid_o     => p_bid,
      s_arready_o => p_arready,
      s_arvalid_i => p_arvalid,
      s_araddr_i  => p_araddr,
      s_arid_i    => p_arid,
      s_rready_i  => p_rready,
      s_rvalid_o  => p_rvalid,
      s_rdata_o   => p_rdata,
      s_rid_o     => p_rid
    ); -- axil_slave_sim_inst : entity work.axil_slave_sim


  ----------------------------------------------
  -- Check
  ----------------------------------------------

  -- s0_busy and s1_busy are asserted when either a AW or W transaction is completed, but not
  -- both.
  axil_busy_0_inst : entity work.axil_busy
    port map (
      clk_i     => clk,
      rst_i     => rst,
      awready_i => s0_awready,
      awvalid_i => s0_awvalid,
      wready_i  => s0_wready,
      wvalid_i  => s0_wvalid,
      busy_o    => s0_busy
    ); -- axil_busy_0_inst : entity work.axil_busy

  axil_busy_1_inst : entity work.axil_busy
    port map (
      clk_i     => clk,
      rst_i     => rst,
      awready_i => s1_awready,
      awvalid_i => s1_awvalid,
      wready_i  => s1_wready,
      wvalid_i  => s1_wvalid,
      busy_o    => s1_busy
    ); -- axil_busy_1_inst : entity work.axil_busy

  assert (s0_busy and s1_busy) /= '1'
    report "axi_lite_arbiter: ERROR: Both slaves busy";


end architecture simulation;

