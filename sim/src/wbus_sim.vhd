-- ---------------------------------------------------------------------------------------
-- Description: This simulates a Wishbone Master and Slave.
-- ---------------------------------------------------------------------------------------

library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std.all;

library work;
  use work.wbus_pkg.all;

entity wbus_sim is
  generic (
    G_SEED        : std_logic_vector(63 downto 0);
    G_NAME        : string;
    G_TIMEOUT_MAX : natural;
    G_DEBUG       : boolean;
    G_DO_ABORT    : boolean;
    G_OFFSET      : natural;
    G_TIMEOUT     : boolean;
    G_FIRST       : std_logic := 'U';
    G_LATENCY     : natural
  );
  port (
    clk_i  : in    std_logic;
    rst_i  : in    std_logic;
    m_wbus : view  wbus_master_view;
    s_wbus : view  wbus_slave_view
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
      G_FIRST       => G_FIRST,
      G_OFFSET      => G_OFFSET
    )
    port map (
      clk_i  => clk_i,
      rst_i  => rst_i,
      m_wbus => m_wbus
    ); -- wbus_master_sim_inst : entity work.wbus_master_sim


  ------------------------------------------
  -- Instantiate Wishbone Slave
  ------------------------------------------

  wbus_slave_sim_inst : entity work.wbus_slave_sim
    generic map (
      G_FIRST => G_FIRST,
      G_DEBUG => G_DEBUG
    )
    port map (
      clk_i  => clk_i,
      rst_i  => rst_i,
      s_wbus => s_wbus
    ); -- wbus_slave_sim_inst : entity work.wbus_slave_sim

end architecture simulation;

