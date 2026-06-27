-- ---------------------------------------------------------------------------------------
-- Description:
--
-- SPDX-License-Identifier: MIT
-- ---------------------------------------------------------------------------------------

library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std.all;

entity tb_avm_to_wbus is
  generic (
    G_BURST_BITS  : positive := 8;
    G_MAX_BURST   : positive := 8;
    G_DEBUG       : boolean;
    G_PAUSE_SIZE  : natural;
    G_TIMEOUT_MAX : natural  := 0;
    G_ADDR_BITS   : positive; -- Number of bits
    G_DATA_BITS   : positive  -- Number of bits
  );
end entity tb_avm_to_wbus;

architecture tb of tb_avm_to_wbus is

  constant C_CLK_PERIOD : time := 10 ns;

  signal   clk : std_logic     := '1';
  signal   rst : std_logic     := '1';

  signal   avm_write         : std_logic;
  signal   avm_read          : std_logic;
  signal   avm_address       : std_logic_vector(G_ADDR_BITS - 1 downto 0);
  signal   avm_writedata     : std_logic_vector(G_DATA_BITS - 1 downto 0);
  signal   avm_byteenable    : std_logic_vector(G_DATA_BITS / 8 - 1 downto 0);
  signal   avm_burstcount    : std_logic_vector(G_BURST_BITS - 1 downto 0);
  signal   avm_readdata      : std_logic_vector(G_DATA_BITS - 1 downto 0);
  signal   avm_readdatavalid : std_logic;
  signal   avm_waitrequest   : std_logic;

  signal   wbus_cyc          : std_logic;
  signal   wbus_stall        : std_logic;
  signal   wbus_stb          : std_logic;
  signal   wbus_addr         : std_logic_vector(G_ADDR_BITS - 1 downto 0);
  signal   wbus_we           : std_logic;
  signal   wbus_wrdat        : std_logic_vector(G_DATA_BITS - 1 downto 0);
  signal   wbus_sel          : std_logic_vector(G_DATA_BITS / 8 - 1 downto 0);
  signal   wbus_ack          : std_logic;
  signal   wbus_rddat        : std_logic_vector(G_DATA_BITS - 1 downto 0);

begin

  clk <= not clk after C_CLK_PERIOD / 2;
  rst <= '1', '0' after 10 * C_CLK_PERIOD;


  ---------------------------------------------------------
  -- Instantiate DUT
  ---------------------------------------------------------

  avm_to_wbus_inst : entity work.avm_to_wbus
    generic map (
      G_BURST_BITS => G_BURST_BITS,
      G_ADDR_BITS  => G_ADDR_BITS,
      G_DATA_BITS  => G_DATA_BITS
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
      s_readdata_o      => avm_readdata,
      s_readdatavalid_o => avm_readdatavalid,
      m_cyc_o           => wbus_cyc,
      m_stall_i         => wbus_stall,
      m_stb_o           => wbus_stb,
      m_addr_o          => wbus_addr,
      m_we_o            => wbus_we,
      m_wrdat_o         => wbus_wrdat,
      m_sel_o           => wbus_sel,
      m_ack_i           => wbus_ack,
      m_rddat_i         => wbus_rddat
    ); -- avm_to_wbus_inst : entity work.avm_to_wbus


  ---------------------------------------------------------
  -- Generate stimuli
  ---------------------------------------------------------

  avm_master_sim_inst : entity work.avm_master_sim
    generic map (
      G_BURST_BITS  => G_BURST_BITS,
      G_MAX_BURST   => G_MAX_BURST,
      G_SEED        => X"DEADBEEFC007BABE",
      G_NAME        => "",
      G_DEBUG       => G_DEBUG,
      G_OFFSET      => 1234,
      G_TIMEOUT_MAX => G_TIMEOUT_MAX,
      G_ADDR_BITS   => G_ADDR_BITS,
      G_DATA_BITS   => G_DATA_BITS
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
    ); -- avm_master_sim_inst : entity work.avm_master_sim


  ------------------------------------------
  -- Instantiate Wishbone Slave
  ------------------------------------------

  wbus_slave_sim_inst : entity work.wbus_slave_sim
    generic map (
      G_NAME      => "",
      G_DEBUG     => G_DEBUG,
      G_ADDR_BITS => G_ADDR_BITS,
      G_DATA_BITS => G_DATA_BITS
    )
    port map (
      clk_i     => clk,
      rst_i     => rst,
      s_cyc_i   => wbus_cyc,
      s_stall_o => wbus_stall,
      s_stb_i   => wbus_stb,
      s_addr_i  => wbus_addr,
      s_we_i    => wbus_we,
      s_wrdat_i => wbus_wrdat,
      s_sel_i   => wbus_sel,
      s_ack_o   => wbus_ack,
      s_rddat_o => wbus_rddat
    ); -- wbus_slave_sim_inst : entity work.wbus_slave_sim

end architecture tb;

