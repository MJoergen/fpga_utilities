-- ---------------------------------------------------------------------------------------
-- Description: Verify avm_sim
-- ---------------------------------------------------------------------------------------

library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std.all;

entity tb_avm_sim is
  generic (
    G_DEBUG       : boolean;
    G_TIMEOUT_MAX : natural;
    G_DO_ABORT    : boolean;
    G_PAUSE_SIZE  : integer;
    G_ADDR_SIZE   : natural;
    G_DATA_SIZE   : natural
  );
end entity tb_avm_sim;

architecture simulation of tb_avm_sim is

  signal clk : std_logic := '1';
  signal rst : std_logic := '1';

  signal m_write         : std_logic;
  signal m_read          : std_logic;
  signal m_address       : std_logic_vector(G_ADDR_SIZE - 1 downto 0);
  signal m_writedata     : std_logic_vector(G_DATA_SIZE - 1 downto 0);
  signal m_byteenable    : std_logic_vector(G_DATA_SIZE / 8 - 1 downto 0);
  signal m_burstcount    : std_logic_vector(7 downto 0);
  signal m_readdata      : std_logic_vector(G_DATA_SIZE - 1 downto 0);
  signal m_readdatavalid : std_logic;
  signal m_waitrequest   : std_logic;

  signal s_write         : std_logic;
  signal s_read          : std_logic;
  signal s_address       : std_logic_vector(G_ADDR_SIZE - 1 downto 0);
  signal s_writedata     : std_logic_vector(G_DATA_SIZE - 1 downto 0);
  signal s_byteenable    : std_logic_vector(G_DATA_SIZE / 8 - 1 downto 0);
  signal s_burstcount    : std_logic_vector(7 downto 0);
  signal s_readdata      : std_logic_vector(G_DATA_SIZE - 1 downto 0);
  signal s_readdatavalid : std_logic;
  signal s_waitrequest   : std_logic;


begin

  --------------------------------
  -- Clock and Reset
  --------------------------------

  clk <= not clk after 5 ns;
  rst <= '1', '0' after 100 ns;


  --------------------------------
  -- Instantiate DUT
  --------------------------------

  avm_sim_inst : entity work.avm_sim
    generic map (
      G_DEBUG     => G_DEBUG,
      G_ADDR_SIZE => G_ADDR_SIZE,
      G_DATA_SIZE => G_DATA_SIZE
    )
    port map (
      clk_i             => clk,
      rst_i             => rst,
      m_write_o         => m_write,
      m_read_o          => m_read,
      m_address_o       => m_address,
      m_writedata_o     => m_writedata,
      m_byteenable_o    => m_byteenable,
      m_burstcount_o    => m_burstcount,
      m_readdata_i      => m_readdata,
      m_readdatavalid_i => m_readdatavalid,
      m_waitrequest_i   => m_waitrequest,
      s_write_i         => s_write,
      s_read_i          => s_read,
      s_address_i       => s_address,
      s_writedata_i     => s_writedata,
      s_byteenable_i    => s_byteenable,
      s_burstcount_i    => s_burstcount,
      s_readdata_o      => s_readdata,
      s_readdatavalid_o => s_readdatavalid,
      s_waitrequest_o   => s_waitrequest
    ); -- avm_master_sim_inst : entity work.avm_master_sim

  avm_pause_inst : entity work.avm_pause
    generic map (
      G_SEED       => X"12345678AABBCCDD",
      G_PAUSE_SIZE => G_PAUSE_SIZE,
      G_ADDR_SIZE  => G_ADDR_SIZE,
      G_DATA_SIZE  => G_DATA_SIZE
    )
    port map (
      clk_i             => clk,
      rst_i             => rst,
      s_write_i         => m_write,
      s_read_i          => m_read,
      s_address_i       => m_address,
      s_writedata_i     => m_writedata,
      s_byteenable_i    => m_byteenable,
      s_burstcount_i    => m_burstcount,
      s_readdata_o      => m_readdata,
      s_readdatavalid_o => m_readdatavalid,
      s_waitrequest_o   => m_waitrequest,
      m_write_o         => s_write,
      m_read_o          => s_read,
      m_address_o       => s_address,
      m_writedata_o     => s_writedata,
      m_byteenable_o    => s_byteenable,
      m_burstcount_o    => s_burstcount,
      m_readdata_i      => s_readdata,
      m_readdatavalid_i => s_readdatavalid,
      m_waitrequest_i   => s_waitrequest
    ); -- avm_pause_inst : entity work.avm_pause

end architecture simulation;

