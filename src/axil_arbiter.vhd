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

entity axil_arbiter is
  generic (
    G_ID_SIZE   : natural;
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
    s0_awid_i    : in    std_logic_vector(G_ID_SIZE - 1 downto 0);
    s0_wready_o  : out   std_logic;
    s0_wvalid_i  : in    std_logic;
    s0_wdata_i   : in    std_logic_vector(G_DATA_SIZE - 1 downto 0);
    s0_wstrb_i   : in    std_logic_vector(G_DATA_SIZE / 8 - 1 downto 0);
    s0_bready_i  : in    std_logic;
    s0_bvalid_o  : out   std_logic;
    s0_bid_o     : out   std_logic_vector(G_ID_SIZE - 1 downto 0);
    s0_arready_o : out   std_logic;
    s0_arvalid_i : in    std_logic;
    s0_araddr_i  : in    std_logic_vector(G_ADDR_SIZE - 1 downto 0);
    s0_arid_i    : in    std_logic_vector(G_ID_SIZE - 1 downto 0);
    s0_rready_i  : in    std_logic;
    s0_rvalid_o  : out   std_logic;
    s0_rdata_o   : out   std_logic_vector(G_DATA_SIZE - 1 downto 0);
    s0_rid_o     : out   std_logic_vector(G_ID_SIZE - 1 downto 0);

    s1_awready_o : out   std_logic;
    s1_awvalid_i : in    std_logic;
    s1_awaddr_i  : in    std_logic_vector(G_ADDR_SIZE - 1 downto 0);
    s1_awid_i    : in    std_logic_vector(G_ID_SIZE - 1 downto 0);
    s1_wready_o  : out   std_logic;
    s1_wvalid_i  : in    std_logic;
    s1_wdata_i   : in    std_logic_vector(G_DATA_SIZE - 1 downto 0);
    s1_wstrb_i   : in    std_logic_vector(G_DATA_SIZE / 8 - 1 downto 0);
    s1_bready_i  : in    std_logic;
    s1_bvalid_o  : out   std_logic;
    s1_bid_o     : out   std_logic_vector(G_ID_SIZE - 1 downto 0);
    s1_arready_o : out   std_logic;
    s1_arvalid_i : in    std_logic;
    s1_araddr_i  : in    std_logic_vector(G_ADDR_SIZE - 1 downto 0);
    s1_arid_i    : in    std_logic_vector(G_ID_SIZE - 1 downto 0);
    s1_rready_i  : in    std_logic;
    s1_rvalid_o  : out   std_logic;
    s1_rdata_o   : out   std_logic_vector(G_DATA_SIZE - 1 downto 0);
    s1_rid_o     : out   std_logic_vector(G_ID_SIZE - 1 downto 0);

    -- Output
    m_awready_i  : in    std_logic;
    m_awvalid_o  : out   std_logic;
    m_awaddr_o   : out   std_logic_vector(G_ADDR_SIZE - 1 downto 0);
    m_awid_o     : out   std_logic_vector(G_ID_SIZE downto 0);
    m_wready_i   : in    std_logic;
    m_wvalid_o   : out   std_logic;
    m_wdata_o    : out   std_logic_vector(G_DATA_SIZE - 1 downto 0);
    m_wstrb_o    : out   std_logic_vector(G_DATA_SIZE / 8 - 1 downto 0);
    m_bready_o   : out   std_logic;
    m_bvalid_i   : in    std_logic;
    m_bid_i      : in    std_logic_vector(G_ID_SIZE downto 0);
    m_arready_i  : in    std_logic;
    m_arvalid_o  : out   std_logic;
    m_araddr_o   : out   std_logic_vector(G_ADDR_SIZE - 1 downto 0);
    m_arid_o     : out   std_logic_vector(G_ID_SIZE downto 0);
    m_rready_o   : out   std_logic;
    m_rvalid_i   : in    std_logic;
    m_rdata_i    : in    std_logic_vector(G_DATA_SIZE - 1 downto 0);
    m_rid_i      : in    std_logic_vector(G_ID_SIZE downto 0)
  );
end entity axil_arbiter;

architecture synthesis of axil_arbiter is

  signal s0_aw_data : std_logic_vector(G_ADDR_SIZE + G_ID_SIZE downto 0);
  signal s1_aw_data : std_logic_vector(G_ADDR_SIZE + G_ID_SIZE downto 0);
  signal m_aw_data  : std_logic_vector(G_ADDR_SIZE + G_ID_SIZE downto 0);

  signal s0_ar_data : std_logic_vector(G_ADDR_SIZE + G_ID_SIZE downto 0);
  signal s1_ar_data : std_logic_vector(G_ADDR_SIZE + G_ID_SIZE downto 0);
  signal m_ar_data  : std_logic_vector(G_ADDR_SIZE + G_ID_SIZE downto 0);

  signal s0_w_data : std_logic_vector(G_DATA_SIZE + G_DATA_SIZE / 8 downto 0);
  signal s1_w_data : std_logic_vector(G_DATA_SIZE + G_DATA_SIZE / 8 downto 0);
  signal m_w_data  : std_logic_vector(G_DATA_SIZE + G_DATA_SIZE / 8 downto 0);

  signal s0_r_data : std_logic_vector(G_DATA_SIZE + G_ID_SIZE - 1 downto 0);
  signal s1_r_data : std_logic_vector(G_DATA_SIZE + G_ID_SIZE - 1 downto 0);
  signal m_r_data  : std_logic_vector(G_DATA_SIZE + G_ID_SIZE - 1 downto 0);

  -- This is only used for debugging
  signal m_wid : std_logic;

begin

  -- Arbitrate the AW and W streams from the two inputs
  axis_arbiter_pair_inst : entity work.axis_arbiter_pair
    generic map (
      G_A_DATA_SIZE => G_ADDR_SIZE + G_ID_SIZE + 1,
      G_B_DATA_SIZE => G_DATA_SIZE + G_DATA_SIZE / 8 + 1
    )
    port map (
      clk_i        => clk_i,
      rst_i        => rst_i,
      s0_a_ready_o => s0_awready_o,
      s0_a_valid_i => s0_awvalid_i,
      s0_a_data_i  => s0_aw_data,
      s1_a_ready_o => s1_awready_o,
      s1_a_valid_i => s1_awvalid_i,
      s1_a_data_i  => s1_aw_data,
      s0_b_ready_o => s0_wready_o,
      s0_b_valid_i => s0_wvalid_i,
      s0_b_data_i  => s0_w_data,
      s1_b_ready_o => s1_wready_o,
      s1_b_valid_i => s1_wvalid_i,
      s1_b_data_i  => s1_w_data,
      m_a_ready_i  => m_awready_i,
      m_a_valid_o  => m_awvalid_o,
      m_a_data_o   => m_aw_data,
      m_b_ready_i  => m_wready_i,
      m_b_valid_o  => m_wvalid_o,
      m_b_data_o   => m_w_data
    ); -- axis_arbiter_pair_inst : entity work.axis_arbiter_pair

  s0_aw_data                    <= '0' & s0_awid_i & s0_awaddr_i;
  s1_aw_data                    <= '1' & s1_awid_i & s1_awaddr_i;
  (m_awid_o , m_awaddr_o)       <= m_aw_data;

  s0_w_data                     <= '0' & s0_wstrb_i & s0_wdata_i;
  s1_w_data                     <= '1' & s1_wstrb_i & s1_wdata_i;
  (m_wid, m_wstrb_o, m_wdata_o) <= m_w_data;


  -- Arbitrate the AR streams from the two inputs
  axis_arbiter_ar_inst : entity work.axis_arbiter
    generic map (
      G_DATA_SIZE => G_ADDR_SIZE + G_ID_SIZE + 1
    )
    port map (
      clk_i      => clk_i,
      rst_i      => rst_i,
      s0_ready_o => s0_arready_o,
      s0_valid_i => s0_arvalid_i,
      s0_data_i  => s0_ar_data,
      s1_ready_o => s1_arready_o,
      s1_valid_i => s1_arvalid_i,
      s1_data_i  => s1_ar_data,
      m_ready_i  => m_arready_i,
      m_valid_o  => m_arvalid_o,
      m_data_o   => m_ar_data
    ); -- axi_arbiter_ar_inst : entity work.axi_arbiter

  s0_ar_data              <= '0' & s0_arid_i & s0_araddr_i;
  s1_ar_data              <= '1' & s1_arid_i & s1_araddr_i;
  (m_arid_o , m_araddr_o) <= m_ar_data;


  axis_distributor_b_inst : entity work.axis_distributor
    generic map (
      G_DATA_SIZE => G_ID_SIZE
    )
    port map (
      clk_i      => clk_i,
      rst_i      => rst_i,
      s_ready_o  => m_bready_o,
      s_valid_i  => m_bvalid_i,
      s_data_i   => m_bid_i(G_ID_SIZE - 1 downto 0),
      s_dst_i    => m_bid_i(G_ID_SIZE),
      m0_ready_i => s0_bready_i,
      m0_valid_o => s0_bvalid_o,
      m0_data_o  => s0_bid_o,
      m1_ready_i => s1_bready_i,
      m1_valid_o => s1_bvalid_o,
      m1_data_o  => s1_bid_o
    ); -- axis_distributor_b_inst : entity work.axis_distributor

  axis_distributor_r_inst : entity work.axis_distributor
    generic map (
      G_DATA_SIZE => G_DATA_SIZE + G_ID_SIZE
    )
    port map (
      clk_i      => clk_i,
      rst_i      => rst_i,
      s_ready_o  => m_rready_o,
      s_valid_i  => m_rvalid_i,
      s_data_i   => m_r_data,
      s_dst_i    => m_rid_i(G_ID_SIZE),
      m0_ready_i => s0_rready_i,
      m0_valid_o => s0_rvalid_o,
      m0_data_o  => s0_r_data,
      m1_ready_i => s1_rready_i,
      m1_valid_o => s1_rvalid_o,
      m1_data_o  => s1_r_data
    ); -- axis_distributor_b_inst : entity work.axis_distributor

  m_r_data                <= m_rid_i(G_ID_SIZE - 1 downto 0) & m_rdata_i;
  (s0_rid_o , s0_rdata_o) <= s0_r_data;
  (s1_rid_o , s1_rdata_o) <= s1_r_data;

end architecture synthesis;

