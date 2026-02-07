-- ---------------------------------------------------------------------------------------
-- Description: Generates a stream of random packets and verifies the response.
-- ---------------------------------------------------------------------------------------

library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std.all;

library work;
  use work.axip_pkg.all;

entity axip_sim is
  generic (
    G_SEED       : std_logic_vector(63 downto 0) := X"DEADBEAFC007BABE";
    G_NAME       : string                        := "";
    G_DEBUG      : boolean;
    G_RANDOM     : boolean;
    G_FAST       : boolean;
    G_MIN_LENGTH : natural;
    G_MAX_LENGTH : natural;
    G_CNT_SIZE   : natural
  );
  port (
    clk_i  : in    std_logic;
    rst_i  : in    std_logic;
    m_axip : view  axip_master_view;
    s_axip : view  axip_slave_view
  );
end entity axip_sim;

architecture simulation of axip_sim is

begin

  axip_master_sim_inst : entity work.axip_master_sim
    generic map (
      G_SEED       => G_SEED,
      G_NAME       => G_NAME,
      G_DEBUG      => G_DEBUG,
      G_RANDOM     => G_RANDOM,
      G_FAST       => G_FAST,
      G_MIN_LENGTH => G_MIN_LENGTH,
      G_MAX_LENGTH => G_MAX_LENGTH,
      G_CNT_SIZE   => G_CNT_SIZE
    )
    port map (
      clk_i  => clk_i,
      rst_i  => rst_i,
      m_axip => m_axip
    ); -- axip_master_sim_inst : entity work.axip_master_sim

  axip_slave_sim_inst : entity work.axip_slave_sim
    generic map (
      G_SEED       => G_SEED,
      G_NAME       => G_NAME,
      G_DEBUG      => G_DEBUG,
      G_RANDOM     => G_RANDOM,
      G_MIN_LENGTH => G_MIN_LENGTH,
      G_MAX_LENGTH => G_MAX_LENGTH,
      G_CNT_SIZE   => G_CNT_SIZE
    )
    port map (
      clk_i  => clk_i,
      rst_i  => rst_i,
      s_axip => s_axip
    ); -- axip_slave_sim_inst : entity work.axip_slave_sim

end architecture simulation;

