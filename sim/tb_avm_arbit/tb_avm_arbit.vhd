library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std.all;

entity tb_avm_arbit is
  generic (
    G_PREFER_SWAP : boolean;
    G_PAUSE_SIZE  : natural;
    G_ADDR_SIZE   : natural;
    G_DATA_SIZE   : natural
  );
end entity tb_avm_arbit;

architecture simulation of tb_avm_arbit is

  signal clk : std_logic := '1';
  signal rst : std_logic := '1';

  signal m0_waitrequest   : std_logic;
  signal m0_write         : std_logic;
  signal m0_read          : std_logic;
  signal m0_address       : std_logic_vector(G_ADDR_SIZE - 1 downto 0);
  signal m0_writedata     : std_logic_vector(G_DATA_SIZE - 1 downto 0);
  signal m0_byteenable    : std_logic_vector(G_DATA_SIZE / 8 - 1 downto 0);
  signal m0_burstcount    : std_logic_vector(7 downto 0);
  signal m0_readdatavalid : std_logic;
  signal m0_readdata      : std_logic_vector(G_DATA_SIZE - 1 downto 0);

  signal m1_waitrequest   : std_logic;
  signal m1_write         : std_logic;
  signal m1_read          : std_logic;
  signal m1_address       : std_logic_vector(G_ADDR_SIZE - 1 downto 0);
  signal m1_writedata     : std_logic_vector(G_DATA_SIZE - 1 downto 0);
  signal m1_byteenable    : std_logic_vector(G_DATA_SIZE / 8 - 1 downto 0);
  signal m1_burstcount    : std_logic_vector(7 downto 0);
  signal m1_readdatavalid : std_logic;
  signal m1_readdata      : std_logic_vector(G_DATA_SIZE - 1 downto 0);

  signal s_waitrequest   : std_logic;
  signal s_write         : std_logic;
  signal s_read          : std_logic;
  signal s_address       : std_logic_vector(G_ADDR_SIZE downto 0);
  signal s_writedata     : std_logic_vector(G_DATA_SIZE - 1 downto 0);
  signal s_byteenable    : std_logic_vector(G_DATA_SIZE / 8 - 1 downto 0);
  signal s_burstcount    : std_logic_vector(7 downto 0);
  signal s_readdatavalid : std_logic;
  signal s_readdata      : std_logic_vector(G_DATA_SIZE - 1 downto 0);

  signal pause_s_waitrequest   : std_logic;
  signal pause_s_write         : std_logic;
  signal pause_s_read          : std_logic;
  signal pause_s_address       : std_logic_vector(G_ADDR_SIZE downto 0);
  signal pause_s_writedata     : std_logic_vector(G_DATA_SIZE - 1 downto 0);
  signal pause_s_byteenable    : std_logic_vector(G_DATA_SIZE / 8 - 1 downto 0);
  signal pause_s_burstcount    : std_logic_vector(7 downto 0);
  signal pause_s_readdatavalid : std_logic;
  signal pause_s_readdata      : std_logic_vector(G_DATA_SIZE - 1 downto 0);

begin

  --------------------------------
  -- Clock and Reset
  --------------------------------

  clk <= not clk after 5 ns;
  rst <= '1', '0' after 100 ns;


  ---------------------------------------------------------
  -- Instantiate Master 0
  ---------------------------------------------------------

  avm_master_sim_0_inst : entity work.avm_master_sim
    generic map (
      G_ADDR_SIZE => G_ADDR_SIZE,
      G_DATA_SIZE => G_DATA_SIZE
    )
    port map (
      clk_i             => clk,
      rst_i             => rst,
      m_write_o         => m0_write,
      m_read_o          => m0_read,
      m_address_o       => m0_address,
      m_writedata_o     => m0_writedata,
      m_byteenable_o    => m0_byteenable,
      m_burstcount_o    => m0_burstcount,
      m_readdata_i      => m0_readdata,
      m_readdatavalid_i => m0_readdatavalid,
      m_waitrequest_i   => m0_waitrequest
    ); -- avm_master_sim_0_inst : entity work.avm_master_sim


  ---------------------------------------------------------
  -- Instantiate Master 1
  ---------------------------------------------------------

  avm_master_sim_1_inst : entity work.avm_master_sim
    generic map (
      G_ADDR_SIZE => G_ADDR_SIZE,
      G_DATA_SIZE => G_DATA_SIZE
    )
    port map (
      clk_i             => clk,
      rst_i             => rst,
      m_write_o         => m1_write,
      m_read_o          => m1_read,
      m_address_o       => m1_address,
      m_writedata_o     => m1_writedata,
      m_byteenable_o    => m1_byteenable,
      m_burstcount_o    => m1_burstcount,
      m_readdata_i      => m1_readdata,
      m_readdatavalid_i => m1_readdatavalid,
      m_waitrequest_i   => m1_waitrequest
    ); -- avm_master_sim_1_inst : entity work.avm_master_sim


  ---------------------------------------------------------
  -- DUT
  ---------------------------------------------------------

  avm_arbit_inst : entity work.avm_arbit
    generic map (
      G_PREFER_SWAP => G_PREFER_SWAP,
      G_ADDR_SIZE   => G_ADDR_SIZE + 1,
      G_DATA_SIZE   => G_DATA_SIZE
    )
    port map (
      clk_i              => clk,
      rst_i              => rst,
      s0_waitrequest_o   => m0_waitrequest,
      s0_write_i         => m0_write,
      s0_read_i          => m0_read,
      s0_address_i       => "0" & m0_address,
      s0_writedata_i     => m0_writedata,
      s0_byteenable_i    => m0_byteenable,
      s0_burstcount_i    => m0_burstcount,
      s0_readdatavalid_o => m0_readdatavalid,
      s0_readdata_o      => m0_readdata,
      s1_waitrequest_o   => m1_waitrequest,
      s1_write_i         => m1_write,
      s1_read_i          => m1_read,
      s1_address_i       => "1" & m1_address,
      s1_writedata_i     => m1_writedata,
      s1_byteenable_i    => m1_byteenable,
      s1_burstcount_i    => m1_burstcount,
      s1_readdatavalid_o => m1_readdatavalid,
      s1_readdata_o      => m1_readdata,
      m_waitrequest_i    => s_waitrequest,
      m_write_o          => s_write,
      m_read_o           => s_read,
      m_address_o        => s_address,
      m_writedata_o      => s_writedata,
      m_byteenable_o     => s_byteenable,
      m_burstcount_o     => s_burstcount,
      m_readdatavalid_i  => s_readdatavalid,
      m_readdata_i       => s_readdata
    ); -- avm_arbit_inst : entity work.avm_arbit


  ---------------------------------------------------------
  -- Instantiate pause before Slave
  ---------------------------------------------------------

  avm_pause_inst : entity work.avm_pause
    generic map (
      G_PAUSE_SIZE => G_PAUSE_SIZE,
      G_ADDR_SIZE  => G_ADDR_SIZE + 1,
      G_DATA_SIZE  => G_DATA_SIZE
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
      m_waitrequest_i   => pause_s_waitrequest,
      m_write_o         => pause_s_write,
      m_read_o          => pause_s_read,
      m_address_o       => pause_s_address,
      m_writedata_o     => pause_s_writedata,
      m_byteenable_o    => pause_s_byteenable,
      m_burstcount_o    => pause_s_burstcount,
      m_readdatavalid_i => pause_s_readdatavalid,
      m_readdata_i      => pause_s_readdata
    ); -- avm_pause_inst : entity work.avm_pause


  ---------------------------------------------------------
  -- Instantiate Slave
  ---------------------------------------------------------

  avm_slave_sim_inst : entity work.avm_slave_sim
    generic map (
      G_ADDR_SIZE  => G_ADDR_SIZE + 1,
      G_DATA_SIZE  => G_DATA_SIZE
    )
    port map (
      clk_i             => clk,
      rst_i             => rst,
      s_waitrequest_o   => pause_s_waitrequest,
      s_write_i         => pause_s_write,
      s_read_i          => pause_s_read,
      s_address_i       => pause_s_address,
      s_writedata_i     => pause_s_writedata,
      s_byteenable_i    => pause_s_byteenable,
      s_burstcount_i    => pause_s_burstcount,
      s_readdatavalid_o => pause_s_readdatavalid,
      s_readdata_o      => pause_s_readdata
    ); -- avm_slave_sim_inst : entity work.avm_slave_sim

end architecture simulation;

