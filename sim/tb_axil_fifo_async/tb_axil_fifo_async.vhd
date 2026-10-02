-- ---------------------------------------------------------------------------------------
-- Description: Verify axil_fifo_async
--
-- An AXI-Lite master on one clock writes to, and reads back from, an AXI-Lite slave on
-- another clock, through the DUT. The master uses random WSTRB values, random BREADY
-- and RREADY, and the slave side has random pauses on all channels.
--
-- SPDX-License-Identifier: MIT
-- ---------------------------------------------------------------------------------------

library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std.all;

entity tb_axil_fifo_async is
  generic (
    G_DEBUG      : boolean;
    G_RATIO      : natural;
    G_PAUSE_SIZE : natural;
    G_RANDOM     : boolean;
    G_FAST       : boolean;
    G_WR_DEPTH   : positive;
    G_RD_DEPTH   : positive;
    G_ADDR_BITS  : natural;
    G_DATA_BITS  : natural
  );
end entity tb_axil_fifo_async;

architecture tb of tb_axil_fifo_async is

  constant C_S_PERIOD : time      := 5 ns;
  constant C_M_PERIOD : time      := (C_S_PERIOD * G_RATIO) / 100;

  signal   async_rst : std_logic := '1';

  signal   s_clk : std_logic     := '1';
  signal   s_rst : std_logic     := '1';
  signal   m_clk : std_logic     := '1';
  signal   m_rst : std_logic     := '1';

  -- Master <-> DUT (s_clk)
  signal   s_awready : std_logic;
  signal   s_awvalid : std_logic;
  signal   s_awaddr  : std_logic_vector(G_ADDR_BITS - 1 downto 0);
  signal   s_wready  : std_logic;
  signal   s_wvalid  : std_logic;
  signal   s_wdata   : std_logic_vector(G_DATA_BITS - 1 downto 0);
  signal   s_wstrb   : std_logic_vector(G_DATA_BITS / 8 - 1 downto 0);
  signal   s_bready  : std_logic;
  signal   s_bvalid  : std_logic;
  signal   s_bresp   : std_logic_vector(1 downto 0);
  signal   s_arready : std_logic;
  signal   s_arvalid : std_logic;
  signal   s_araddr  : std_logic_vector(G_ADDR_BITS - 1 downto 0);
  signal   s_rready  : std_logic;
  signal   s_rvalid  : std_logic;
  signal   s_rdata   : std_logic_vector(G_DATA_BITS - 1 downto 0);
  signal   s_rresp   : std_logic_vector(1 downto 0);

  -- DUT <-> pause (m_clk)
  signal   m_awready : std_logic;
  signal   m_awvalid : std_logic;
  signal   m_awaddr  : std_logic_vector(G_ADDR_BITS - 1 downto 0);
  signal   m_wready  : std_logic;
  signal   m_wvalid  : std_logic;
  signal   m_wdata   : std_logic_vector(G_DATA_BITS - 1 downto 0);
  signal   m_wstrb   : std_logic_vector(G_DATA_BITS / 8 - 1 downto 0);
  signal   m_bready  : std_logic;
  signal   m_bvalid  : std_logic;
  signal   m_bresp   : std_logic_vector(1 downto 0);
  signal   m_arready : std_logic;
  signal   m_arvalid : std_logic;
  signal   m_araddr  : std_logic_vector(G_ADDR_BITS - 1 downto 0);
  signal   m_rready  : std_logic;
  signal   m_rvalid  : std_logic;
  signal   m_rdata   : std_logic_vector(G_DATA_BITS - 1 downto 0);
  signal   m_rresp   : std_logic_vector(1 downto 0);

  -- Pause <-> slave (m_clk)
  signal   p_awready : std_logic;
  signal   p_awvalid : std_logic;
  signal   p_awaddr  : std_logic_vector(G_ADDR_BITS - 1 downto 0);
  signal   p_wready  : std_logic;
  signal   p_wvalid  : std_logic;
  signal   p_wdata   : std_logic_vector(G_DATA_BITS - 1 downto 0);
  signal   p_wstrb   : std_logic_vector(G_DATA_BITS / 8 - 1 downto 0);
  signal   p_bready  : std_logic;
  signal   p_bvalid  : std_logic;
  signal   p_bresp   : std_logic_vector(1 downto 0);
  signal   p_arready : std_logic;
  signal   p_arvalid : std_logic;
  signal   p_araddr  : std_logic_vector(G_ADDR_BITS - 1 downto 0);
  signal   p_rready  : std_logic;
  signal   p_rvalid  : std_logic;
  signal   p_rdata   : std_logic_vector(G_DATA_BITS - 1 downto 0);
  signal   p_rresp   : std_logic_vector(1 downto 0);

begin

  ----------------------------------------------
  -- Clock and Reset
  ----------------------------------------------

  s_clk <= not s_clk after C_S_PERIOD;
  m_clk <= not m_clk after C_M_PERIOD;

  async_rst <= '1', '0' after 120 ns;

  s_rst <= async_rst when rising_edge(s_clk);
  m_rst <= async_rst when rising_edge(m_clk);


  ----------------------------------------------
  -- Instantiate DUT
  ----------------------------------------------

  axil_fifo_async_inst : entity work.axil_fifo_async
    generic map (
      G_ADDR_BITS => G_ADDR_BITS,
      G_DATA_BITS => G_DATA_BITS,
      G_WR_DEPTH  => G_WR_DEPTH,
      G_RD_DEPTH  => G_RD_DEPTH
    )
    port map (
      s_clk_i     => s_clk,
      s_rst_i     => s_rst,
      s_awready_o => s_awready,
      s_awvalid_i => s_awvalid,
      s_awaddr_i  => s_awaddr,
      s_wready_o  => s_wready,
      s_wvalid_i  => s_wvalid,
      s_wdata_i   => s_wdata,
      s_wstrb_i   => s_wstrb,
      s_bready_i  => s_bready,
      s_bvalid_o  => s_bvalid,
      s_bresp_o   => s_bresp,
      s_arready_o => s_arready,
      s_arvalid_i => s_arvalid,
      s_araddr_i  => s_araddr,
      s_rready_i  => s_rready,
      s_rvalid_o  => s_rvalid,
      s_rdata_o   => s_rdata,
      s_rresp_o   => s_rresp,
      m_clk_i     => m_clk,
      m_rst_i     => m_rst,
      m_awready_i => m_awready,
      m_awvalid_o => m_awvalid,
      m_awaddr_o  => m_awaddr,
      m_wready_i  => m_wready,
      m_wvalid_o  => m_wvalid,
      m_wdata_o   => m_wdata,
      m_wstrb_o   => m_wstrb,
      m_bready_o  => m_bready,
      m_bvalid_i  => m_bvalid,
      m_bresp_i   => m_bresp,
      m_arready_i => m_arready,
      m_arvalid_o => m_arvalid,
      m_araddr_o  => m_araddr,
      m_rready_o  => m_rready,
      m_rvalid_i  => m_rvalid,
      m_rdata_i   => m_rdata,
      m_rresp_i   => m_rresp
    ); -- axil_fifo_async_inst : entity work.axil_fifo_async


  ----------------------------------------------
  -- Generate stimuli and verify response
  ----------------------------------------------

  axil_master_sim_inst : entity work.axil_master_sim
    generic map (
      G_SEED         => X"1234567887654321",
      G_OFFSET       => 1234,
      G_DEBUG        => G_DEBUG,
      G_RANDOM       => G_RANDOM,
      G_FAST         => G_FAST,
      G_ADDR_BITS    => G_ADDR_BITS,
      G_DATA_BITS    => G_DATA_BITS,
      G_RANDOM_WSTRB => true
    )
    port map (
      clk_i       => s_clk,
      rst_i       => s_rst,
      m_awready_i => s_awready,
      m_awvalid_o => s_awvalid,
      m_awaddr_o  => s_awaddr,
      m_wready_i  => s_wready,
      m_wvalid_o  => s_wvalid,
      m_wdata_o   => s_wdata,
      m_wstrb_o   => s_wstrb,
      m_bready_o  => s_bready,
      m_bvalid_i  => s_bvalid,
      m_bresp_i   => s_bresp,
      m_arready_i => s_arready,
      m_arvalid_o => s_arvalid,
      m_araddr_o  => s_araddr,
      m_rready_o  => s_rready,
      m_rvalid_i  => s_rvalid,
      m_rdata_i   => s_rdata,
      m_rresp_i   => s_rresp
    ); -- axil_master_sim_inst : entity work.axil_master_sim


  ----------------------------------------------
  -- Random pauses on the slave side
  ----------------------------------------------

  axil_pause_inst : entity work.axil_pause
    generic map (
      G_ADDR_BITS  => G_ADDR_BITS,
      G_DATA_BITS  => G_DATA_BITS,
      G_PAUSE_SIZE => G_PAUSE_SIZE
    )
    port map (
      clk_i       => m_clk,
      rst_i       => m_rst,
      s_awready_o => m_awready,
      s_awvalid_i => m_awvalid,
      s_awaddr_i  => m_awaddr,
      s_wready_o  => m_wready,
      s_wvalid_i  => m_wvalid,
      s_wdata_i   => m_wdata,
      s_wstrb_i   => m_wstrb,
      s_bready_i  => m_bready,
      s_bvalid_o  => m_bvalid,
      s_bresp_o   => m_bresp,
      s_arready_o => m_arready,
      s_arvalid_i => m_arvalid,
      s_araddr_i  => m_araddr,
      s_rready_i  => m_rready,
      s_rvalid_o  => m_rvalid,
      s_rdata_o   => m_rdata,
      s_rresp_o   => m_rresp,
      m_awready_i => p_awready,
      m_awvalid_o => p_awvalid,
      m_awaddr_o  => p_awaddr,
      m_wready_i  => p_wready,
      m_wvalid_o  => p_wvalid,
      m_wdata_o   => p_wdata,
      m_wstrb_o   => p_wstrb,
      m_bready_o  => p_bready,
      m_bvalid_i  => p_bvalid,
      m_bresp_i   => p_bresp,
      m_arready_i => p_arready,
      m_arvalid_o => p_arvalid,
      m_araddr_o  => p_araddr,
      m_rready_o  => p_rready,
      m_rvalid_i  => p_rvalid,
      m_rdata_i   => p_rdata,
      m_rresp_i   => p_rresp
    ); -- axil_pause_inst : entity work.axil_pause


  ----------------------------------------------
  -- Memory
  ----------------------------------------------

  axil_slave_sim_inst : entity work.axil_slave_sim
    generic map (
      G_DEBUG     => G_DEBUG,
      G_FAST      => G_FAST,
      G_ADDR_BITS => G_ADDR_BITS,
      G_DATA_BITS => G_DATA_BITS
    )
    port map (
      clk_i       => m_clk,
      rst_i       => m_rst,
      s_awready_o => p_awready,
      s_awvalid_i => p_awvalid,
      s_awaddr_i  => p_awaddr,
      s_wready_o  => p_wready,
      s_wvalid_i  => p_wvalid,
      s_wdata_i   => p_wdata,
      s_wstrb_i   => p_wstrb,
      s_bready_i  => p_bready,
      s_bvalid_o  => p_bvalid,
      s_bresp_o   => p_bresp,
      s_arready_o => p_arready,
      s_arvalid_i => p_arvalid,
      s_araddr_i  => p_araddr,
      s_rready_i  => p_rready,
      s_rvalid_o  => p_rvalid,
      s_rdata_o   => p_rdata,
      s_rresp_o   => p_rresp
    ); -- axil_slave_sim_inst : entity work.axil_slave_sim

end architecture tb;
