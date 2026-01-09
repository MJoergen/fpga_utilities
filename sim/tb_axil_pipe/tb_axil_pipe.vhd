-- ---------------------------------------------------------------------------------------
-- Description: Verify axil_pipe.
-- ---------------------------------------------------------------------------------------

library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std.all;

library std;
  use std.env.stop;

entity tb_axil_pipe is
  generic (
    G_DEBUG      : boolean;
    G_PAUSE_SIZE : natural;
    G_RANDOM     : boolean;
    G_FAST       : boolean;
    G_ADDR_SIZE  : natural;
    G_DATA_SIZE  : natural
  );
end entity tb_axil_pipe;

architecture simulation of tb_axil_pipe is

  signal clk : std_logic := '1';
  signal rst : std_logic := '1';

  signal s_awready : std_logic;
  signal s_awvalid : std_logic;
  signal s_awaddr  : std_logic_vector(G_ADDR_SIZE - 1 downto 0);
  signal s_wready  : std_logic;
  signal s_wvalid  : std_logic;
  signal s_wdata   : std_logic_vector(G_DATA_SIZE - 1 downto 0);
  signal s_wstrb   : std_logic_vector(G_DATA_SIZE / 8 - 1 downto 0);
  signal s_bready  : std_logic;
  signal s_bvalid  : std_logic;
  signal s_bresp   : std_logic_vector(1 downto 0);
  signal s_arready : std_logic;
  signal s_arvalid : std_logic;
  signal s_araddr  : std_logic_vector(G_ADDR_SIZE - 1 downto 0);
  signal s_rready  : std_logic;
  signal s_rvalid  : std_logic;
  signal s_rdata   : std_logic_vector(G_DATA_SIZE - 1 downto 0);
  signal s_rresp   : std_logic_vector(1 downto 0);

  signal m_awready : std_logic;
  signal m_awvalid : std_logic;
  signal m_awaddr  : std_logic_vector(G_ADDR_SIZE - 1 downto 0);
  signal m_wready  : std_logic;
  signal m_wvalid  : std_logic;
  signal m_wdata   : std_logic_vector(G_DATA_SIZE - 1 downto 0);
  signal m_wstrb   : std_logic_vector(G_DATA_SIZE / 8 - 1 downto 0);
  signal m_bready  : std_logic;
  signal m_bvalid  : std_logic;
  signal m_bresp   : std_logic_vector(1 downto 0);
  signal m_arready : std_logic;
  signal m_arvalid : std_logic;
  signal m_araddr  : std_logic_vector(G_ADDR_SIZE - 1 downto 0);
  signal m_rready  : std_logic;
  signal m_rvalid  : std_logic;
  signal m_rdata   : std_logic_vector(G_DATA_SIZE - 1 downto 0);
  signal m_rresp   : std_logic_vector(1 downto 0);

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

  axil_pipe_inst : entity work.axil_pipe
    generic map (
      G_ADDR_SIZE => G_ADDR_SIZE,
      G_DATA_SIZE => G_DATA_SIZE
    )
    port map (
      clk_i       => clk,
      rst_i       => rst,
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
    ); -- axil_pipe_inst : entity work.axil_pipe


  ----------------------------------------------
  -- Generate stimuli and verify response
  ----------------------------------------------

  axil_sim_inst : entity work.axil_sim
    generic map (
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
    ); -- axil_sim_inst : entity work.axil_sim

end architecture simulation;

