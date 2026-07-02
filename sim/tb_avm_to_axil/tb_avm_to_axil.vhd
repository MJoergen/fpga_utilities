-- ---------------------------------------------------------------------------------------
-- Description: Simple testbench for the avm_to_axil module.
--
-- Uses a generic Avalon MM MASTER and a generic AXI Lite SLAVE to connect to the DUT:
--
-- TODO: Add PAUSEs to both the MASTER and SLAVE sides of the DUT for improved test coverage.
--
-- SPDX-License-Identifier: MIT
-- ---------------------------------------------------------------------------------------

library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std.all;

entity tb_avm_to_axil is
  generic (
    G_BURST_BITS        : positive                      := 8;
    G_MAX_BURST         : positive                      := 8;
    G_RANDOM_BYTEENABLE : boolean                       := false;
    G_SEED              : std_logic_vector(63 downto 0) := x"DEADBEEFC007BABE";
    G_NAME              : string                        := "";
    G_DEBUG             : boolean                       := false;
    G_FAST              : boolean                       := true;
    G_OFFSET            : natural                       := 1234;
    G_TIMEOUT_MAX       : natural                       := 0;
    G_ADDR_BITS         : positive;
    G_DATA_BITS         : positive
  );
end entity tb_avm_to_axil;

architecture tb of tb_avm_to_axil is

  -- Clock and reset
  signal clk : std_logic := '1';
  signal rst : std_logic := '1';

  -- Avalon Memory Map
  signal avm_waitrequest   : std_logic;
  signal avm_write         : std_logic;
  signal avm_read          : std_logic;
  signal avm_address       : std_logic_vector(G_ADDR_BITS - 1 downto 0);
  signal avm_writedata     : std_logic_vector(G_DATA_BITS - 1 downto 0);
  signal avm_byteenable    : std_logic_vector(G_DATA_BITS / 8 - 1 downto 0);
  signal avm_burstcount    : std_logic_vector(G_BURST_BITS - 1 downto 0);
  signal avm_readdatavalid : std_logic;
  signal avm_readdata      : std_logic_vector(G_DATA_BITS - 1 downto 0);

  -- AXI-Lite
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

  clk <= not clk after 5 ns;
  rst <= '1', '0' after 100 ns;

  -- Instantiate DUT
  avm_to_axil_inst : entity work.avm_to_axil
    generic map (
      G_ADDR_BITS  => G_ADDR_BITS,
      G_DATA_BITS  => G_DATA_BITS,
      G_BURST_BITS => G_BURST_BITS
    )
    port map (
      clk_i             => clk,
      rst_i             => rst,
      s_waitrequest_o   => avm_waitrequest,
      s_write_i         => avm_write,
      s_read_i          => avm_read,
      s_address_i       => avm_address,
      s_writedata_i     => avm_writedata,
      s_byteenable_i    => avm_byteenable,
      s_burstcount_i    => avm_burstcount,
      s_readdatavalid_o => avm_readdatavalid,
      s_readdata_o      => avm_readdata,
      m_awready_i       => axil_awready,
      m_awvalid_o       => axil_awvalid,
      m_awaddr_o        => axil_awaddr,
      m_wready_i        => axil_wready,
      m_wvalid_o        => axil_wvalid,
      m_wdata_o         => axil_wdata,
      m_wstrb_o         => axil_wstrb,
      m_bready_o        => axil_bready,
      m_bvalid_i        => axil_bvalid,
      m_bresp_i         => axil_bresp,
      m_arready_i       => axil_arready,
      m_arvalid_o       => axil_arvalid,
      m_araddr_o        => axil_araddr,
      m_rready_o        => axil_rready,
      m_rvalid_i        => axil_rvalid,
      m_rdata_i         => axil_rdata,
      m_rresp_i         => axil_rresp
    );

  -- Instantiate Avalon MM Master for stimuli
  avm_master_sim_inst : entity work.avm_master_sim
    generic map (
      G_BURST_BITS        => G_BURST_BITS,
      G_MAX_BURST         => G_MAX_BURST,
      G_RANDOM_BYTEENABLE => G_RANDOM_BYTEENABLE,
      G_SEED              => G_SEED,
      G_NAME              => G_NAME,
      G_DEBUG             => G_DEBUG,
      G_OFFSET            => G_OFFSET,
      G_TIMEOUT_MAX       => G_TIMEOUT_MAX,
      G_ADDR_BITS         => G_ADDR_BITS,
      G_DATA_BITS         => G_DATA_BITS
    )
    port map (
      clk_i             => clk,
      rst_i             => rst,
      m_waitrequest_i   => avm_waitrequest,
      m_write_o         => avm_write,
      m_read_o          => avm_read,
      m_address_o       => avm_address,
      m_writedata_o     => avm_writedata,
      m_byteenable_o    => avm_byteenable,
      m_burstcount_o    => avm_burstcount,
      m_readdatavalid_i => avm_readdatavalid,
      m_readdata_i      => avm_readdata
    ); -- avm_master_sim_inst

  axil_slave_sim_inst : entity work.axil_slave_sim
    generic map (
      G_DEBUG     => G_DEBUG,
      G_FAST      => G_FAST,
      G_ADDR_BITS => G_ADDR_BITS,
      G_DATA_BITS => G_DATA_BITS
    )
    port map (
      clk_i       => clk,
      rst_i       => rst,
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
      s_rresp_o   => axil_rresp
    ); -- axil_slave_sim_inst

end architecture tb;

