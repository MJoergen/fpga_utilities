-- ---------------------------------------------------------------------------------------
-- Description: Verify avm_sim
-- ---------------------------------------------------------------------------------------

library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std.all;

library work;
  use work.avm_pkg.all;

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

  signal m_avm : avm_rec_type (
                               address       (G_ADDR_SIZE - 1 downto 0),
                               writedata     (G_DATA_SIZE - 1 downto 0),
                               byteenable    (G_DATA_SIZE / 8 - 1 downto 0),
                               readdata      (G_DATA_SIZE - 1 downto 0)
                              );

  signal s_avm : avm_rec_type (
                               address       (G_ADDR_SIZE - 1 downto 0),
                               writedata     (G_DATA_SIZE - 1 downto 0),
                               byteenable    (G_DATA_SIZE / 8 - 1 downto 0),
                               readdata      (G_DATA_SIZE - 1 downto 0)
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

  avm_sim_inst : entity work.avm_sim
    generic map (
      G_DEBUG      => G_DEBUG,
      G_PAUSE_SIZE => 0
    )
    port map (
      clk_i => clk,
      rst_i => rst,
      m_avm => m_avm,
      s_avm => s_avm
    ); -- avm_master_sim_inst : entity work.avm_master_sim

  avm_pause_inst : entity work.avm_pause
    generic map (
      G_SEED       => X"12345678AABBCCDD",
      G_PAUSE_SIZE => G_PAUSE_SIZE
    )
    port map (
      clk_i => clk,
      rst_i => rst,
      s_avm => m_avm,
      m_avm => s_avm
    ); -- avm_pause_inst : entity work.avm_pause

end architecture simulation;

