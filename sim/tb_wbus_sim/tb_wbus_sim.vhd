-- ---------------------------------------------------------------------------------------
-- Description: Verify wbus_sim
-- ---------------------------------------------------------------------------------------

library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std.all;

library work;
  use work.wbus_pkg.all;

entity tb_wbus_sim is
  generic (
    G_DEBUG       : boolean;
    G_TIMEOUT_MAX : natural;
    G_DO_ABORT    : boolean;
    G_PAUSE_SIZE  : integer;
    G_ADDR_SIZE   : natural;
    G_DATA_SIZE   : natural
  );
end entity tb_wbus_sim;

architecture simulation of tb_wbus_sim is

  signal clk : std_logic := '1';
  signal rst : std_logic := '1';

  signal m_wbus : wbus_rec_type (
    addr(G_ADDR_SIZE - 1 downto 0),
    wrdat(G_DATA_SIZE - 1 downto 0),
    rddat(G_DATA_SIZE - 1 downto 0)
  );

  signal s_wbus : wbus_rec_type (
    addr(G_ADDR_SIZE - 1 downto 0),
    wrdat(G_DATA_SIZE - 1 downto 0),
    rddat(G_DATA_SIZE - 1 downto 0)
  );

begin

  --------------------------------
  -- Clock and Reset
  --------------------------------

  clk <= not clk after 5 ns;
  rst <= '1', '0' after 100 ns;


  --------------------------------
  -- Instantiate DUT
  --------------------------------

  wbus_sim_inst : entity work.wbus_sim
    generic map (
      G_DEBUG       => G_DEBUG,
      G_TIMEOUT_MAX => G_TIMEOUT_MAX,
      G_DO_ABORT    => G_DO_ABORT,
      G_NAME        => "",
      G_SEED        => X"1234567887654321",
      G_LATENCY     => 3,
      G_TIMEOUT     => false,
      G_OFFSET      => 1234
    )
    port map (
      clk_i  => clk,
      rst_i  => rst,
      m_wbus => m_wbus,
      s_wbus => s_wbus
    ); -- wbus_master_sim_inst : entity work.wbus_master_sim

  wbus_pause_inst : entity work.wbus_pause
    generic map (
      G_SEED       => X"1122334455667788",
      G_PAUSE_SIZE => G_PAUSE_SIZE
    )
    port map (
      clk_i  => clk,
      rst_i  => rst,
      s_wbus => m_wbus,
      m_wbus => s_wbus
    ); -- wbus_pause_inst : entity work.wbus_pause

end architecture simulation;

