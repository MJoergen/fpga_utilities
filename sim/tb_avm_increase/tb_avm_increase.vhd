library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std.all;

entity tb_avm_increase is
  generic (
    G_BURST_WIDTH      : positive := 8;
    G_MAX_BURST        : positive := 8;
    G_DEBUG            : boolean;
    G_PAUSE_SIZE       : natural;
    G_TIMEOUT_MAX      : natural  := 0;
    G_SLAVE_ADDR_SIZE  : positive; -- Number of bits
    G_SLAVE_DATA_SIZE  : positive; -- Number of bits
    G_MASTER_ADDR_SIZE : positive; -- Number of bits
    G_MASTER_DATA_SIZE : positive  -- Number of bits
  );
end entity tb_avm_increase;

architecture simulation of tb_avm_increase is

  constant C_CLK_PERIOD : time := 10 ns;

  signal   clk : std_logic     := '1';
  signal   rst : std_logic     := '1';

  signal   s_write         : std_logic;
  signal   s_read          : std_logic;
  signal   s_address       : std_logic_vector(G_SLAVE_ADDR_SIZE - 1 downto 0);
  signal   s_writedata     : std_logic_vector(G_SLAVE_DATA_SIZE - 1 downto 0);
  signal   s_byteenable    : std_logic_vector(G_SLAVE_DATA_SIZE / 8 - 1 downto 0);
  signal   s_burstcount    : std_logic_vector(G_BURST_WIDTH - 1 downto 0);
  signal   s_readdata      : std_logic_vector(G_SLAVE_DATA_SIZE - 1 downto 0);
  signal   s_readdatavalid : std_logic;
  signal   s_waitrequest   : std_logic;

  signal   sp_write         : std_logic;
  signal   sp_read          : std_logic;
  signal   sp_address       : std_logic_vector(G_SLAVE_ADDR_SIZE - 1 downto 0);
  signal   sp_writedata     : std_logic_vector(G_SLAVE_DATA_SIZE - 1 downto 0);
  signal   sp_byteenable    : std_logic_vector(G_SLAVE_DATA_SIZE / 8 - 1 downto 0);
  signal   sp_burstcount    : std_logic_vector(G_BURST_WIDTH - 1 downto 0);
  signal   sp_readdata      : std_logic_vector(G_SLAVE_DATA_SIZE - 1 downto 0);
  signal   sp_readdatavalid : std_logic;
  signal   sp_waitrequest   : std_logic;

  signal   m_write         : std_logic;
  signal   m_read          : std_logic;
  signal   m_address       : std_logic_vector(G_MASTER_ADDR_SIZE - 1 downto 0);
  signal   m_writedata     : std_logic_vector(G_MASTER_DATA_SIZE - 1 downto 0);
  signal   m_byteenable    : std_logic_vector(G_MASTER_DATA_SIZE / 8 - 1 downto 0);
  signal   m_burstcount    : std_logic_vector(G_BURST_WIDTH - 1 downto 0);
  signal   m_readdata      : std_logic_vector(G_MASTER_DATA_SIZE - 1 downto 0);
  signal   m_readdatavalid : std_logic;
  signal   m_waitrequest   : std_logic;

begin

  clk <= not clk after C_CLK_PERIOD / 2;
  rst <= '1', '0' after 10 * C_CLK_PERIOD;


  ---------------------------------------------------------
  -- Instantiate DUT
  ---------------------------------------------------------

  avm_increase_inst : entity work.avm_increase
    generic map (
      G_BURST_WIDTH         => G_BURST_WIDTH,
      G_SLAVE_ADDRESS_SIZE  => G_SLAVE_ADDR_SIZE,
      G_MASTER_ADDRESS_SIZE => G_MASTER_ADDR_SIZE,
      G_SLAVE_DATA_SIZE     => G_SLAVE_DATA_SIZE,
      G_MASTER_DATA_SIZE    => G_MASTER_DATA_SIZE
    )
    port map (
      clk_i             => clk,
      rst_i             => rst,
      s_waitrequest_o   => sp_waitrequest,
      s_write_i         => sp_write,
      s_read_i          => sp_read,
      s_address_i       => sp_address,
      s_writedata_i     => sp_writedata,
      s_byteenable_i    => sp_byteenable,
      s_burstcount_i    => sp_burstcount,
      s_readdata_o      => sp_readdata,
      s_readdatavalid_o => sp_readdatavalid,
      m_waitrequest_i   => m_waitrequest,
      m_write_o         => m_write,
      m_read_o          => m_read,
      m_address_o       => m_address,
      m_writedata_o     => m_writedata,
      m_byteenable_o    => m_byteenable,
      m_burstcount_o    => m_burstcount,
      m_readdata_i      => m_readdata,
      m_readdatavalid_i => m_readdatavalid
    ); -- avm_increase_inst


  ---------------------------------------------------------
  -- Generate stimuli
  ---------------------------------------------------------

  avm_master_sim_inst : entity work.avm_master_sim
    generic map (
      G_BURST_WIDTH => G_BURST_WIDTH,
      G_MAX_BURST   => G_MAX_BURST,
      G_SEED        => X"DEADBEEFC007BABE",
      G_NAME        => "",
      G_DEBUG       => G_DEBUG,
      G_OFFSET      => 1234,
      G_TIMEOUT_MAX => G_TIMEOUT_MAX,
      G_ADDR_SIZE   => G_SLAVE_ADDR_SIZE,
      G_DATA_SIZE   => G_SLAVE_DATA_SIZE
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
    ); -- avm_master_sim_inst : entity work.avm_master_sim

  avm_pause_inst : entity work.avm_pause
    generic map (
      G_BURST_WIDTH  => G_BURST_WIDTH,
      G_MAX_BURST    => G_MAX_BURST,
      G_SEED         => X"CAFEBABEC007DEAD",
      G_PAUSE_SIZE   => G_PAUSE_SIZE,
      G_ADDR_SIZE    => G_SLAVE_ADDR_SIZE,
      G_DATA_SIZE    => G_SLAVE_DATA_SIZE
    )
    port map (
      clk_i             => clk,
      rst_i             => rst,
      s_waitrequest_o   => s_waitrequest,
      s_write_i         => s_write,
      s_read_i          => s_read,
      s_address_i       => s_address,
      s_writedata_i     => s_writedata,
      s_byteenable_i    => s_byteenable,
      s_burstcount_i    => s_burstcount,
      s_readdatavalid_o => s_readdatavalid,
      s_readdata_o      => s_readdata,
      m_waitrequest_i   => sp_waitrequest,
      m_write_o         => sp_write,
      m_read_o          => sp_read,
      m_address_o       => sp_address,
      m_writedata_o     => sp_writedata,
      m_byteenable_o    => sp_byteenable,
      m_burstcount_o    => sp_burstcount,
      m_readdatavalid_i => sp_readdatavalid,
      m_readdata_i      => sp_readdata
    ); -- avm_pause_inst : entity work.avm_pause


  ------------------------------------------
  -- Instantiate Avalon Slave
  ------------------------------------------

  avm_slave_sim_inst : entity work.avm_slave_sim
    generic map (
      G_BURST_WIDTH => G_BURST_WIDTH,
      G_DEBUG       => G_DEBUG,
      G_ADDR_SIZE   => G_MASTER_ADDR_SIZE,
      G_DATA_SIZE   => G_MASTER_DATA_SIZE
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
    ); -- avm_slave_sim_inst : entity work.avm_slave_sim

end architecture simulation;

