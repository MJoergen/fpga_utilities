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
  signal s0_wready  : std_logic;
  signal s0_wvalid  : std_logic;
  signal s0_wdata   : std_logic_vector(G_DATA_SIZE - 1 downto 0);
  signal s0_wstrb   : std_logic_vector(G_DATA_SIZE / 8 - 1 downto 0);
  signal s0_bready  : std_logic;
  signal s0_bvalid  : std_logic;
  signal s0_bresp   : std_logic_vector(1 downto 0);
  signal s0_arready : std_logic;
  signal s0_arvalid : std_logic;
  signal s0_araddr  : std_logic_vector(G_ADDR_SIZE - 1 downto 0);
  signal s0_rready  : std_logic;
  signal s0_rvalid  : std_logic;
  signal s0_rdata   : std_logic_vector(G_DATA_SIZE - 1 downto 0);
  signal s0_rresp   : std_logic_vector(1 downto 0);

  signal s1_awready : std_logic;
  signal s1_awvalid : std_logic;
  signal s1_awaddr  : std_logic_vector(G_ADDR_SIZE - 1 downto 0);
  signal s1_wready  : std_logic;
  signal s1_wvalid  : std_logic;
  signal s1_wdata   : std_logic_vector(G_DATA_SIZE - 1 downto 0);
  signal s1_wstrb   : std_logic_vector(G_DATA_SIZE / 8 - 1 downto 0);
  signal s1_bready  : std_logic;
  signal s1_bvalid  : std_logic;
  signal s1_bresp   : std_logic_vector(1 downto 0);
  signal s1_arready : std_logic;
  signal s1_arvalid : std_logic;
  signal s1_araddr  : std_logic_vector(G_ADDR_SIZE - 1 downto 0);
  signal s1_rready  : std_logic;
  signal s1_rvalid  : std_logic;
  signal s1_rdata   : std_logic_vector(G_DATA_SIZE - 1 downto 0);
  signal s1_rresp   : std_logic_vector(1 downto 0);

  signal p0_awready : std_logic;
  signal p0_awvalid : std_logic;
  signal p0_awaddr  : std_logic_vector(G_ADDR_SIZE - 1 downto 0);
  signal p0_wready  : std_logic;
  signal p0_wvalid  : std_logic;
  signal p0_wdata   : std_logic_vector(G_DATA_SIZE - 1 downto 0);
  signal p0_wstrb   : std_logic_vector(G_DATA_SIZE / 8 - 1 downto 0);
  signal p0_bready  : std_logic;
  signal p0_bvalid  : std_logic;
  signal p0_bresp   : std_logic_vector(1 downto 0);
  signal p0_arready : std_logic;
  signal p0_arvalid : std_logic;
  signal p0_araddr  : std_logic_vector(G_ADDR_SIZE - 1 downto 0);
  signal p0_rready  : std_logic;
  signal p0_rvalid  : std_logic;
  signal p0_rdata   : std_logic_vector(G_DATA_SIZE - 1 downto 0);
  signal p0_rresp   : std_logic_vector(1 downto 0);

  signal p1_awready : std_logic;
  signal p1_awvalid : std_logic;
  signal p1_awaddr  : std_logic_vector(G_ADDR_SIZE - 1 downto 0);
  signal p1_wready  : std_logic;
  signal p1_wvalid  : std_logic;
  signal p1_wdata   : std_logic_vector(G_DATA_SIZE - 1 downto 0);
  signal p1_wstrb   : std_logic_vector(G_DATA_SIZE / 8 - 1 downto 0);
  signal p1_bready  : std_logic;
  signal p1_bvalid  : std_logic;
  signal p1_bresp   : std_logic_vector(1 downto 0);
  signal p1_arready : std_logic;
  signal p1_arvalid : std_logic;
  signal p1_araddr  : std_logic_vector(G_ADDR_SIZE - 1 downto 0);
  signal p1_rready  : std_logic;
  signal p1_rvalid  : std_logic;
  signal p1_rdata   : std_logic_vector(G_DATA_SIZE - 1 downto 0);
  signal p1_rresp   : std_logic_vector(1 downto 0);

  signal d_awready : std_logic;
  signal d_awvalid : std_logic;
  signal d_awaddr  : std_logic_vector(G_ADDR_SIZE downto 0);
  signal d_wready  : std_logic;
  signal d_wvalid  : std_logic;
  signal d_wdata   : std_logic_vector(G_DATA_SIZE - 1 downto 0);
  signal d_wstrb   : std_logic_vector(G_DATA_SIZE / 8 - 1 downto 0);
  signal d_bready  : std_logic;
  signal d_bvalid  : std_logic;
  signal d_bresp   : std_logic_vector(1 downto 0);
  signal d_arready : std_logic;
  signal d_arvalid : std_logic;
  signal d_araddr  : std_logic_vector(G_ADDR_SIZE downto 0);
  signal d_rready  : std_logic;
  signal d_rvalid  : std_logic;
  signal d_rdata   : std_logic_vector(G_DATA_SIZE - 1 downto 0);
  signal d_rresp   : std_logic_vector(1 downto 0);

  signal p_awready : std_logic;
  signal p_awvalid : std_logic;
  signal p_awaddr  : std_logic_vector(G_ADDR_SIZE downto 0);
  signal p_wready  : std_logic;
  signal p_wvalid  : std_logic;
  signal p_wdata   : std_logic_vector(G_DATA_SIZE - 1 downto 0);
  signal p_wstrb   : std_logic_vector(G_DATA_SIZE / 8 - 1 downto 0);
  signal p_bready  : std_logic;
  signal p_bvalid  : std_logic;
  signal p_bresp   : std_logic_vector(1 downto 0);
  signal p_arready : std_logic;
  signal p_arvalid : std_logic;
  signal p_araddr  : std_logic_vector(G_ADDR_SIZE downto 0);
  signal p_rready  : std_logic;
  signal p_rvalid  : std_logic;
  signal p_rdata   : std_logic_vector(G_DATA_SIZE - 1 downto 0);
  signal p_rresp   : std_logic_vector(1 downto 0);

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
      G_ADDR_SIZE => G_ADDR_SIZE + 1,
      G_DATA_SIZE => G_DATA_SIZE
    )
    port map (
      clk_i        => clk,
      rst_i        => rst,
      s0_awready_o => p0_awready,
      s0_awvalid_i => p0_awvalid,
      s0_awaddr_i  => "0" & p0_awaddr,
      s0_wready_o  => p0_wready,
      s0_wvalid_i  => p0_wvalid,
      s0_wdata_i   => p0_wdata,
      s0_wstrb_i   => p0_wstrb,
      s0_bready_i  => p0_bready,
      s0_bvalid_o  => p0_bvalid,
      s0_bresp_o   => p0_bresp,
      s0_arready_o => p0_arready,
      s0_arvalid_i => p0_arvalid,
      s0_araddr_i  => "0" & p0_araddr,
      s0_rready_i  => p0_rready,
      s0_rvalid_o  => p0_rvalid,
      s0_rdata_o   => p0_rdata,
      s0_rresp_o   => p0_rresp,
      s1_awready_o => p1_awready,
      s1_awvalid_i => p1_awvalid,
      s1_awaddr_i  => "1" & p1_awaddr,
      s1_wready_o  => p1_wready,
      s1_wvalid_i  => p1_wvalid,
      s1_wdata_i   => p1_wdata,
      s1_wstrb_i   => p1_wstrb,
      s1_bready_i  => p1_bready,
      s1_bvalid_o  => p1_bvalid,
      s1_bresp_o   => p1_bresp,
      s1_arready_o => p1_arready,
      s1_arvalid_i => p1_arvalid,
      s1_araddr_i  => "1" & p1_araddr,
      s1_rready_i  => p1_rready,
      s1_rvalid_o  => p1_rvalid,
      s1_rdata_o   => p1_rdata,
      s1_rresp_o   => p1_rresp,
      m_awready_i  => d_awready,
      m_awvalid_o  => d_awvalid,
      m_awaddr_o   => d_awaddr,
      m_wready_i   => d_wready,
      m_wvalid_o   => d_wvalid,
      m_wdata_o    => d_wdata,
      m_wstrb_o    => d_wstrb,
      m_bready_o   => d_bready,
      m_bvalid_i   => d_bvalid,
      m_bresp_i    => d_bresp,
      m_arready_i  => d_arready,
      m_arvalid_o  => d_arvalid,
      m_araddr_o   => d_araddr,
      m_rready_o   => d_rready,
      m_rvalid_i   => d_rvalid,
      m_rdata_i    => d_rdata,
      m_rresp_i    => d_rresp
    ); -- axil_arbiter_inst : entity work.axil_arbiter


  ----------------------------------------------
  -- Instantiate AXI lite masters
  ----------------------------------------------

  axil_master_sim_0_inst : entity work.axil_master_sim
    generic map (
      G_NAME      => "0",
      G_SEED      => X"1234567887654321",
      G_OFFSET    => 1234,
      G_DEBUG     => G_DEBUG,
      G_RANDOM    => G_RANDOM,
      G_FAST      => G_FAST,
      G_ADDR_SIZE => G_ADDR_SIZE,
      G_DATA_SIZE => G_DATA_SIZE
    )
    port map (
      clk_i       => clk,
      rst_i       => rst,
      m_awready_i => s0_awready,
      m_awvalid_o => s0_awvalid,
      m_awaddr_o  => s0_awaddr,
      m_wready_i  => s0_wready,
      m_wvalid_o  => s0_wvalid,
      m_wdata_o   => s0_wdata,
      m_wstrb_o   => s0_wstrb,
      m_bready_o  => s0_bready,
      m_bvalid_i  => s0_bvalid,
      m_bresp_i   => s0_bresp,
      m_arready_i => s0_arready,
      m_arvalid_o => s0_arvalid,
      m_araddr_o  => s0_araddr,
      m_rready_o  => s0_rready,
      m_rvalid_i  => s0_rvalid,
      m_rdata_i   => s0_rdata,
      m_rresp_i   => s0_rresp
    ); -- axil_master_sim_0_inst : entity work.axil_master_sim

  axil_master_sim_1_inst : entity work.axil_master_sim
    generic map (
      G_NAME      => "1",
      G_SEED      => X"ABCDEFABCDEFABCD",
      G_OFFSET    => 4321,
      G_DEBUG     => G_DEBUG,
      G_RANDOM    => G_RANDOM,
      G_FAST      => G_FAST,
      G_ADDR_SIZE => G_ADDR_SIZE,
      G_DATA_SIZE => G_DATA_SIZE
    )
    port map (
      clk_i       => clk,
      rst_i       => rst,
      m_awready_i => s1_awready,
      m_awvalid_o => s1_awvalid,
      m_awaddr_o  => s1_awaddr,
      m_wready_i  => s1_wready,
      m_wvalid_o  => s1_wvalid,
      m_wdata_o   => s1_wdata,
      m_wstrb_o   => s1_wstrb,
      m_bready_o  => s1_bready,
      m_bvalid_i  => s1_bvalid,
      m_bresp_i   => s1_bresp,
      m_arready_i => s1_arready,
      m_arvalid_o => s1_arvalid,
      m_araddr_o  => s1_araddr,
      m_rready_o  => s1_rready,
      m_rvalid_i  => s1_rvalid,
      m_rdata_i   => s1_rdata,
      m_rresp_i   => s1_rresp
    ); -- axil_master_sim_1_inst : entity work.axil_master_sim


  ----------------------------------------------
  -- Instantiate AXI lite pauses
  ----------------------------------------------

  axil_pause_0_inst : entity work.axil_pause
    generic map (
      G_SEED       => X"8765432112345678",
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
      s_wready_o  => s0_wready,
      s_wvalid_i  => s0_wvalid,
      s_wdata_i   => s0_wdata,
      s_wstrb_i   => s0_wstrb,
      s_bready_i  => s0_bready,
      s_bvalid_o  => s0_bvalid,
      s_bresp_o   => s0_bresp,
      s_arready_o => s0_arready,
      s_arvalid_i => s0_arvalid,
      s_araddr_i  => s0_araddr,
      s_rready_i  => s0_rready,
      s_rvalid_o  => s0_rvalid,
      s_rdata_o   => s0_rdata,
      s_rresp_o   => s0_rresp,
      m_awready_i => p0_awready,
      m_awvalid_o => p0_awvalid,
      m_awaddr_o  => p0_awaddr,
      m_wready_i  => p0_wready,
      m_wvalid_o  => p0_wvalid,
      m_wdata_o   => p0_wdata,
      m_wstrb_o   => p0_wstrb,
      m_bready_o  => p0_bready,
      m_bvalid_i  => p0_bvalid,
      m_bresp_i   => p0_bresp,
      m_arready_i => p0_arready,
      m_arvalid_o => p0_arvalid,
      m_araddr_o  => p0_araddr,
      m_rready_o  => p0_rready,
      m_rvalid_i  => p0_rvalid,
      m_rdata_i   => p0_rdata,
      m_rresp_i   => p0_rresp
    ); -- axil_pause_0_inst : entity work.axil_pause

  axil_pause_1_inst : entity work.axil_pause
    generic map (
      G_SEED       => X"ABCDEFABCDEFABCD",
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
      s_wready_o  => s1_wready,
      s_wvalid_i  => s1_wvalid,
      s_wdata_i   => s1_wdata,
      s_wstrb_i   => s1_wstrb,
      s_bready_i  => s1_bready,
      s_bvalid_o  => s1_bvalid,
      s_bresp_o   => s1_bresp,
      s_arready_o => s1_arready,
      s_arvalid_i => s1_arvalid,
      s_araddr_i  => s1_araddr,
      s_rready_i  => s1_rready,
      s_rvalid_o  => s1_rvalid,
      s_rdata_o   => s1_rdata,
      s_rresp_o   => s1_rresp,
      m_awready_i => p1_awready,
      m_awvalid_o => p1_awvalid,
      m_awaddr_o  => p1_awaddr,
      m_wready_i  => p1_wready,
      m_wvalid_o  => p1_wvalid,
      m_wdata_o   => p1_wdata,
      m_wstrb_o   => p1_wstrb,
      m_bready_o  => p1_bready,
      m_bvalid_i  => p1_bvalid,
      m_bresp_i   => p1_bresp,
      m_arready_i => p1_arready,
      m_arvalid_o => p1_arvalid,
      m_araddr_o  => p1_araddr,
      m_rready_o  => p1_rready,
      m_rvalid_i  => p1_rvalid,
      m_rdata_i   => p1_rdata,
      m_rresp_i   => p1_rresp
    ); -- axil_pause_1_inst : entity work.axil_pause

  axil_pause_d_inst : entity work.axil_pause
    generic map (
      G_SEED       => X"DEADBEEFC007BABE",
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
      s_wready_o  => d_wready,
      s_wvalid_i  => d_wvalid,
      s_wdata_i   => d_wdata,
      s_wstrb_i   => d_wstrb,
      s_bready_i  => d_bready,
      s_bvalid_o  => d_bvalid,
      s_bresp_o   => d_bresp,
      s_arready_o => d_arready,
      s_arvalid_i => d_arvalid,
      s_araddr_i  => d_araddr,
      s_rready_i  => d_rready,
      s_rvalid_o  => d_rvalid,
      s_rdata_o   => d_rdata,
      s_rresp_o   => d_rresp,
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
    ); -- axil_pause_d_inst : entity work.axil_pause


  ----------------------------------------------
  -- Instantiate AXI lite slave
  ----------------------------------------------

  axil_slave_sim_inst : entity work.axil_slave_sim
    generic map (
      G_DEBUG     => G_DEBUG,
      G_FAST      => G_FAST,
      G_ADDR_SIZE => G_ADDR_SIZE + 1,
      G_DATA_SIZE => G_DATA_SIZE
    )
    port map (
      clk_i       => clk,
      rst_i       => rst,
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

  check_proc : process (clk)
  begin
    if rising_edge(clk) then
      assert (s0_busy and s1_busy) /= '1'
        report "axi_lite_arbiter: ERROR: Both slaves busy";
    end if;
  end process check_proc;

end architecture simulation;

