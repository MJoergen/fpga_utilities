-- ---------------------------------------------------------------------------------------
-- Description: Verify wbus_arbiter
-- ---------------------------------------------------------------------------------------

library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std.all;

library work;
  use work.wbus_pkg.all;

entity tb_wbus_arbiter is
  generic (
    G_DEBUG     : boolean;
    G_DO_ABORT  : boolean;
    G_LATENCY   : natural;
    G_ADDR_SIZE : natural;
    G_DATA_SIZE : natural
  );
end entity tb_wbus_arbiter;

architecture simulation of tb_wbus_arbiter is

  signal clk : std_logic := '1';
  signal rst : std_logic := '1';

  signal s0_wbus : wbus_rec_type (
                                  addr(G_ADDR_SIZE downto 0),
                                  wrdat(G_DATA_SIZE - 1 downto 0),
                                  rddat(G_DATA_SIZE - 1 downto 0)
                                 );

  signal s1_wbus : wbus_rec_type (
                                  addr(G_ADDR_SIZE downto 0),
                                  wrdat(G_DATA_SIZE - 1 downto 0),
                                  rddat(G_DATA_SIZE - 1 downto 0)
                                 );

  signal m_wbus : wbus_rec_type (
                                 addr(G_ADDR_SIZE downto 0),
                                 wrdat(G_DATA_SIZE - 1 downto 0),
                                 rddat(G_DATA_SIZE - 1 downto 0)
                                );

  signal map_wbus : wbus_map_rec_type (
                                       rst(1 downto 0),
                                       stall(1 downto 0),
                                       stb(1 downto 0),
                                       addr(G_ADDR_SIZE - 1 downto 0),
                                       wrdat(G_DATA_SIZE - 1 downto 0),
                                       ack(1 downto 0),
                                       rddat(1 downto 0)(G_DATA_SIZE - 1 downto 0)
                                      );

  signal m0_wbus : wbus_rec_type (
                                  addr(G_ADDR_SIZE downto 0),
                                  wrdat(G_DATA_SIZE - 1 downto 0),
                                  rddat(G_DATA_SIZE - 1 downto 0)
                                 );

  signal m1_wbus : wbus_rec_type (
                                  addr(G_ADDR_SIZE downto 0),
                                  wrdat(G_DATA_SIZE - 1 downto 0),
                                  rddat(G_DATA_SIZE - 1 downto 0)
                                 );

  signal m0_rst : std_logic;
  signal m1_rst : std_logic;

begin

  --------------------------------
  -- Clock and Reset
  --------------------------------

  clk               <= not clk after 5 ns;
  rst               <= '1', '0' after 100 ns;


  --------------------------------
  -- Instantiate DUT
  --------------------------------

  wbus_arbiter_inst : entity work.wbus_arbiter
    port map (
      clk_i   => clk,
      rst_i   => rst,
      s0_wbus => s0_wbus,
      s1_wbus => s1_wbus,
      m_wbus  => m_wbus
    ); -- wbus_arbiter_inst : entity work.wbus_arbiter


  --------------------------------
  -- Instantiate Stimuli
  --------------------------------

  wbus_mapper_inst : entity work.wbus_mapper
    port map (
      clk_i  => clk,
      rst_i  => rst,
      s_wbus => m_wbus,
      m_wbus => map_wbus
    ); -- wbus_mapper_inst : entity work.wbus_mapper


  m0_rst            <= map_wbus.rst(0);
  m0_wbus.cyc       <= map_wbus.cyc;
  m0_wbus.stb       <= map_wbus.stb(0);
  m0_wbus.addr      <= "0" & map_wbus.addr;
  m0_wbus.we        <= map_wbus.we;
  m0_wbus.wrdat     <= map_wbus.wrdat;
  map_wbus.stall(0) <= m0_wbus.stall;
  map_wbus.ack(0)   <= m0_wbus.ack;
  map_wbus.rddat(0) <= m0_wbus.rddat;

  wbus_sim_0_inst : entity work.wbus_sim
    generic map (
      G_SEED        => X"1234567812345678",
      G_NAME        => "0",
      G_TIMEOUT_MAX => 100,
      G_DEBUG       => G_DEBUG,
      G_TIMEOUT     => false,
      G_LATENCY     => G_LATENCY,
      G_OFFSET      => 1234,
      G_FIRST       => '0',
      G_DO_ABORT    => G_DO_ABORT
    )
    port map (
      clk_i  => clk,
      rst_i  => m0_rst,
      m_wbus => s0_wbus,
      s_wbus => m0_wbus
    ); -- wbus_sim_0_inst : entity work.wbus_sim


  m1_rst            <= map_wbus.rst(1);
  m1_wbus.cyc       <= map_wbus.cyc;
  m1_wbus.stb       <= map_wbus.stb(1);
  m1_wbus.addr      <= "1" & map_wbus.addr;
  m1_wbus.we        <= map_wbus.we;
  m1_wbus.wrdat     <= map_wbus.wrdat;
  map_wbus.stall(1) <= m1_wbus.stall;
  map_wbus.ack(1)   <= m1_wbus.ack;
  map_wbus.rddat(1) <= m1_wbus.rddat;

  wbus_sim_1_inst : entity work.wbus_sim
    generic map (
      G_SEED        => X"1122334455667788",
      G_NAME        => "1",
      G_TIMEOUT_MAX => 100,
      G_DEBUG       => G_DEBUG,
      G_TIMEOUT     => false,
      G_LATENCY     => G_LATENCY,
      G_OFFSET      => 4321,
      G_FIRST       => '1',
      G_DO_ABORT    => G_DO_ABORT
    )
    port map (
      clk_i  => clk,
      rst_i  => m1_rst,
      m_wbus => s1_wbus,
      s_wbus => m1_wbus
    ); -- wbus_sim_1_inst : entity work.wbus_sim

end architecture simulation;

