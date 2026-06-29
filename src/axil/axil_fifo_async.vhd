-- ---------------------------------------------------------------------------------------
-- Description: This provides a Clock Domain Crossing (i.e. an asynchronous FIFO) for a
-- AXI Lite interface.
--
-- Important limitation:
-- This module does NOT preserve relative ordering between AXI-Lite channels.
-- AW, W, AR, B, and R channels are transported independently.
-- Downstream slaves must tolerate arbitrary inter-channel skew.
--
-- SPDX-License-Identifier: MIT
-- ---------------------------------------------------------------------------------------

library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std.all;

entity axil_fifo_async is
  generic (
    G_ADDR_BITS : positive;
    G_DATA_BITS : positive;
    G_WR_DEPTH  : positive; -- Channels AW, W, and B
    G_RD_DEPTH  : positive; -- Channels AR and R
    G_RAM_STYLE : string := "auto"
  );
  port (
    -- Connect to AXI Lite Master
    s_clk_i     : in    std_logic;
    s_rst_i     : in    std_logic;
    s_awready_o : out   std_logic;
    s_awvalid_i : in    std_logic;
    s_awaddr_i  : in    std_logic_vector(G_ADDR_BITS - 1 downto 0);
    s_wready_o  : out   std_logic;
    s_wvalid_i  : in    std_logic;
    s_wdata_i   : in    std_logic_vector(G_DATA_BITS - 1 downto 0);
    s_wstrb_i   : in    std_logic_vector(G_DATA_BITS / 8 - 1 downto 0);
    s_bready_i  : in    std_logic;
    s_bvalid_o  : out   std_logic;
    s_bresp_o   : out   std_logic_vector(1 downto 0);
    s_arready_o : out   std_logic;
    s_arvalid_i : in    std_logic;
    s_araddr_i  : in    std_logic_vector(G_ADDR_BITS - 1 downto 0);
    s_rready_i  : in    std_logic;
    s_rvalid_o  : out   std_logic;
    s_rdata_o   : out   std_logic_vector(G_DATA_BITS - 1 downto 0);
    s_rresp_o   : out   std_logic_vector(1 downto 0);

    -- Connect to AXI Lite Slave
    m_clk_i     : in    std_logic;
    m_rst_i     : in    std_logic;
    m_awready_i : in    std_logic;
    m_awvalid_o : out   std_logic;
    m_awaddr_o  : out   std_logic_vector(G_ADDR_BITS - 1 downto 0);
    m_wready_i  : in    std_logic;
    m_wvalid_o  : out   std_logic;
    m_wdata_o   : out   std_logic_vector(G_DATA_BITS - 1 downto 0);
    m_wstrb_o   : out   std_logic_vector(G_DATA_BITS / 8 - 1 downto 0);
    m_bready_o  : out   std_logic;
    m_bvalid_i  : in    std_logic;
    m_bresp_i   : in    std_logic_vector(1 downto 0);
    m_arready_i : in    std_logic;
    m_arvalid_o : out   std_logic;
    m_araddr_o  : out   std_logic_vector(G_ADDR_BITS - 1 downto 0);
    m_rready_o  : out   std_logic;
    m_rvalid_i  : in    std_logic;
    m_rdata_i   : in    std_logic_vector(G_DATA_BITS - 1 downto 0);
    m_rresp_i   : in    std_logic_vector(1 downto 0)
  );
end entity axil_fifo_async;

architecture rtl of axil_fifo_async is

  subtype R_WDATA is natural range G_DATA_BITS - 1 downto 0;

  subtype R_WSTRB is natural range G_DATA_BITS + G_DATA_BITS / 8 - 1 downto G_DATA_BITS;

  signal  s_w_in  : std_logic_vector(G_DATA_BITS + G_DATA_BITS / 8 - 1 downto 0);
  signal  m_w_out : std_logic_vector(G_DATA_BITS + G_DATA_BITS / 8 - 1 downto 0);

  subtype R_RDATA is natural range G_DATA_BITS - 1 downto 0;

  subtype R_RRESP is natural range G_DATA_BITS + 1 downto G_DATA_BITS;

  signal  m_r_in  : std_logic_vector(G_DATA_BITS + 1 downto 0);
  signal  s_r_out : std_logic_vector(G_DATA_BITS + 1 downto 0);

  pure function log2 (
    arg : positive
  ) return natural is
    variable res_v : natural := 0;
  begin
    while 2 ** res_v < arg loop
      res_v := res_v + 1;
    end loop;
    return res_v;
  end function log2;

begin

  assert G_DATA_BITS mod 8 = 0
    report "G_DATA_BITS must be a multiple of 8"
    severity failure;

  --------------------------------------------------------
  -- AW stream
  --------------------------------------------------------

  axis_fifo_async_aw_inst : entity work.axis_fifo_async
    generic map (
      G_ADDR_BITS => log2(G_WR_DEPTH),
      G_DATA_BITS => G_ADDR_BITS,
      G_RAM_STYLE => G_RAM_STYLE
    )
    port map (
      async_rst_i => s_rst_i,
      s_clk_i     => s_clk_i,
      s_ready_o   => s_awready_o,
      s_valid_i   => s_awvalid_i,
      s_data_i    => s_awaddr_i,
      s_fill_o    => open,
      m_clk_i     => m_clk_i,
      m_ready_i   => m_awready_i,
      m_valid_o   => m_awvalid_o,
      m_data_o    => m_awaddr_o,
      m_fill_o    => open
    ); -- axis_fifo_async_aw_inst : entity work.axis_fifo_async


  --------------------------------------------------------
  -- W stream
  --------------------------------------------------------

  axis_fifo_async_w_inst : entity work.axis_fifo_async
    generic map (
      G_ADDR_BITS => log2(G_WR_DEPTH),
      G_DATA_BITS => G_DATA_BITS + G_DATA_BITS / 8,
      G_RAM_STYLE => G_RAM_STYLE
    )
    port map (
      async_rst_i => s_rst_i,
      s_clk_i     => s_clk_i,
      s_ready_o   => s_wready_o,
      s_valid_i   => s_wvalid_i,
      s_data_i    => s_w_in,
      s_fill_o    => open,
      m_clk_i     => m_clk_i,
      m_ready_i   => m_wready_i,
      m_valid_o   => m_wvalid_o,
      m_data_o    => m_w_out,
      m_fill_o    => open
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
      G_ADDR_BITS => log2(G_WR_DEPTH),
      G_DATA_BITS => 2,
      G_RAM_STYLE => G_RAM_STYLE
    )
    port map (
      async_rst_i => m_rst_i,
      s_clk_i     => m_clk_i,
      s_ready_o   => m_bready_o,
      s_valid_i   => m_bvalid_i,
      s_data_i    => m_bresp_i,
      s_fill_o    => open,
      m_clk_i     => s_clk_i,
      m_ready_i   => s_bready_i,
      m_valid_o   => s_bvalid_o,
      m_data_o    => s_bresp_o,
      m_fill_o    => open
    ); -- axis_fifo_async_b_inst : entity work.axis_fifo_async


  --------------------------------------------------------
  -- AR stream
  --------------------------------------------------------

  axis_fifo_async_ar_inst : entity work.axis_fifo_async
    generic map (
      G_ADDR_BITS => log2(G_RD_DEPTH),
      G_DATA_BITS => G_ADDR_BITS,
      G_RAM_STYLE => G_RAM_STYLE
    )
    port map (
      async_rst_i => s_rst_i,
      s_clk_i     => s_clk_i,
      s_ready_o   => s_arready_o,
      s_valid_i   => s_arvalid_i,
      s_data_i    => s_araddr_i,
      s_fill_o    => open,
      m_clk_i     => m_clk_i,
      m_ready_i   => m_arready_i,
      m_valid_o   => m_arvalid_o,
      m_data_o    => m_araddr_o,
      m_fill_o    => open
    ); -- axis_fifo_async_ar_inst : entity work.axis_fifo_async


  --------------------------------------------------------
  -- R stream
  --------------------------------------------------------

  axis_fifo_async_r_inst : entity work.axis_fifo_async
    generic map (
      G_ADDR_BITS => log2(G_RD_DEPTH),
      G_DATA_BITS => G_DATA_BITS + 2
    )
    port map (
      async_rst_i => m_rst_i,
      s_clk_i     => m_clk_i,
      s_ready_o   => m_rready_o,
      s_valid_i   => m_rvalid_i,
      s_data_i    => m_r_in,
      s_fill_o    => open,
      m_clk_i     => s_clk_i,
      m_ready_i   => s_rready_i,
      m_valid_o   => s_rvalid_o,
      m_data_o    => s_r_out,
      m_fill_o    => open
    ); -- axis_fifo_async_r_inst : entity work.axis_fifo_async

  m_r_in(R_RDATA) <= m_rdata_i;
  m_r_in(R_RRESP) <= m_rresp_i;
  s_rdata_o       <= s_r_out(R_RDATA);
  s_rresp_o       <= s_r_out(R_RRESP);

end architecture rtl;

