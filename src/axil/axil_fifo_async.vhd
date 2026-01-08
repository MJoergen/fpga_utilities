library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std.all;

-- This provides a Clock Domain Crossing (i.e. an asynchronuous FIFO) for a AXI Lite
-- interface.

-- Each of the five channels (AW, W, B, AR, and R) use their own separate async FIFO,
-- so you can not make any assumptions about the relative timings between these channels.

entity axil_fifo_async is
  generic (
    G_WR_DEPTH  : natural := 16; -- Channels AW, W, and AR
    G_RD_DEPTH  : natural := 16; -- Channels B and R
    G_ADDR_SIZE : natural;
    G_DATA_SIZE : natural
  );
  port (
    -- Connect to AXI Lite Master
    s_aclk_i        : in    std_logic;
    s_aresetn_i     : in    std_logic;
    s_axi_awaddr_i  : in    std_logic_vector(G_ADDR_SIZE - 1 downto 0);
    s_axi_awlen_i   : in    std_logic_vector(7 downto 0);
    s_axi_awsize_i  : in    std_logic_vector(2 downto 0);
    s_axi_awburst_i : in    std_logic_vector(1 downto 0);
    s_axi_awprot_i  : in    std_logic_vector(2 downto 0);
    s_axi_awvalid_i : in    std_logic;
    s_axi_awready_o : out   std_logic;
    s_axi_awlock_i  : in    std_logic;
    s_axi_awcache_i : in    std_logic_vector(3 downto 0);
    s_axi_wdata_i   : in    std_logic_vector(G_DATA_SIZE - 1 downto 0);
    s_axi_wstrb_i   : in    std_logic_vector(G_DATA_SIZE / 8 - 1 downto 0);
    s_axi_wlast_i   : in    std_logic;
    s_axi_wvalid_i  : in    std_logic;
    s_axi_wready_o  : out   std_logic;
    s_axi_bresp_o   : out   std_logic_vector(1 downto 0);
    s_axi_bvalid_o  : out   std_logic;
    s_axi_bready_i  : in    std_logic;
    s_axi_araddr_i  : in    std_logic_vector(G_ADDR_SIZE - 1 downto 0);
    s_axi_arlen_i   : in    std_logic_vector(7 downto 0);
    s_axi_arsize_i  : in    std_logic_vector(2 downto 0);
    s_axi_arburst_i : in    std_logic_vector(1 downto 0);
    s_axi_arprot_i  : in    std_logic_vector(2 downto 0);
    s_axi_arvalid_i : in    std_logic;
    s_axi_arready_o : out   std_logic;
    s_axi_arlock_i  : in    std_logic;
    s_axi_arcache_i : in    std_logic_vector(3 downto 0);
    s_axi_rdata_o   : out   std_logic_vector(G_DATA_SIZE - 1 downto 0);
    s_axi_rresp_o   : out   std_logic_vector(1 downto 0);
    s_axi_rlast_o   : out   std_logic;
    s_axi_rvalid_o  : out   std_logic;
    s_axi_rready_i  : in    std_logic;

    -- Connect to AXI Lite Slave
    m_aclk_i        : in    std_logic;
    m_aresetn_i     : in    std_logic;
    m_axi_awaddr_o  : out   std_logic_vector(G_ADDR_SIZE - 1 downto 0);
    m_axi_awlen_o   : out   std_logic_vector(7 downto 0);
    m_axi_awsize_o  : out   std_logic_vector(2 downto 0);
    m_axi_awburst_o : out   std_logic_vector(1 downto 0);
    m_axi_awprot_o  : out   std_logic_vector(2 downto 0);
    m_axi_awvalid_o : out   std_logic;
    m_axi_awready_i : in    std_logic;
    m_axi_awlock_o  : out   std_logic;
    m_axi_awcache_o : out   std_logic_vector(3 downto 0);
    m_axi_wdata_o   : out   std_logic_vector(G_DATA_SIZE - 1 downto 0);
    m_axi_wstrb_o   : out   std_logic_vector(G_DATA_SIZE / 8 - 1 downto 0);
    m_axi_wlast_o   : out   std_logic;
    m_axi_wvalid_o  : out   std_logic;
    m_axi_wready_i  : in    std_logic;
    m_axi_bresp_i   : in    std_logic_vector(1 downto 0);
    m_axi_bvalid_i  : in    std_logic;
    m_axi_bready_o  : out   std_logic;
    m_axi_araddr_o  : out   std_logic_vector(G_ADDR_SIZE - 1 downto 0);
    m_axi_arlen_o   : out   std_logic_vector(7 downto 0);
    m_axi_arsize_o  : out   std_logic_vector(2 downto 0);
    m_axi_arburst_o : out   std_logic_vector(1 downto 0);
    m_axi_arprot_o  : out   std_logic_vector(2 downto 0);
    m_axi_arvalid_o : out   std_logic;
    m_axi_arready_i : in    std_logic;
    m_axi_arlock_o  : out   std_logic;
    m_axi_arcache_o : out   std_logic_vector(3 downto 0);
    m_axi_rdata_i   : in    std_logic_vector(G_DATA_SIZE - 1 downto 0);
    m_axi_rresp_i   : in    std_logic_vector(1 downto 0);
    m_axi_rlast_i   : in    std_logic;
    m_axi_rvalid_i  : in    std_logic;
    m_axi_rready_o  : out   std_logic
  );
end entity axil_fifo_async;

architecture synthesis of axil_fifo_async is

  constant C_USER_SIZE_AW : natural := 24;
  subtype  R_USER_AWLEN    is natural range  7 downto  0;
  subtype  R_USER_AWSIZE   is natural range 10 downto  8;
  subtype  R_USER_AWBURST  is natural range 12 downto 11;
  subtype  R_USER_AWPROT   is natural range 15 downto 13;
  constant C_USER_AWLOCK  : natural := 16;
  subtype  R_USER_AWCACHE  is natural range 20 downto 17;
  signal   s_axi_awuser   : std_logic_vector(C_USER_SIZE_AW - 1 downto 0);
  signal   m_axi_awuser   : std_logic_vector(C_USER_SIZE_AW - 1 downto 0);

  constant C_USER_SIZE_B : natural  := 8;
  subtype  R_USER_BRESP is natural range 1 downto 0;
  signal   m_axi_buser   : std_logic_vector(C_USER_SIZE_B - 1 downto 0);
  signal   s_axi_buser   : std_logic_vector(C_USER_SIZE_B - 1 downto 0);

  constant C_USER_SIZE_AR : natural := 24;
  subtype  R_USER_ARLEN    is natural range  7 downto  0;
  subtype  R_USER_ARSIZE   is natural range 10 downto  8;
  subtype  R_USER_ARBURST  is natural range 12 downto 11;
  subtype  R_USER_ARPROT   is natural range 15 downto 13;
  constant C_USER_ARLOCK  : natural := 16;
  subtype  R_USER_ARCACHE  is natural range 20 downto 17;
  signal   s_axi_aruser   : std_logic_vector(C_USER_SIZE_AR - 1 downto 0);
  signal   m_axi_aruser   : std_logic_vector(C_USER_SIZE_AR - 1 downto 0);

  constant C_USER_SIZE_R : natural  := 8;
  subtype  R_USER_RRESP is natural range 1 downto 0;
  signal   m_axi_ruser   : std_logic_vector(C_USER_SIZE_R - 1 downto 0);
  signal   s_axi_ruser   : std_logic_vector(C_USER_SIZE_R - 1 downto 0);

begin

  --------------------------------------------------------
  -- AW stream
  --------------------------------------------------------

  s_axi_awuser(R_USER_AWLEN)   <= s_axi_awlen_i;
  s_axi_awuser(R_USER_AWSIZE)  <= s_axi_awsize_i;
  s_axi_awuser(R_USER_AWBURST) <= s_axi_awburst_i;
  s_axi_awuser(R_USER_AWPROT)  <= s_axi_awprot_i;
  s_axi_awuser(C_USER_AWLOCK)  <= s_axi_awlock_i;
  s_axi_awuser(R_USER_AWCACHE) <= s_axi_awcache_i;

  axip_fifo_async_aw_inst : entity work.axip_fifo_async
    generic map (
      G_DEPTH     => G_WR_DEPTH,
      G_FILL_SIZE => 1,
      G_DATA_SIZE => G_ADDR_SIZE,
      G_USER_SIZE => C_USER_SIZE_AW
    )
    port map (
      s_aclk_i        => s_aclk_i,
      s_aresetn_i     => s_aresetn_i,
      s_axis_tready_o => s_axi_awready_o,
      s_axis_tvalid_i => s_axi_awvalid_i,
      s_axis_tdata_i  => s_axi_awaddr_i,
      s_axis_tkeep_i  => (others => '1'),
      s_axis_tlast_i  => '1',
      s_axis_tuser_i  => s_axi_awuser,
      s_fill_o        => open,
      m_aclk_i        => m_aclk_i,
      m_axis_tready_i => m_axi_awready_i,
      m_axis_tvalid_o => m_axi_awvalid_o,
      m_axis_tdata_o  => m_axi_awaddr_o,
      m_axis_tkeep_o  => open,
      m_axis_tlast_o  => open,
      m_axis_tuser_o  => m_axi_awuser,
      m_fill_o        => open
    ); -- axip_fifo_async_aw_inst : entity work.axip_fifo_async

  m_axi_awlen_o   <= s_axi_awuser(R_USER_AWLEN);
  m_axi_awsize_o  <= s_axi_awuser(R_USER_AWSIZE);
  m_axi_awburst_o <= s_axi_awuser(R_USER_AWBURST);
  m_axi_awprot_o  <= s_axi_awuser(R_USER_AWPROT);
  m_axi_awlock_o  <= s_axi_awuser(C_USER_AWLOCK);
  m_axi_awcache_o <= s_axi_awuser(R_USER_AWCACHE);


  --------------------------------------------------------
  -- W stream
  --------------------------------------------------------

  axip_fifo_async_w_inst : entity work.axip_fifo_async
    generic map (
      G_DEPTH     => G_WR_DEPTH,
      G_FILL_SIZE => 1,
      G_DATA_SIZE => G_DATA_SIZE,
      G_USER_SIZE => G_DATA_SIZE / 8
    )
    port map (
      s_aclk_i        => s_aclk_i,
      s_aresetn_i     => s_aresetn_i,
      s_axis_tready_o => s_axi_wready_o,
      s_axis_tvalid_i => s_axi_wvalid_i,
      s_axis_tdata_i  => s_axi_wdata_i,
      s_axis_tkeep_i  => (others => '1'),
      s_axis_tlast_i  => s_axi_wlast_i,
      s_axis_tuser_i  => s_axi_wstrb_i,
      s_fill_o        => open,
      m_aclk_i        => m_aclk_i,
      m_axis_tready_i => m_axi_wready_i,
      m_axis_tvalid_o => m_axi_wvalid_o,
      m_axis_tdata_o  => m_axi_wdata_o,
      m_axis_tkeep_o  => open,
      m_axis_tlast_o  => m_axi_wlast_o,
      m_axis_tuser_o  => m_axi_wstrb_o,
      m_fill_o        => open
    ); -- axip_fifo_async_w_inst : entity work.axip_fifo_async


  --------------------------------------------------------
  -- B stream
  --------------------------------------------------------

  m_axi_buser(R_USER_BRESP) <= m_axi_bresp_i;

  axip_fifo_async_b_inst : entity work.axip_fifo_async
    generic map (
      G_DEPTH     => G_RD_DEPTH,
      G_FILL_SIZE => 1,
      G_DATA_SIZE => 8,
      G_USER_SIZE => C_USER_SIZE_B
    )
    port map (
      s_aclk_i        => m_aclk_i,
      s_aresetn_i     => m_aresetn_i,
      s_axis_tready_o => m_axi_bready_o,
      s_axis_tvalid_i => m_axi_bvalid_i,
      s_axis_tdata_i  => (others => '0'),
      s_axis_tkeep_i  => (others => '1'),
      s_axis_tlast_i  => '1',
      s_axis_tuser_i  => m_axi_buser,
      s_fill_o        => open,
      m_aclk_i        => s_aclk_i,
      m_axis_tready_i => s_axi_bready_i,
      m_axis_tvalid_o => s_axi_bvalid_o,
      m_axis_tdata_o  => open,
      m_axis_tkeep_o  => open,
      m_axis_tlast_o  => open,
      m_axis_tuser_o  => s_axi_buser,
      m_fill_o        => open
    ); -- axip_fifo_async_b_inst : entity work.axip_fifo_async

  s_axi_bresp_o                <= s_axi_buser(R_USER_BRESP);


  --------------------------------------------------------
  -- AR stream
  --------------------------------------------------------

  s_axi_aruser(R_USER_ARLEN)   <= s_axi_arlen_i;
  s_axi_aruser(R_USER_ARSIZE)  <= s_axi_arsize_i;
  s_axi_aruser(R_USER_ARBURST) <= s_axi_arburst_i;
  s_axi_aruser(R_USER_ARPROT)  <= s_axi_arprot_i;
  s_axi_aruser(C_USER_ARLOCK)  <= s_axi_arlock_i;
  s_axi_aruser(R_USER_ARCACHE) <= s_axi_arcache_i;

  axip_fifo_async_ar_inst : entity work.axip_fifo_async
    generic map (
      G_DEPTH     => G_WR_DEPTH,
      G_FILL_SIZE => 1,
      G_DATA_SIZE => G_ADDR_SIZE,
      G_USER_SIZE => C_USER_SIZE_AR
    )
    port map (
      s_aclk_i        => s_aclk_i,
      s_aresetn_i     => s_aresetn_i,
      s_axis_tready_o => s_axi_arready_o,
      s_axis_tvalid_i => s_axi_arvalid_i,
      s_axis_tdata_i  => s_axi_araddr_i,
      s_axis_tkeep_i  => (others => '1'),
      s_axis_tlast_i  => '1',
      s_axis_tuser_i  => s_axi_aruser,
      s_fill_o        => open,
      m_aclk_i        => m_aclk_i,
      m_axis_tready_i => m_axi_arready_i,
      m_axis_tvalid_o => m_axi_arvalid_o,
      m_axis_tdata_o  => m_axi_araddr_o,
      m_axis_tkeep_o  => open,
      m_axis_tlast_o  => open,
      m_axis_tuser_o  => m_axi_aruser,
      m_fill_o        => open
    ); -- axip_fifo_async_ar_inst : entity work.axip_fifo_async

  m_axi_arlen_o             <= m_axi_aruser(R_USER_ARLEN);
  m_axi_arsize_o            <= m_axi_aruser(R_USER_ARSIZE);
  m_axi_arburst_o           <= m_axi_aruser(R_USER_ARBURST);
  m_axi_arprot_o            <= m_axi_aruser(R_USER_ARPROT);
  m_axi_arlock_o            <= m_axi_aruser(C_USER_ARLOCK);
  m_axi_arcache_o           <= m_axi_aruser(R_USER_ARCACHE);


  --------------------------------------------------------
  -- R stream
  --------------------------------------------------------

  m_axi_ruser(R_USER_RRESP) <= m_axi_rresp_i;

  axip_fifo_async_r_inst : entity work.axip_fifo_async
    generic map (
      G_DEPTH     => G_RD_DEPTH,
      G_FILL_SIZE => 1,
      G_DATA_SIZE => G_DATA_SIZE,
      G_USER_SIZE => C_USER_SIZE_B
    )
    port map (
      s_aclk_i        => m_aclk_i,
      s_aresetn_i     => m_aresetn_i,
      s_axis_tready_o => m_axi_rready_o,
      s_axis_tvalid_i => m_axi_rvalid_i,
      s_axis_tdata_i  => m_axi_rdata_i,
      s_axis_tkeep_i  => (others => '1'),
      s_axis_tlast_i  => m_axi_rlast_i,
      s_axis_tuser_i  => m_axi_ruser,
      s_fill_o        => open,
      m_aclk_i        => s_aclk_i,
      m_axis_tready_i => s_axi_rready_i,
      m_axis_tvalid_o => s_axi_rvalid_o,
      m_axis_tdata_o  => s_axi_rdata_o,
      m_axis_tkeep_o  => open,
      m_axis_tlast_o  => s_axi_rlast_o,
      m_axis_tuser_o  => s_axi_ruser,
      m_fill_o        => open
    ); -- axip_fifo_async_r_inst : entity work.axip_fifo_async

  s_axi_rresp_o <= s_axi_ruser(R_USER_RRESP);

end architecture synthesis;

