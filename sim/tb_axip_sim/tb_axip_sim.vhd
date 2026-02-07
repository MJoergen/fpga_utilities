-- ---------------------------------------------------------------------------------------
-- Description: Verify axip_sim
-- ---------------------------------------------------------------------------------------

library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std.all;

library work;
  use work.axip_pkg.all;

entity tb_axip_sim is
  generic (
    G_PAUSE_SIZE : natural;
    G_RAM_DEPTH  : natural;
    G_RANDOM     : boolean;
    G_FAST       : boolean;
    G_CNT_SIZE   : natural;
    G_DATA_BYTES : natural
  );
end entity tb_axip_sim;

architecture simulation of tb_axip_sim is

  signal clk : std_logic := '1';
  signal rst : std_logic := '1';

  -- Input to axip_sim
  signal tx_axip : axip_rec_type (
                                  data(G_DATA_BYTES * 8 - 1 downto 0)
                                 );

  -- Output from axip_sim
  signal rx_axip : axip_rec_type (
                                  data(G_DATA_BYTES * 8 - 1 downto 0)
                                 );

begin

  ----------------------------------------------
  -- Clock and Reset
  ----------------------------------------------

  clk <= not clk after 5 ns;
  rst <= '1', '0' after 100 ns;


  ----------------------------------------------
  -- Instantiate DUT
  ----------------------------------------------

  axip_sim_inst : entity work.axip_sim
    generic map (
      G_DEBUG      => false,
      G_MIN_LENGTH => 1,
      G_MAX_LENGTH => 10,
      G_RANDOM     => G_RANDOM,
      G_FAST       => G_FAST,
      G_CNT_SIZE   => G_CNT_SIZE
    )
    port map (
      clk_i  => clk,
      rst_i  => rst,
      m_axip => tx_axip,
      s_axip => rx_axip
    ); -- axip_sim_inst : entity work.axip_sim


  ----------------------------------------------
  -- Add additional random delays
  ----------------------------------------------

  axip_pause_inst : entity work.axip_pause
    generic map (
      G_SEED       => X"CAFEBABE666B00B5",
      G_PAUSE_SIZE => G_PAUSE_SIZE
    )
    port map (
      clk_i  => clk,
      rst_i  => rst,
      s_axip => tx_axip,
      m_axip => rx_axip
    ); -- axip_pause_inst : entity work.axip_pause

end architecture simulation;

