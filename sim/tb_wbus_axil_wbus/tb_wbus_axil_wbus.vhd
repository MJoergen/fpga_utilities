-- ---------------------------------------------------------------------------------------
-- Description: Simple testbench for the AXI-Lite to WBUS and WBUS to AXI-Lite converters
-- ---------------------------------------------------------------------------------------

library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std.all;

entity tb_wbus_axil_wbus is
  generic (
    G_DEBUG     : boolean;
    G_ADDR_BITS : natural;
    G_DATA_BITS : natural
  );
end entity tb_wbus_axil_wbus;

architecture tb of tb_wbus_axil_wbus is

  signal wbus_clk : std_logic := '1';
  signal wbus_rst : std_logic := '1';

  signal tb_wbus_cyc   : std_logic;
  signal tb_wbus_stall : std_logic;
  signal tb_wbus_stb   : std_logic;
  signal tb_wbus_addr  : std_logic_vector(G_ADDR_BITS - 1 downto 0);
  signal tb_wbus_we    : std_logic;
  signal tb_wbus_wrdat : std_logic_vector(G_DATA_BITS - 1 downto 0);
  signal tb_wbus_sel   : std_logic_vector(G_DATA_BITS / 8 - 1 downto 0);
  signal tb_wbus_ack   : std_logic;
  signal tb_wbus_rddat : std_logic_vector(G_DATA_BITS - 1 downto 0);

  signal mem_wbus_cyc   : std_logic;
  signal mem_wbus_stall : std_logic;
  signal mem_wbus_stb   : std_logic;
  signal mem_wbus_addr  : std_logic_vector(G_ADDR_BITS - 1 downto 0);
  signal mem_wbus_we    : std_logic;
  signal mem_wbus_wrdat : std_logic_vector(G_DATA_BITS - 1 downto 0);
  signal mem_wbus_sel   : std_logic_vector(G_DATA_BITS / 8 - 1 downto 0);
  signal mem_wbus_ack   : std_logic;
  signal mem_wbus_rddat : std_logic_vector(G_DATA_BITS - 1 downto 0);

  signal axil_awready : std_logic;
  signal axil_awvalid : std_logic;
  signal axil_awaddr  : std_logic_vector(G_ADDR_BITS - 1 downto 0);
  signal axil_wready  : std_logic;
  signal axil_wvalid  : std_logic;
  signal axil_wdata   : std_logic_vector(G_DATA_BITS - 1 downto 0);
  signal axil_wstrb   : std_logic_vector(G_DATA_BITS / 8 - 1 downto 0);
  signal axil_bready  : std_logic;
  signal axil_bvalid  : std_logic;
  signal axil_bresp   : std_logic_vector(1 downto 0);
  signal axil_arready : std_logic;
  signal axil_arvalid : std_logic;
  signal axil_araddr  : std_logic_vector(G_ADDR_BITS - 1 downto 0);
  signal axil_rready  : std_logic;
  signal axil_rvalid  : std_logic;
  signal axil_rdata   : std_logic_vector(G_DATA_BITS - 1 downto 0);
  signal axil_rresp   : std_logic_vector(1 downto 0);

begin

  -------------------------------------
  -- Clock and reset
  -------------------------------------

  wbus_clk <= not wbus_clk after 5 ns;
  wbus_rst <= '1', '0' after 100 ns;


  -------------------------------------
  -- Instantiate DUTs
  -------------------------------------

  wbus_to_axil_inst : entity work.wbus_to_axil
    generic map (
      G_ADDR_BITS => G_ADDR_BITS,
      G_DATA_BITS => G_DATA_BITS
    )
    port map (
      clk_i       => wbus_clk,
      rst_i       => wbus_rst,
      s_cyc_i     => tb_wbus_cyc,
      s_stall_o   => tb_wbus_stall,
      s_stb_i     => tb_wbus_stb,
      s_addr_i    => tb_wbus_addr,
      s_we_i      => tb_wbus_we,
      s_wrdat_i   => tb_wbus_wrdat,
      s_sel_i     => tb_wbus_sel,
      s_ack_o     => tb_wbus_ack,
      s_rddat_o   => tb_wbus_rddat,
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
    ); -- wbus_to_axil_inst : entity work.wbus_to_axil

  axil_to_wbus_inst : entity work.axil_to_wbus
    generic map (
      G_TIMEOUT   => 100,
      G_ADDR_BITS => G_ADDR_BITS,
      G_DATA_BITS => G_DATA_BITS
    )
    port map (
      clk_i       => wbus_clk,
      rst_i       => wbus_rst,
      s_awready_o => axil_awready,
      s_awvalid_i => axil_awvalid,
      s_awaddr_i  => axil_awaddr,
      s_wready_o  => axil_wready,
      s_wvalid_i  => axil_wvalid,
      s_wdata_i   => axil_wdata,
      s_wstrb_i   => axil_wstrb,
      s_bready_i  => axil_bready,
      s_bvalid_o  => axil_bvalid,
      s_bresp_o   => axil_bresp,
      s_arready_o => axil_arready,
      s_arvalid_i => axil_arvalid,
      s_araddr_i  => axil_araddr,
      s_rready_i  => axil_rready,
      s_rvalid_o  => axil_rvalid,
      s_rdata_o   => axil_rdata,
      s_rresp_o   => axil_rresp,
      m_cyc_o     => mem_wbus_cyc,
      m_stall_i   => mem_wbus_stall,
      m_stb_o     => mem_wbus_stb,
      m_addr_o    => mem_wbus_addr,
      m_we_o      => mem_wbus_we,
      m_wrdat_o   => mem_wbus_wrdat,
      m_sel_o     => mem_wbus_sel,
      m_ack_i     => mem_wbus_ack,
      m_rddat_i   => mem_wbus_rddat
    ); -- axil_to_wbus_inst : entity work.axil_to_wbus


  -------------------------------------
  -- Generate stimuli
  -------------------------------------

  wbus_master_sim_inst : entity work.wbus_master_sim
    generic map (
      G_DEBUG     => G_DEBUG,
      G_OFFSET    => 1234,
      G_ADDR_BITS => G_ADDR_BITS,
      G_DATA_BITS => G_DATA_BITS
    )
    port map (
      clk_i     => wbus_clk,
      rst_i     => wbus_rst,
      m_cyc_o   => tb_wbus_cyc,
      m_stall_i => tb_wbus_stall,
      m_stb_o   => tb_wbus_stb,
      m_addr_o  => tb_wbus_addr,
      m_we_o    => tb_wbus_we,
      m_wrdat_o => tb_wbus_wrdat,
      m_sel_o   => tb_wbus_sel,
      m_ack_i   => tb_wbus_ack,
      m_rddat_i => tb_wbus_rddat
    ); -- wbus_master_sim_inst : entity work.wbus_master_sim

  wbus_slave_sim_inst : entity work.wbus_slave_sim
    generic map (
      G_DEBUG     => G_DEBUG,
      G_ADDR_BITS => G_ADDR_BITS,
      G_DATA_BITS => G_DATA_BITS
    )
    port map (
      clk_i     => wbus_clk,
      rst_i     => wbus_rst,
      s_cyc_i   => mem_wbus_cyc,
      s_stall_o => mem_wbus_stall,
      s_stb_i   => mem_wbus_stb,
      s_addr_i  => mem_wbus_addr,
      s_we_i    => mem_wbus_we,
      s_wrdat_i => mem_wbus_wrdat,
      s_sel_i   => mem_wbus_sel,
      s_ack_o   => mem_wbus_ack,
      s_rddat_o => mem_wbus_rddat
    ); -- wbus_slave_sim_inst : entity work.wbus_slave_sim

end architecture tb;

