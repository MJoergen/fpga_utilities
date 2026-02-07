-- ---------------------------------------------------------------------------------------
-- Description: Verify axil_sim
-- ---------------------------------------------------------------------------------------

library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std.all;

library work;
  use work.axil_pkg.all;

entity tb_axil_sim is
  generic (
    G_DEBUG      : boolean;
    G_PAUSE_SIZE : natural;
    G_RANDOM     : boolean;
    G_FAST       : boolean;
    G_ADDR_SIZE  : natural;
    G_DATA_SIZE  : natural
  );
end entity tb_axil_sim;

architecture simulation of tb_axil_sim is

  signal clk : std_logic := '1';
  signal rst : std_logic := '1';

  signal s_axil : axil_rec_type (
    awaddr(G_ADDR_SIZE - 1 downto 0),
    wdata(G_DATA_SIZE - 1 downto 0),
    wstrb(G_DATA_SIZE/8 - 1 downto 0),
    araddr(G_ADDR_SIZE - 1 downto 0),
    rdata(G_DATA_SIZE - 1 downto 0)
  );

  signal m_axil : axil_rec_type (
    awaddr(G_ADDR_SIZE - 1 downto 0),
    wdata(G_DATA_SIZE - 1 downto 0),
    wstrb(G_DATA_SIZE/8 - 1 downto 0),
    araddr(G_ADDR_SIZE - 1 downto 0),
    rdata(G_DATA_SIZE - 1 downto 0)
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

  axil_sim_inst : entity work.axil_sim
    generic map (
      G_SEED   => X"1234567887654321",
      G_OFFSET => 1234,
      G_DEBUG  => G_DEBUG,
      G_RANDOM => G_RANDOM,
      G_FAST   => G_FAST
    )
    port map (
      clk_i  => clk,
      rst_i  => rst,
      m_axil => m_axil,
      s_axil => s_axil
    ); -- axil_sim_inst : entity work.axil_sim


  ----------------------------------------------
  -- Add additional random delays
  ----------------------------------------------

  axil_pause_inst : entity work.axil_pause
    generic map (
      G_SEED       => X"ABCDEFABCDEFABCD",
      G_PAUSE_SIZE => G_PAUSE_SIZE
    )
    port map (
      clk_i  => clk,
      rst_i  => rst,
      s_axil => m_axil,
      m_axil => s_axil
    ); -- axil_pause_inst : entity work.axil_pause

end architecture simulation;

