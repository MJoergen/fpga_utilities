library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std.all;

library work;
  use work.avm_pkg.all;

entity tb_avm_arbit is
  generic (
    G_PREFER_SWAP : boolean;
    G_PAUSE_SIZE  : natural;
    G_ADDR_SIZE   : natural;
    G_DATA_SIZE   : natural
  );
end entity tb_avm_arbit;

architecture simulation of tb_avm_arbit is

  signal clk : std_logic := '1';
  signal rst : std_logic := '1';

  signal m0_avm : avm_rec_type (
                                address   (G_ADDR_SIZE - 1 downto 0),
                                writedata (G_DATA_SIZE - 1 downto 0),
                                byteenable(G_DATA_SIZE / 8 - 1 downto 0),
                                readdata  (G_DATA_SIZE - 1 downto 0)
                               );

  signal m1_avm : avm_rec_type (
                                address   (G_ADDR_SIZE - 1 downto 0),
                                writedata (G_DATA_SIZE - 1 downto 0),
                                byteenable(G_DATA_SIZE / 8 - 1 downto 0),
                                readdata  (G_DATA_SIZE - 1 downto 0)
                               );

  signal s_avm : avm_rec_type (
                               address   (G_ADDR_SIZE - 1 downto 0),
                               writedata (G_DATA_SIZE - 1 downto 0),
                               byteenable(G_DATA_SIZE / 8 - 1 downto 0),
                               readdata  (G_DATA_SIZE - 1 downto 0)
                              );

  signal pause_s_avm : avm_rec_type (
                                     address   (G_ADDR_SIZE - 1 downto 0),
                                     writedata (G_DATA_SIZE - 1 downto 0),
                                     byteenable(G_DATA_SIZE / 8 - 1 downto 0),
                                     readdata  (G_DATA_SIZE - 1 downto 0)
                                    );

begin

  --------------------------------
  -- Clock and Reset
  --------------------------------

  clk <= not clk after 5 ns;
  rst <= '1', '0' after 100 ns;


  ---------------------------------------------------------
  -- Instantiate Master 0
  ---------------------------------------------------------

  avm_master_sim_0_inst : entity work.avm_master_sim
    port map (
      clk_i => clk,
      rst_i => rst,
      m_avm => m0_avm
    ); -- avm_master_sim_0_inst : entity work.avm_master_sim


  ---------------------------------------------------------
  -- Instantiate Master 1
  ---------------------------------------------------------

  avm_master_sim_1_inst : entity work.avm_master_sim
    port map (
      clk_i => clk,
      rst_i => rst,
      m_avm => m1_avm
    ); -- avm_master_sim_1_inst : entity work.avm_master_sim


  ---------------------------------------------------------
  -- DUT
  ---------------------------------------------------------

  avm_arbit_inst : entity work.avm_arbit
    generic map (
      G_PREFER_SWAP => G_PREFER_SWAP
    )
    port map (
      clk_i  => clk,
      rst_i  => rst,
      s0_avm => m0_avm,
      s1_avm => m1_avm,
      m_avm  => s_avm
    ); -- avm_arbit_inst : entity work.avm_arbit


  ---------------------------------------------------------
  -- Instantiate pause before Slave
  ---------------------------------------------------------

  avm_pause_inst : entity work.avm_pause
    generic map (
      G_PAUSE_SIZE => G_PAUSE_SIZE
    )
    port map (
      clk_i => clk,
      rst_i => rst,
      s_avm => s_avm,
      m_avm => pause_s_avm
    ); -- avm_pause_inst : entity work.avm_pause


  ---------------------------------------------------------
  -- Instantiate Slave
  ---------------------------------------------------------

  avm_slave_sim_inst : entity work.avm_slave_sim
    port map (
      clk_i => clk,
      rst_i => rst,
      s_avm => pause_s_avm
    ); -- avm_slave_sim_inst : entity work.avm_slave_sim

end architecture simulation;

