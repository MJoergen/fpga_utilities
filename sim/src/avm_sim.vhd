-- ---------------------------------------------------------------------------------------
-- Description: This simulates a Avalon Master and Slave.
-- ---------------------------------------------------------------------------------------

library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std.all;

entity avm_sim is
  generic (
    G_DEBUG      : boolean;
    G_PAUSE_SIZE : integer;
    G_ADDR_SIZE  : integer; -- Number of bits
    G_DATA_SIZE  : integer  -- Number of bits
  );
  port (
    clk_i             : in    std_logic;
    rst_i             : in    std_logic;
    -- Input
    m_waitrequest_i   : in    std_logic;
    m_write_o         : out   std_logic;
    m_read_o          : out   std_logic;
    m_address_o       : out   std_logic_vector(G_ADDR_SIZE - 1 downto 0);
    m_writedata_o     : out   std_logic_vector(G_DATA_SIZE - 1 downto 0);
    m_byteenable_o    : out   std_logic_vector(G_DATA_SIZE / 8 - 1 downto 0);
    m_burstcount_o    : out   std_logic_vector(7 downto 0);
    m_readdatavalid_i : in    std_logic;
    m_readdata_i      : in    std_logic_vector(G_DATA_SIZE - 1 downto 0);
    -- Output
    s_waitrequest_o   : out   std_logic;
    s_write_i         : in    std_logic;
    s_read_i          : in    std_logic;
    s_address_i       : in    std_logic_vector(G_ADDR_SIZE - 1 downto 0);
    s_writedata_i     : in    std_logic_vector(G_DATA_SIZE - 1 downto 0);
    s_byteenable_i    : in    std_logic_vector(G_DATA_SIZE / 8 - 1 downto 0);
    s_burstcount_i    : in    std_logic_vector(7 downto 0);
    s_readdatavalid_o : out   std_logic;
    s_readdata_o      : out   std_logic_vector(G_DATA_SIZE - 1 downto 0)
  );
end entity avm_sim;

architecture simulation of avm_sim is

  signal pause_m_waitrequest   : std_logic;
  signal pause_m_write         : std_logic;
  signal pause_m_read          : std_logic;
  signal pause_m_address       : std_logic_vector(G_ADDR_SIZE - 1 downto 0);
  signal pause_m_writedata     : std_logic_vector(G_DATA_SIZE - 1 downto 0);
  signal pause_m_byteenable    : std_logic_vector(G_DATA_SIZE / 8 - 1 downto 0);
  signal pause_m_burstcount    : std_logic_vector(7 downto 0);
  signal pause_m_readdatavalid : std_logic;
  signal pause_m_readdata      : std_logic_vector(G_DATA_SIZE - 1 downto 0);

  signal pause_s_waitrequest   : std_logic;
  signal pause_s_write         : std_logic;
  signal pause_s_read          : std_logic;
  signal pause_s_address       : std_logic_vector(G_ADDR_SIZE - 1 downto 0);
  signal pause_s_writedata     : std_logic_vector(G_DATA_SIZE - 1 downto 0);
  signal pause_s_byteenable    : std_logic_vector(G_DATA_SIZE / 8 - 1 downto 0);
  signal pause_s_burstcount    : std_logic_vector(7 downto 0);
  signal pause_s_readdatavalid : std_logic;
  signal pause_s_readdata      : std_logic_vector(G_DATA_SIZE - 1 downto 0);

begin

  ------------------------------------------
  -- Instantiate Avalon Master
  ------------------------------------------

  avm_master_sim_inst : entity work.avm_master_sim
    generic map (
      G_SEED        => X"DEADBEEFC007BABE",
      G_NAME        => "",
      G_TIMEOUT_MAX => 200,
      G_DEBUG       => G_DEBUG,
      G_OFFSET      => 1234,
      G_ADDR_SIZE   => G_ADDR_SIZE,
      G_DATA_SIZE   => G_DATA_SIZE
    )
    port map (
      clk_i             => clk_i,
      rst_i             => rst_i,
      m_waitrequest_i   => pause_m_waitrequest,
      m_write_o         => pause_m_write,
      m_read_o          => pause_m_read,
      m_address_o       => pause_m_address,
      m_writedata_o     => pause_m_writedata,
      m_byteenable_o    => pause_m_byteenable,
      m_burstcount_o    => pause_m_burstcount,
      m_readdatavalid_i => pause_m_readdatavalid,
      m_readdata_i      => pause_m_readdata
    ); -- avm_master_sim_inst : entity work.avm_master_sim


  ------------------------------------------
  -- Inserts pauses after Avalon Master
  ------------------------------------------

  avm_pause_m_inst : entity work.avm_pause
    generic map (
      G_SEED       => X"1234567888776655",
      G_PAUSE_SIZE => G_PAUSE_SIZE,
      G_ADDR_SIZE  => G_ADDR_SIZE,
      G_DATA_SIZE  => G_DATA_SIZE
    )
    port map (
      clk_i             => clk_i,
      rst_i             => rst_i,
      s_waitrequest_o   => pause_m_waitrequest,
      s_write_i         => pause_m_write,
      s_read_i          => pause_m_read,
      s_address_i       => pause_m_address,
      s_writedata_i     => pause_m_writedata,
      s_byteenable_i    => pause_m_byteenable,
      s_burstcount_i    => pause_m_burstcount,
      s_readdatavalid_o => pause_m_readdatavalid,
      s_readdata_o      => pause_m_readdata,
      m_waitrequest_i   => m_waitrequest_i,
      m_write_o         => m_write_o,
      m_read_o          => m_read_o,
      m_address_o       => m_address_o,
      m_writedata_o     => m_writedata_o,
      m_byteenable_o    => m_byteenable_o,
      m_burstcount_o    => m_burstcount_o,
      m_readdatavalid_i => m_readdatavalid_i,
      m_readdata_i      => m_readdata_i
    ); -- avm_pause_m_inst : entity work.avm_pause


  ------------------------------------------
  -- Inserts pauses before Avalon Slave
  ------------------------------------------

  avm_pause_s_inst : entity work.avm_pause
    generic map (
      G_SEED       => X"4433221187654321",
      G_PAUSE_SIZE => G_PAUSE_SIZE,
      G_ADDR_SIZE  => G_ADDR_SIZE,
      G_DATA_SIZE  => G_DATA_SIZE
    )
    port map (
      clk_i             => clk_i,
      rst_i             => rst_i,
      s_waitrequest_o   => s_waitrequest_o,
      s_write_i         => s_write_i,
      s_read_i          => s_read_i,
      s_address_i       => s_address_i,
      s_writedata_i     => s_writedata_i,
      s_byteenable_i    => s_byteenable_i,
      s_burstcount_i    => s_burstcount_i,
      s_readdatavalid_o => s_readdatavalid_o,
      s_readdata_o      => s_readdata_o,
      m_waitrequest_i   => pause_s_waitrequest,
      m_write_o         => pause_s_write,
      m_read_o          => pause_s_read,
      m_address_o       => pause_s_address,
      m_writedata_o     => pause_s_writedata,
      m_byteenable_o    => pause_s_byteenable,
      m_burstcount_o    => pause_s_burstcount,
      m_readdatavalid_i => pause_s_readdatavalid,
      m_readdata_i      => pause_s_readdata
    ); -- avm_pause_s_inst : entity work.avm_pause


  ------------------------------------------
  -- Instantiate Avalon Slave
  ------------------------------------------

  avm_slave_sim_inst : entity work.avm_slave_sim
    generic map (
      G_DEBUG     => G_DEBUG,
      G_ADDR_SIZE => G_ADDR_SIZE,
      G_DATA_SIZE => G_DATA_SIZE
    )
    port map (
      clk_i             => clk_i,
      rst_i             => rst_i,
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

