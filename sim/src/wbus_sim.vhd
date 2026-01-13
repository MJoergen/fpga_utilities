-- ---------------------------------------------------------------------------------------
-- Description: This simulates a Wishbone Master and Slave.
-- ---------------------------------------------------------------------------------------

library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std.all;

entity wbus_sim is
  generic (
    G_SEED        : std_logic_vector(63 downto 0);
    G_NAME        : string;
    G_TIMEOUT_MAX : natural;
    G_DEBUG       : boolean;
    G_DO_ABORT    : boolean;
    G_OFFSET      : natural;
    G_TIMEOUT     : boolean;
    G_LATENCY     : natural;
    G_ADDR_SIZE   : natural;
    G_DATA_SIZE   : natural
  );
  port (
    clk_i     : in    std_logic;
    rst_i     : in    std_logic;
    m_cyc_o   : out   std_logic;
    m_stall_i : in    std_logic;
    m_stb_o   : out   std_logic;
    m_addr_o  : out   std_logic_vector(G_ADDR_SIZE - 1 downto 0);
    m_we_o    : out   std_logic;
    m_wrdat_o : out   std_logic_vector(G_DATA_SIZE - 1 downto 0);
    m_ack_i   : in    std_logic;
    m_rddat_i : in    std_logic_vector(G_DATA_SIZE - 1 downto 0);
    s_cyc_i   : in    std_logic;
    s_stall_o : out   std_logic;
    s_stb_i   : in    std_logic;
    s_addr_i  : in    std_logic_vector(G_ADDR_SIZE - 1 downto 0);
    s_we_i    : in    std_logic;
    s_wrdat_i : in    std_logic_vector(G_DATA_SIZE - 1 downto 0);
    s_ack_o   : out   std_logic;
    s_rddat_o : out   std_logic_vector(G_DATA_SIZE - 1 downto 0)
  );
end entity wbus_sim;

architecture simulation of wbus_sim is

begin

  ------------------------------------------
  -- Instantiate Wishbone Master
  ------------------------------------------

  wbus_master_sim_inst : entity work.wbus_master_sim
    generic map (
      G_SEED        => G_SEED,
      G_NAME        => G_NAME,
      G_TIMEOUT_MAX => G_TIMEOUT_MAX,
      G_DEBUG       => G_DEBUG,
      G_DO_ABORT    => G_DO_ABORT,
      G_OFFSET      => G_OFFSET,
      G_ADDR_SIZE   => G_ADDR_SIZE,
      G_DATA_SIZE   => G_DATA_SIZE
    )
    port map (
      clk_i     => clk_i,
      rst_i     => rst_i,
      m_cyc_o   => m_cyc_o,
      m_stall_i => m_stall_i,
      m_stb_o   => m_stb_o,
      m_addr_o  => m_addr_o,
      m_we_o    => m_we_o,
      m_wrdat_o => m_wrdat_o,
      m_ack_i   => m_ack_i,
      m_rddat_i => m_rddat_i
    ); -- wbus_master_sim_inst : entity work.wbus_master_sim


  ------------------------------------------
  -- Instantiate Wishbone Slave
  ------------------------------------------

  wbus_slave_sim_inst : entity work.wbus_slave_sim
    generic map (
      G_DEBUG     => G_DEBUG,
      G_ADDR_SIZE => G_ADDR_SIZE,
      G_DATA_SIZE => G_DATA_SIZE
    )
    port map (
      clk_i     => clk_i,
      rst_i     => rst_i,
      s_cyc_i   => s_cyc_i,
      s_stall_o => s_stall_o,
      s_stb_i   => s_stb_i,
      s_addr_i  => s_addr_i,
      s_we_i    => s_we_i,
      s_wrdat_i => s_wrdat_i,
      s_ack_o   => s_ack_o,
      s_rddat_o => s_rddat_o
    ); -- wbus_slave_sim_inst : entity work.wbus_slave_sim

end architecture simulation;

