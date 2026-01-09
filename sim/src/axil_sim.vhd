-- ---------------------------------------------------------------------------------------
-- Description: This provides stimulus to and verifies response from an AXI lite
-- interface.  It generates a sequence of Writes and Reads, and verifies that the values
-- returned from Read matches the corresponding values during Write.
-- ---------------------------------------------------------------------------------------

library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std.all;

entity axil_sim is
  generic (
    G_SEED      : std_logic_vector(63 downto 0) := x"DEADBEEFC007BABE";
    G_OFFSET    : natural;
    G_DEBUG     : boolean;
    G_RANDOM    : boolean;
    G_FAST      : boolean;
    G_ADDR_SIZE : natural;
    G_DATA_SIZE : natural
  );
  port (
    clk_i       : in    std_logic;
    rst_i       : in    std_logic;

    -- Stimulus
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
    m_rresp_i   : in    std_logic_vector(1 downto 0);

    -- Response
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
    s_rresp_o   : out   std_logic_vector(1 downto 0)
  );
end entity axil_sim;

architecture simulation of axil_sim is

begin

  axil_master_sim_inst : entity work.axil_master_sim
    generic map (
      G_SEED      => G_SEED,
      G_OFFSET    => G_OFFSET,
      G_DEBUG     => G_DEBUG,
      G_RANDOM    => G_RANDOM,
      G_FAST      => G_FAST,
      G_ADDR_SIZE => G_ADDR_SIZE,
      G_DATA_SIZE => G_DATA_SIZE
    )
    port map (
      clk_i       => clk_i,
      rst_i       => rst_i,
      m_awready_i => m_awready_i,
      m_awvalid_o => m_awvalid_o,
      m_awaddr_o  => m_awaddr_o,
      m_wready_i  => m_wready_i,
      m_wvalid_o  => m_wvalid_o,
      m_wdata_o   => m_wdata_o,
      m_wstrb_o   => m_wstrb_o,
      m_bready_o  => m_bready_o,
      m_bvalid_i  => m_bvalid_i,
      m_bresp_i   => m_bresp_i,
      m_arready_i => m_arready_i,
      m_arvalid_o => m_arvalid_o,
      m_araddr_o  => m_araddr_o,
      m_rready_o  => m_rready_o,
      m_rvalid_i  => m_rvalid_i,
      m_rdata_i   => m_rdata_i,
      m_rresp_i   => m_rresp_i
    ); -- axil_master_sim_inst : entity work.axil_master_sim

  axil_slave_sim_inst : entity work.axil_slave_sim
    generic map (
      G_DEBUG     => G_DEBUG,
      G_FAST      => G_FAST,
      G_ADDR_SIZE => G_ADDR_SIZE,
      G_DATA_SIZE => G_DATA_SIZE
    )
    port map (
      clk_i       => clk_i,
      rst_i       => rst_i,
      s_awready_o => s_awready_o,
      s_awvalid_i => s_awvalid_i,
      s_awaddr_i  => s_awaddr_i,
      s_wready_o  => s_wready_o,
      s_wvalid_i  => s_wvalid_i,
      s_wdata_i   => s_wdata_i,
      s_wstrb_i   => s_wstrb_i,
      s_bready_i  => s_bready_i,
      s_bvalid_o  => s_bvalid_o,
      s_bresp_o   => s_bresp_o,
      s_arready_o => s_arready_o,
      s_arvalid_i => s_arvalid_i,
      s_araddr_i  => s_araddr_i,
      s_rready_i  => s_rready_i,
      s_rvalid_o  => s_rvalid_o,
      s_rdata_o   => s_rdata_o,
      s_rresp_o   => s_rresp_o
    ); -- axil_slave_sim_inst : entity work.axil_slave_sim

end architecture simulation;

