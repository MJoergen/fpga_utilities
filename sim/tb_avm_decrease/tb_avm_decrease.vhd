-- ---------------------------------------------------------------------------------------
-- Description: Verify avm_sim
-- ---------------------------------------------------------------------------------------

library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std.all;

entity tb_avm_decrease is
  generic (
    G_BURST_BITS      : positive;
    G_MAX_BURST        : positive;
    G_DEBUG            : boolean;
    G_PAUSE_SIZE       : integer;
    G_TIMEOUT_MAX      : natural;
    G_SLAVE_ADDR_BITS  : positive;
    G_SLAVE_DATA_BITS  : positive;
    G_MASTER_ADDR_BITS : positive;
    G_MASTER_DATA_BITS : positive
  );
end entity tb_avm_decrease;

architecture tb of tb_avm_decrease is

  signal clk : std_logic := '1';
  signal rst : std_logic := '1';

  signal s_write         : std_logic;
  signal s_read          : std_logic;
  signal s_address       : std_logic_vector(G_SLAVE_ADDR_BITS - 1 downto 0);
  signal s_writedata     : std_logic_vector(G_SLAVE_DATA_BITS - 1 downto 0);
  signal s_byteenable    : std_logic_vector(G_SLAVE_DATA_BITS / 8 - 1 downto 0);
  signal s_burstcount    : std_logic_vector(G_BURST_BITS - 1 downto 0);
  signal s_readdata      : std_logic_vector(G_SLAVE_DATA_BITS - 1 downto 0);
  signal s_readdatavalid : std_logic;
  signal s_waitrequest   : std_logic;

  signal m_write         : std_logic;
  signal m_read          : std_logic;
  signal m_address       : std_logic_vector(G_MASTER_ADDR_BITS - 1 downto 0);
  signal m_writedata     : std_logic_vector(G_MASTER_DATA_BITS - 1 downto 0);
  signal m_byteenable    : std_logic_vector(G_MASTER_DATA_BITS / 8 - 1 downto 0);
  signal m_burstcount    : std_logic_vector(G_BURST_BITS - 1 downto 0);
  signal m_readdata      : std_logic_vector(G_MASTER_DATA_BITS - 1 downto 0);
  signal m_readdatavalid : std_logic;
  signal m_waitrequest   : std_logic;

begin

  --------------------------------
  -- Clock and Reset
  --------------------------------

  clk <= not clk after 5 ns;
  rst <= '1', '0' after 100 ns;


  --------------------------------
  -- Instantiate DUT
  --------------------------------

  avm_decrease_inst : entity work.avm_decrease
    generic map (
      G_BURST_BITS         => G_BURST_BITS,
      G_SLAVE_ADDRESS_BITS  => G_SLAVE_ADDR_BITS,
      G_SLAVE_DATA_BITS     => G_SLAVE_DATA_BITS,
      G_MASTER_ADDRESS_BITS => G_MASTER_ADDR_BITS,
      G_MASTER_DATA_BITS    => G_MASTER_DATA_BITS
    )
    port map (
      clk_i             => clk,
      rst_i             => rst,
      s_write_i         => s_write,
      s_read_i          => s_read,
      s_address_i       => s_address,
      s_writedata_i     => s_writedata,
      s_byteenable_i    => s_byteenable,
      s_burstcount_i    => s_burstcount,
      s_readdata_o      => s_readdata,
      s_readdatavalid_o => s_readdatavalid,
      s_waitrequest_o   => s_waitrequest,
      m_write_o         => m_write,
      m_read_o          => m_read,
      m_address_o       => m_address,
      m_writedata_o     => m_writedata,
      m_byteenable_o    => m_byteenable,
      m_burstcount_o    => m_burstcount,
      m_readdata_i      => m_readdata,
      m_readdatavalid_i => m_readdatavalid,
      m_waitrequest_i   => m_waitrequest
    );


  --------------------------------
  -- Generate stimuli
  --------------------------------

  avm_master_sim_inst : entity work.avm_master_sim
    generic map (
      G_BURST_BITS        => G_BURST_BITS,
      G_MAX_BURST         => G_MAX_BURST,
      G_RANDOM_BYTEENABLE => false,
      G_SEED              => X"DEADBEEFC007BABE",
      G_NAME              => "MASTER",
      G_DEBUG             => G_DEBUG,
      G_OFFSET            => 1234,
      G_TIMEOUT_MAX       => 0,
      G_ADDR_BITS         => G_SLAVE_ADDR_BITS,
      G_DATA_BITS         => G_SLAVE_DATA_BITS
    )
    port map (
      clk_i             => clk,
      rst_i             => rst,
      m_waitrequest_i   => s_waitrequest,
      m_write_o         => s_write,
      m_read_o          => s_read,
      m_address_o       => s_address,
      m_writedata_o     => s_writedata,
      m_byteenable_o    => s_byteenable,
      m_burstcount_o    => s_burstcount,
      m_readdatavalid_i => s_readdatavalid,
      m_readdata_i      => s_readdata
    );


  --------------------------------
  -- Instantiate Avalon Slave
  --------------------------------

  avm_slave_sim_inst : entity work.avm_slave_sim
    generic map (
      G_BURST_BITS  => G_BURST_BITS,
      G_NAME        => "SLAVE",
      G_DEBUG       => G_DEBUG,
      G_ADDR_BITS   => G_MASTER_ADDR_BITS,
      G_DATA_BITS   => G_MASTER_DATA_BITS
    )
    port map (
      clk_i             => clk,
      rst_i             => rst,
      s_waitrequest_o   => m_waitrequest,
      s_write_i         => m_write,
      s_read_i          => m_read,
      s_address_i       => m_address,
      s_writedata_i     => m_writedata,
      s_byteenable_i    => m_byteenable,
      s_burstcount_i    => m_burstcount,
      s_readdatavalid_o => m_readdatavalid,
      s_readdata_o      => m_readdata
    );

end architecture tb;

