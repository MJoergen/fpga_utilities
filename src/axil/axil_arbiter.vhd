-- ---------------------------------------------------------------------------------------
-- Description: Arbitrate between two different AXI Lite masters. If both Masters request
-- simultaneously, then they are granted access alternately.
--
-- This is similar to the 2-1 AXI crossbar, see:
-- https://www.xilinx.com/support/documents/ip_documentation/axi_interconnect/v2_1/pg059-axi-interconnect.pdf
--
-- The implementation is split into writing and reading, each of which is handled
-- separately and (almost) independently.
-- ---------------------------------------------------------------------------------------

library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std.all;

entity axil_arbiter is
  generic (
    G_ADDR_SIZE : natural;
    G_DATA_SIZE : natural
  );
  port (
    clk_i        : in    std_logic;
    rst_i        : in    std_logic;

    -- Input
    s0_awready_o : out   std_logic;
    s0_awvalid_i : in    std_logic;
    s0_awaddr_i  : in    std_logic_vector(G_ADDR_SIZE - 1 downto 0);
    s0_wready_o  : out   std_logic;
    s0_wvalid_i  : in    std_logic;
    s0_wdata_i   : in    std_logic_vector(G_DATA_SIZE - 1 downto 0);
    s0_wstrb_i   : in    std_logic_vector(G_DATA_SIZE / 8 - 1 downto 0);
    s0_bready_i  : in    std_logic;
    s0_bvalid_o  : out   std_logic;
    s0_bresp_o   : out   std_logic_vector(1 downto 0);
    s0_arready_o : out   std_logic;
    s0_arvalid_i : in    std_logic;
    s0_araddr_i  : in    std_logic_vector(G_ADDR_SIZE - 1 downto 0);
    s0_rready_i  : in    std_logic;
    s0_rvalid_o  : out   std_logic;
    s0_rdata_o   : out   std_logic_vector(G_DATA_SIZE - 1 downto 0);
    s0_rresp_o   : out   std_logic_vector(1 downto 0);

    s1_awready_o : out   std_logic;
    s1_awvalid_i : in    std_logic;
    s1_awaddr_i  : in    std_logic_vector(G_ADDR_SIZE - 1 downto 0);
    s1_wready_o  : out   std_logic;
    s1_wvalid_i  : in    std_logic;
    s1_wdata_i   : in    std_logic_vector(G_DATA_SIZE - 1 downto 0);
    s1_wstrb_i   : in    std_logic_vector(G_DATA_SIZE / 8 - 1 downto 0);
    s1_bready_i  : in    std_logic;
    s1_bvalid_o  : out   std_logic;
    s1_bresp_o   : out   std_logic_vector(1 downto 0);
    s1_arready_o : out   std_logic;
    s1_arvalid_i : in    std_logic;
    s1_araddr_i  : in    std_logic_vector(G_ADDR_SIZE - 1 downto 0);
    s1_rready_i  : in    std_logic;
    s1_rvalid_o  : out   std_logic;
    s1_rdata_o   : out   std_logic_vector(G_DATA_SIZE - 1 downto 0);
    s1_rresp_o   : out   std_logic_vector(1 downto 0);

    -- Output
    m_awready_i  : in    std_logic;
    m_awvalid_o  : out   std_logic;
    m_awaddr_o   : out   std_logic_vector(G_ADDR_SIZE - 1 downto 0);
    m_wready_i   : in    std_logic;
    m_wvalid_o   : out   std_logic;
    m_wdata_o    : out   std_logic_vector(G_DATA_SIZE - 1 downto 0);
    m_wstrb_o    : out   std_logic_vector(G_DATA_SIZE / 8 - 1 downto 0);
    m_bready_o   : out   std_logic;
    m_bvalid_i   : in    std_logic;
    m_bresp_i    : in    std_logic_vector(1 downto 0);
    m_arready_i  : in    std_logic;
    m_arvalid_o  : out   std_logic;
    m_araddr_o   : out   std_logic_vector(G_ADDR_SIZE - 1 downto 0);
    m_rready_o   : out   std_logic;
    m_rvalid_i   : in    std_logic;
    m_rdata_i    : in    std_logic_vector(G_DATA_SIZE - 1 downto 0);
    m_rresp_i    : in    std_logic_vector(1 downto 0)
  );
end entity axil_arbiter;

architecture synthesis of axil_arbiter is

begin

  axil_arbiter_write_inst : entity work.axil_arbiter_write
    generic map (
      G_ADDR_SIZE => G_ADDR_SIZE,
      G_DATA_SIZE => G_DATA_SIZE
    )
    port map (
      clk_i        => clk_i,
      rst_i        => rst_i,
      s0_awready_o => s0_awready_o,
      s0_awvalid_i => s0_awvalid_i,
      s0_awaddr_i  => s0_awaddr_i,
      s0_wready_o  => s0_wready_o,
      s0_wvalid_i  => s0_wvalid_i,
      s0_wdata_i   => s0_wdata_i,
      s0_wstrb_i   => s0_wstrb_i,
      s0_bready_i  => s0_bready_i,
      s0_bvalid_o  => s0_bvalid_o,
      s0_bresp_o   => s0_bresp_o,
      s1_awready_o => s1_awready_o,
      s1_awvalid_i => s1_awvalid_i,
      s1_awaddr_i  => s1_awaddr_i,
      s1_wready_o  => s1_wready_o,
      s1_wvalid_i  => s1_wvalid_i,
      s1_wdata_i   => s1_wdata_i,
      s1_wstrb_i   => s1_wstrb_i,
      s1_bready_i  => s1_bready_i,
      s1_bvalid_o  => s1_bvalid_o,
      s1_bresp_o   => s1_bresp_o,
      m_awready_i  => m_awready_i,
      m_awvalid_o  => m_awvalid_o,
      m_awaddr_o   => m_awaddr_o,
      m_wready_i   => m_wready_i,
      m_wvalid_o   => m_wvalid_o,
      m_wdata_o    => m_wdata_o,
      m_wstrb_o    => m_wstrb_o,
      m_bready_o   => m_bready_o,
      m_bvalid_i   => m_bvalid_i,
      m_bresp_i    => m_bresp_i
    ); -- axil_arbiter_write_inst : entity work.axil_arbiter_write

  axil_arbiter_read_inst : entity work.axil_arbiter_read
    generic map (
      G_ADDR_SIZE => G_ADDR_SIZE,
      G_DATA_SIZE => G_DATA_SIZE
    )
    port map (
      clk_i        => clk_i,
      rst_i        => rst_i,
      s0_arready_o => s0_arready_o,
      s0_arvalid_i => s0_arvalid_i,
      s0_araddr_i  => s0_araddr_i,
      s0_rready_i  => s0_rready_i,
      s0_rvalid_o  => s0_rvalid_o,
      s0_rdata_o   => s0_rdata_o,
      s0_rresp_o   => s0_rresp_o,
      s0_writing_i => s0_awvalid_i or s0_wvalid_i,
      s1_arready_o => s1_arready_o,
      s1_arvalid_i => s1_arvalid_i,
      s1_araddr_i  => s1_araddr_i,
      s1_rready_i  => s1_rready_i,
      s1_rvalid_o  => s1_rvalid_o,
      s1_rdata_o   => s1_rdata_o,
      s1_rresp_o   => s1_rresp_o,
      s1_writing_i => s1_awvalid_i or s1_wvalid_i,
      m_arready_i  => m_arready_i,
      m_arvalid_o  => m_arvalid_o,
      m_araddr_o   => m_araddr_o,
      m_rready_o   => m_rready_o,
      m_rvalid_i   => m_rvalid_i,
      m_rdata_i    => m_rdata_i,
      m_rresp_i    => m_rresp_i
    ); -- axil_arbiter_read_inst : entity work.axil_arbiter_read

end architecture synthesis;

