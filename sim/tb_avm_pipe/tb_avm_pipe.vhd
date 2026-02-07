-- ---------------------------------------------------------------------------------------
-- Description: Verify avm_pipe
-- ---------------------------------------------------------------------------------------

library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std.all;

library work;
  use work.avm_pkg.all;

entity tb_avm_pipe is
  generic (
    G_DEBUG       : boolean;
    G_TIMEOUT_MAX : natural;
    G_DO_ABORT    : boolean;
    G_PAUSE_SIZE  : integer;
    G_ADDR_SIZE   : natural;
    G_DATA_SIZE   : natural
  );
end entity tb_avm_pipe;

architecture simulation of tb_avm_pipe is

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

  avm_pipe_inst : entity work.avm_pipe
    port map (
      clk_i => clk,
      rst_i => rst,
      s_avm => m_avm,
      m_avm => s_avm
    ); -- avm_pipe_inst : entity work.avm_pipe


  --------------------------------
  -- Generate stimuli
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
    ); -- avm_sim_inst : entity work.avm_sim

end architecture simulation;

