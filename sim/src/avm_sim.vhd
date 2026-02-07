-- ---------------------------------------------------------------------------------------
-- Description: This simulates a Avalon Master and Slave.
-- ---------------------------------------------------------------------------------------

library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std.all;

library work;
  use work.avm_pkg.all;

entity avm_sim is
  generic (
    G_DEBUG      : boolean;
    G_PAUSE_SIZE : integer
  );
  port (
    clk_i : in    std_logic;
    rst_i : in    std_logic;
    m_avm : view avm_master_view;
    s_avm : view avm_slave_view
  );
end entity avm_sim;

architecture simulation of avm_sim is

  constant C_ADDR_SIZE : positive := m_avm.address'length;
  constant C_DATA_SIZE : positive := m_avm.writedata'length;

  signal pause_m_avm : avm_rec_type (
                                     address       (C_ADDR_SIZE - 1 downto 0),
                                     writedata     (C_DATA_SIZE - 1 downto 0),
                                     byteenable    (C_DATA_SIZE / 8 - 1 downto 0),
                                     readdata      (C_DATA_SIZE - 1 downto 0)
                                    );

  signal pause_s_avm : avm_rec_type (
                                     address       (C_ADDR_SIZE - 1 downto 0),
                                     writedata     (C_DATA_SIZE - 1 downto 0),
                                     byteenable    (C_DATA_SIZE / 8 - 1 downto 0),
                                     readdata      (C_DATA_SIZE - 1 downto 0)
                                    );

begin

  ------------------------------------------
  -- Instantiate Avalon Master
  ------------------------------------------

  avm_master_sim_inst : entity work.avm_master_sim
    generic map (
      G_SEED        => X"DEADBEEFC007BABE",
      G_NAME        => "",
      G_TIMEOUT_MAX => 200,
      G_DEBUG       => G_DEBUG,
      G_OFFSET      => 1234
    )
    port map (
      clk_i => clk_i,
      rst_i => rst_i,
      m_avm => pause_m_avm
    ); -- avm_master_sim_inst : entity work.avm_master_sim


  ------------------------------------------
  -- Inserts pauses after Avalon Master
  ------------------------------------------

  avm_pause_m_inst : entity work.avm_pause
    generic map (
      G_SEED       => X"1234567888776655",
      G_PAUSE_SIZE => G_PAUSE_SIZE
    )
    port map (
      clk_i => clk_i,
      rst_i => rst_i,
      s_avm => pause_m_avm,
      m_avm => m_avm
    ); -- avm_pause_m_inst : entity work.avm_pause


  ------------------------------------------
  -- Inserts pauses before Avalon Slave
  ------------------------------------------

  avm_pause_s_inst : entity work.avm_pause
    generic map (
      G_SEED       => X"4433221187654321",
      G_PAUSE_SIZE => G_PAUSE_SIZE
    )
    port map (
      clk_i => clk_i,
      rst_i => rst_i,
      s_avm => s_avm,
      m_avm => pause_s_avm
    ); -- avm_pause_s_inst : entity work.avm_pause


  ------------------------------------------
  -- Instantiate Avalon Slave
  ------------------------------------------

  avm_slave_sim_inst : entity work.avm_slave_sim
    generic map (
      G_DEBUG => G_DEBUG
    )
    port map (
      clk_i => clk_i,
      rst_i => rst_i,
      s_avm => pause_s_avm
    ); -- avm_slave_sim_inst : entity work.avm_slave_sim

end architecture simulation;

