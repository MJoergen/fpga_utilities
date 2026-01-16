-- ---------------------------------------------------------------------------------------
-- Description: This provides a Clock Domain Crossing (i.e. an asynchronuous FIFO) for a
-- AXI Lite interface.  Each of the five channels (AW, W, B, AR, and R) use their own
-- separate async FIFO, so you can not make any assumptions about the relative timings
-- between these channels.
-- ---------------------------------------------------------------------------------------

library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std.all;

entity axil_fifo_async is
  generic (
    G_WR_DEPTH  : natural := 16; -- Channels AW, W, and AR
    G_RD_DEPTH  : natural := 16; -- Channels B and R
    G_ADDR_SIZE : natural;
    G_DATA_SIZE : natural
  );
  port (
    -- Connect to AXI Lite Master
    s_clk_i     : in    std_logic;
    s_rst_i     : in    std_logic;
    s_awready_o : out   std_logic;
    s_awvalid_i : in    std_logic;
    s_awaddr_i  : in    std_logic_vector(G_ADDR_SIZE - 1 downto 0);
    s_wready_o  : out   std_logic;
    s_wvalid_i  : in    std_logic;
    s_wdata_i   : in    std_logic_vector(G_DATA_SIZE - 1 downto 0);
    s_wstrb_i   : in    std_logic_vector(G_DATA_SIZE / 8 - 1 downto 0);
    s_bready_i  : in    std_logic;
    s_bvalid_o  : out   std_logic;
    s_bresp_o   : out   std_logic_vector(1 downto 0);
    s_arready_o : out   std_logic;
    s_arvalid_i : in    std_logic;
    s_araddr_i  : in    std_logic_vector(G_ADDR_SIZE - 1 downto 0);
    s_rready_i  : in    std_logic;
    s_rvalid_o  : out   std_logic;
    s_rdata_o   : out   std_logic_vector(G_DATA_SIZE - 1 downto 0);
    s_rresp_o   : out   std_logic_vector(1 downto 0);

    -- Connect to AXI Lite Slave
    m_clk_i     : in    std_logic;
    m_rst_i     : in    std_logic;
    m_awready_i : in    std_logic;
    m_awvalid_o : out   std_logic;
    m_awaddr_o  : out   std_logic_vector(G_ADDR_SIZE - 1 downto 0);
    m_wready_i  : in    std_logic;
    m_wvalid_o  : out   std_logic;
    m_wdata_o   : out   std_logic_vector(G_DATA_SIZE - 1 downto 0);
    m_wstrb_o   : out   std_logic_vector(G_DATA_SIZE / 8 - 1 downto 0);
    m_bready_o  : out   std_logic;
    m_bvalid_i  : in    std_logic;
    m_bresp_i   : in    std_logic_vector(1 downto 0);
    m_arready_i : in    std_logic;
    m_arvalid_o : out   std_logic;
    m_araddr_o  : out   std_logic_vector(G_ADDR_SIZE - 1 downto 0);
    m_rready_o  : out   std_logic;
    m_rvalid_i  : in    std_logic;
    m_rdata_i   : in    std_logic_vector(G_DATA_SIZE - 1 downto 0);
    m_rresp_i   : in    std_logic_vector(1 downto 0)
  );
end entity axil_fifo_async;

architecture synthesis of axil_fifo_async is

  subtype R_WDATA is natural range G_DATA_SIZE - 1 downto 0;

  subtype R_WSTRB is natural range G_DATA_SIZE + G_DATA_SIZE / 8 - 1 downto G_DATA_SIZE;

  signal  s_w_in  : std_logic_vector(G_DATA_SIZE + G_DATA_SIZE / 8 - 1 downto 0);
  signal  m_w_out : std_logic_vector(G_DATA_SIZE + G_DATA_SIZE / 8 - 1 downto 0);

  subtype R_RDATA is natural range G_DATA_SIZE - 1 downto 0;

  subtype R_RRESP is natural range G_DATA_SIZE + 1 downto G_DATA_SIZE;

  signal  m_r_in  : std_logic_vector(G_DATA_SIZE + 1 downto 0);
  signal  s_r_out : std_logic_vector(G_DATA_SIZE + 1 downto 0);

begin

  --------------------------------------------------------
  -- AW stream
  --------------------------------------------------------

  axis_fifo_async_aw_inst : entity work.axis_fifo_async
    generic map (
      G_DEPTH     => G_WR_DEPTH,
      G_DATA_SIZE => G_ADDR_SIZE
    )
    port map (
      s_clk_i   => s_clk_i,
      s_rst_i   => s_rst_i,
      s_ready_o => s_awready_o,
      s_valid_i => s_awvalid_i,
      s_data_i  => s_awaddr_i,
      s_fill_o  => open,
      m_clk_i   => m_clk_i,
      m_ready_i => m_awready_i,
      m_valid_o => m_awvalid_o,
      m_data_o  => m_awaddr_o,
      m_fill_o  => open
    ); -- axis_fifo_async_aw_inst : entity work.axis_fifo_async


  --------------------------------------------------------
  -- W stream
  --------------------------------------------------------

  axis_fifo_async_w_inst : entity work.axis_fifo_async
    generic map (
      G_DEPTH     => G_WR_DEPTH,
      G_DATA_SIZE => G_DATA_SIZE + G_DATA_SIZE / 8
    )
    port map (
      s_clk_i   => s_clk_i,
      s_rst_i   => s_rst_i,
      s_ready_o => s_wready_o,
      s_valid_i => s_wvalid_i,
      s_data_i  => s_w_in,
      s_fill_o  => open,
      m_clk_i   => m_clk_i,
      m_ready_i => m_wready_i,
      m_valid_o => m_wvalid_o,
      m_data_o  => m_w_out,
      m_fill_o  => open
    ); -- axis_fifo_async_w_inst : entity work.axis_fifo_async

  s_w_in(R_WDATA) <= s_wdata_i;
  s_w_in(R_WSTRB) <= s_wstrb_i;
  m_wdata_o       <= m_w_out(R_WDATA);
  m_wstrb_o       <= m_w_out(R_WSTRB);


  --------------------------------------------------------
  -- B stream
  --------------------------------------------------------

  axis_fifo_async_b_inst : entity work.axis_fifo_async
    generic map (
      G_DEPTH     => G_WR_DEPTH,
      G_DATA_SIZE => 2
    )
    port map (
      s_clk_i   => s_clk_i,
      s_rst_i   => s_rst_i,
      s_ready_o => m_bready_o,
      s_valid_i => m_bvalid_i,
      s_data_i  => m_bresp_i,
      s_fill_o  => open,
      m_clk_i   => m_clk_i,
      m_ready_i => s_bready_i,
      m_valid_o => s_bvalid_o,
      m_data_o  => s_bresp_o,
      m_fill_o  => open
    ); -- axis_fifo_async_b_inst : entity work.axis_fifo_async


  --------------------------------------------------------
  -- AR stream
  --------------------------------------------------------

  axis_fifo_async_ar_inst : entity work.axis_fifo_async
    generic map (
      G_DEPTH     => G_RD_DEPTH,
      G_DATA_SIZE => G_ADDR_SIZE
    )
    port map (
      s_clk_i   => s_clk_i,
      s_rst_i   => s_rst_i,
      s_ready_o => s_arready_o,
      s_valid_i => s_arvalid_i,
      s_data_i  => s_araddr_i,
      s_fill_o  => open,
      m_clk_i   => m_clk_i,
      m_ready_i => m_arready_i,
      m_valid_o => m_arvalid_o,
      m_data_o  => m_araddr_o,
      m_fill_o  => open
    ); -- axis_fifo_async_ar_inst : entity work.axis_fifo_async


  --------------------------------------------------------
  -- R stream
  --------------------------------------------------------

  axis_fifo_async_r_inst : entity work.axis_fifo_async
    generic map (
      G_DEPTH     => G_RD_DEPTH,
      G_DATA_SIZE => G_DATA_SIZE + 2
    )
    port map (
      s_clk_i   => s_clk_i,
      s_rst_i   => s_rst_i,
      s_ready_o => m_rready_o,
      s_valid_i => m_rvalid_i,
      s_data_i  => m_r_in,
      s_fill_o  => open,
      m_clk_i   => m_clk_i,
      m_ready_i => s_rready_i,
      m_valid_o => s_rvalid_o,
      m_data_o  => s_r_out,
      m_fill_o  => open
    ); -- axis_fifo_async_r_inst : entity work.axis_fifo_async

  m_r_in(R_RDATA) <= m_rdata_i;
  m_r_in(R_RRESP) <= m_rresp_i;
  s_rdata_o       <= s_r_out(R_RDATA);
  s_rresp_o       <= s_r_out(R_RRESP);

end architecture synthesis;

