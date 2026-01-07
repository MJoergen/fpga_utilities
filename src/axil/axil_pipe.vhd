-- ----------------------------------------------------------------------------
-- Author     : Michael Jørgensen
-- Platform   : AMD Artix 7
-- ----------------------------------------------------------------------------
-- Description: Arbitrate between two different AXI Lite masters
-- If both Masters request simultaneously, then they are granted access alternately.
--
-- This is similar to the 2-1 AXI crossbar, see:
-- https://www.xilinx.com/support/documents/ip_documentation/axi_interconnect/v2_1/pg059-axi-interconnect.pdf
-- ----------------------------------------------------------------------------

library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std.all;

entity axil_pipe is
  generic (
    G_ADDR_SIZE : natural;
    G_DATA_SIZE : natural
  );
  port (
    clk_i       : in    std_logic;
    rst_i       : in    std_logic;

    -- Input
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

    -- Output
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
end entity axil_pipe;

architecture synthesis of axil_pipe is

  subtype R_WDATA is natural range G_DATA_SIZE - 1 downto 0;
  subtype R_WSTRB is natural range G_DATA_SIZE + G_DATA_SIZE / 8 - 1 downto G_DATA_SIZE;

  signal  s_w_in  : std_logic_vector(G_DATA_SIZE + G_DATA_SIZE / 8 - 1 downto 0);
  signal  m_w_out : std_logic_vector(G_DATA_SIZE + G_DATA_SIZE / 8 - 1 downto 0);

  subtype R_RDATA is natural range G_DATA_SIZE - 1 downto 0;
  subtype R_RRESP is natural range G_DATA_SIZE + 1 downto G_DATA_SIZE;

  signal  m_r_in  : std_logic_vector(G_DATA_SIZE + 1 downto 0);
  signal  s_r_out : std_logic_vector(G_DATA_SIZE + 1 downto 0);

begin

  axis_pipe_aw_inst : entity work.axis_pipe
    generic map (
      G_DATA_SIZE => G_ADDR_SIZE
    )
    port map (
      clk_i     => clk_i,
      rst_i     => rst_i,
      s_ready_o => s_awready_o,
      s_valid_i => s_awvalid_i,
      s_data_i  => s_awaddr_i,
      s_fill_o  => open,
      m_ready_i => m_awready_i,
      m_valid_o => m_awvalid_o,
      m_data_o  => m_awaddr_o
    ); -- axis_pipe_aw_inst : entity work.axis_pipe

  axis_pipe_ar_inst : entity work.axis_pipe
    generic map (
      G_DATA_SIZE => G_ADDR_SIZE
    )
    port map (
      clk_i     => clk_i,
      rst_i     => rst_i,
      s_ready_o => s_arready_o,
      s_valid_i => s_arvalid_i,
      s_data_i  => s_araddr_i,
      s_fill_o  => open,
      m_ready_i => m_arready_i,
      m_valid_o => m_arvalid_o,
      m_data_o  => m_araddr_o
    ); -- axis_pipe_ar_inst : entity work.axis_pipe

  axis_pipe_w_inst : entity work.axis_pipe
    generic map (
      G_DATA_SIZE => G_DATA_SIZE + G_DATA_SIZE / 8
    )
    port map (
      clk_i     => clk_i,
      rst_i     => rst_i,
      s_ready_o => s_wready_o,
      s_valid_i => s_wvalid_i,
      s_data_i  => s_w_in,
      s_fill_o  => open,
      m_ready_i => m_wready_i,
      m_valid_o => m_wvalid_o,
      m_data_o  => m_w_out
    ); -- axis_pipe_w_inst : entity work.axis_pipe

  s_w_in(R_WDATA) <= s_wdata_i;
  s_w_in(R_WSTRB) <= s_wstrb_i;
  m_wdata_o       <= m_w_out(R_WDATA);
  m_wstrb_o       <= m_w_out(R_WSTRB);


  axis_pipe_b_inst : entity work.axis_pipe
    generic map (
      G_DATA_SIZE => 2
    )
    port map (
      clk_i     => clk_i,
      rst_i     => rst_i,
      s_ready_o => m_bready_o,
      s_valid_i => m_bvalid_i,
      s_data_i  => m_bresp_i,
      s_fill_o  => open,
      m_ready_i => s_bready_i,
      m_valid_o => s_bvalid_o,
      m_data_o  => s_bresp_o
    ); -- axis_pipe_b_inst : entity work.axis_pipe

  axis_pipe_r_inst : entity work.axis_pipe
    generic map (
      G_DATA_SIZE => G_DATA_SIZE + 2
    )
    port map (
      clk_i     => clk_i,
      rst_i     => rst_i,
      s_ready_o => m_rready_o,
      s_valid_i => m_rvalid_i,
      s_data_i  => m_r_in,
      s_fill_o  => open,
      m_ready_i => s_rready_i,
      m_valid_o => s_rvalid_o,
      m_data_o  => s_r_out
    ); -- axis_pipe_r_inst : entity work.axis_pipe

  m_r_in(R_RDATA) <= m_rdata_i;
  m_r_in(R_RRESP) <= m_rresp_i;
  s_rdata_o       <= s_r_out(R_RDATA);
  s_rresp_o       <= s_r_out(R_RRESP);

end architecture synthesis;

