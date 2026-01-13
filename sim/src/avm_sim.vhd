-- ---------------------------------------------------------------------------------------
-- Description: This simulates a Avalon Master and Slave.
-- ---------------------------------------------------------------------------------------

library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std.all;

entity avm_sim is
  generic (
    G_DEBUG     : boolean;
    G_ADDR_SIZE : integer; -- Number of bits
    G_DATA_SIZE : integer  -- Number of bits
  );
  port (
    clk_i             : in    std_logic;
    rst_i             : in    std_logic;
    m_write_o         : out   std_logic;
    m_read_o          : out   std_logic;
    m_address_o       : out   std_logic_vector(G_ADDR_SIZE - 1 downto 0);
    m_writedata_o     : out   std_logic_vector(G_DATA_SIZE - 1 downto 0);
    m_byteenable_o    : out   std_logic_vector(G_DATA_SIZE / 8 - 1 downto 0);
    m_burstcount_o    : out   std_logic_vector(7 downto 0);
    m_readdata_i      : in    std_logic_vector(G_DATA_SIZE - 1 downto 0);
    m_readdatavalid_i : in    std_logic;
    m_waitrequest_i   : in    std_logic;
    s_write_i         : in    std_logic;
    s_read_i          : in    std_logic;
    s_address_i       : in    std_logic_vector(G_ADDR_SIZE - 1 downto 0);
    s_writedata_i     : in    std_logic_vector(G_DATA_SIZE - 1 downto 0);
    s_byteenable_i    : in    std_logic_vector(G_DATA_SIZE / 8 - 1 downto 0);
    s_burstcount_i    : in    std_logic_vector(7 downto 0);
    s_readdata_o      : out   std_logic_vector(G_DATA_SIZE - 1 downto 0);
    s_readdatavalid_o : out   std_logic;
    s_waitrequest_o   : out   std_logic
  );
end entity avm_sim;

architecture simulation of avm_sim is

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
      m_write_o         => m_write_o,
      m_read_o          => m_read_o,
      m_address_o       => m_address_o,
      m_writedata_o     => m_writedata_o,
      m_byteenable_o    => m_byteenable_o,
      m_burstcount_o    => m_burstcount_o,
      m_readdata_i      => m_readdata_i,
      m_readdatavalid_i => m_readdatavalid_i,
      m_waitrequest_i   => m_waitrequest_i
    );


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
      s_write_i         => s_write_i,
      s_read_i          => s_read_i,
      s_address_i       => s_address_i,
      s_writedata_i     => s_writedata_i,
      s_byteenable_i    => s_byteenable_i,
      s_burstcount_i    => s_burstcount_i,
      s_readdata_o      => s_readdata_o,
      s_readdatavalid_o => s_readdatavalid_o,
      s_waitrequest_o   => s_waitrequest_o
    ); -- avm_slave_sim_inst : entity work.avm_slave_sim

end architecture simulation;

