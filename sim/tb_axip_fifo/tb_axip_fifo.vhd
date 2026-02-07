-- ---------------------------------------------------------------------------------------
-- Description: Verify axip_fifo
-- ---------------------------------------------------------------------------------------

library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std.all;

library work;
  use work.axip_pkg.all;

entity tb_axip_fifo is
  generic (
    G_RAM_DEPTH  : natural;
    G_DEBUG      : boolean;
    G_RANDOM     : boolean;
    G_FAST       : boolean;
    G_MIN_LENGTH : natural;
    G_MAX_LENGTH : natural;
    G_CNT_SIZE   : natural;
    G_DATA_BYTES : natural
  );
end entity tb_axip_fifo;

architecture simulation of tb_axip_fifo is

  signal clk : std_logic := '1';
  signal rst : std_logic := '1';

  signal s_axip : axip_rec_type (
    data(G_DATA_BYTES * 8 - 1 downto 0)
  );

  signal m_axip : axip_rec_type (
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

  axip_fifo_inst : entity work.axip_fifo
    generic map (
      G_RAM_STYLE => "auto",
      G_RAM_DEPTH => G_RAM_DEPTH
    )
    port map (
      clk_i  => clk,
      rst_i  => rst,
      s_axip => s_axip,
      m_axip => m_axip
    ); -- axip_fifo_inst : entity work.axip_fifo


  ----------------------------------------------
  -- Generate stimulus and verify response
  ----------------------------------------------

  axip_sim_inst : entity work.axip_sim
    generic map (
      G_DEBUG      => G_DEBUG,
      G_RANDOM     => G_RANDOM,
      G_FAST       => G_FAST,
      G_MIN_LENGTH => G_MIN_LENGTH,
      G_MAX_LENGTH => G_MAX_LENGTH,
      G_CNT_SIZE   => G_CNT_SIZE
    )
    port map (
      clk_i  => clk,
      rst_i  => rst,
      m_axip => s_axip,
      s_axip => m_axip
    ); -- axip_sim_inst : entity work.axip_sim

end architecture simulation;

