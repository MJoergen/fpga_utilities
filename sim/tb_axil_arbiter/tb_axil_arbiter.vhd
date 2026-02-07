-- ---------------------------------------------------------------------------------------
-- Description: Verify axil_arbiter.
-- ---------------------------------------------------------------------------------------

library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std.all;

library work;
  use work.axil_pkg.all;

entity tb_axil_arbiter is
  generic (
    G_DEBUG      : boolean;
    G_PAUSE_SIZE : natural;
    G_RANDOM     : boolean;
    G_FAST       : boolean;
    G_ADDR_SIZE  : natural;
    G_DATA_SIZE  : natural
  );
end entity tb_axil_arbiter;

architecture simulation of tb_axil_arbiter is

  signal clk : std_logic := '1';
  signal rst : std_logic := '1';

  signal s0_axil : axil_rec_type (
    awaddr(G_ADDR_SIZE - 1 downto 0),
    wdata(G_DATA_SIZE - 1 downto 0),
    wstrb(G_DATA_SIZE/8 - 1 downto 0),
    araddr(G_ADDR_SIZE - 1 downto 0),
    rdata(G_DATA_SIZE - 1 downto 0)
  );

  signal s1_axil : axil_rec_type (
    awaddr(G_ADDR_SIZE - 1 downto 0),
    wdata(G_DATA_SIZE - 1 downto 0),
    wstrb(G_DATA_SIZE/8 - 1 downto 0),
    araddr(G_ADDR_SIZE - 1 downto 0),
    rdata(G_DATA_SIZE - 1 downto 0)
  );

  signal p0_axil : axil_rec_type (
    awaddr(G_ADDR_SIZE - 1 downto 0),
    wdata(G_DATA_SIZE - 1 downto 0),
    wstrb(G_DATA_SIZE/8 - 1 downto 0),
    araddr(G_ADDR_SIZE - 1 downto 0),
    rdata(G_DATA_SIZE - 1 downto 0)
  );

  signal p1_axil : axil_rec_type (
    awaddr(G_ADDR_SIZE - 1 downto 0),
    wdata(G_DATA_SIZE - 1 downto 0),
    wstrb(G_DATA_SIZE/8 - 1 downto 0),
    araddr(G_ADDR_SIZE - 1 downto 0),
    rdata(G_DATA_SIZE - 1 downto 0)
  );

  signal d_axil : axil_rec_type (
    awaddr(G_ADDR_SIZE - 1 downto 0),
    wdata(G_DATA_SIZE - 1 downto 0),
    wstrb(G_DATA_SIZE/8 - 1 downto 0),
    araddr(G_ADDR_SIZE - 1 downto 0),
    rdata(G_DATA_SIZE - 1 downto 0)
  );

  signal p_axil : axil_rec_type (
    awaddr(G_ADDR_SIZE - 1 downto 0),
    wdata(G_DATA_SIZE - 1 downto 0),
    wstrb(G_DATA_SIZE/8 - 1 downto 0),
    araddr(G_ADDR_SIZE - 1 downto 0),
    rdata(G_DATA_SIZE - 1 downto 0)
  );

  signal s0_busy : std_logic;
  signal s1_busy : std_logic;

begin

  ----------------------------------------------
  -- Clock and Reset
  ----------------------------------------------

  clk <= not clk after 5 ns;
  rst <= '1', '0' after 100 ns;


  ----------------------------------------------
  -- Instantiate DUT
  ----------------------------------------------

  axil_arbiter_inst : entity work.axil_arbiter
    port map (
      clk_i   => clk,
      rst_i   => rst,
      s0_axil => p0_axil,
      s1_axil => p1_axil,
      m_axil  => d_axil
    ); -- axil_arbiter_inst : entity work.axil_arbiter


  ----------------------------------------------
  -- Instantiate AXI lite masters
  ----------------------------------------------

  axil_master_sim_0_inst : entity work.axil_master_sim
    generic map (
      G_NAME   => "0",
      G_SEED   => X"1234567887654321",
      G_OFFSET => 1234,
      G_DEBUG  => G_DEBUG,
      G_RANDOM => G_RANDOM,
      G_FIRST  => '0',
      G_FAST   => G_FAST
    )
    port map (
      clk_i  => clk,
      rst_i  => rst,
      m_axil => s0_axil
    ); -- axil_master_sim_0_inst : entity work.axil_master_sim

  axil_master_sim_1_inst : entity work.axil_master_sim
    generic map (
      G_NAME   => "1",
      G_SEED   => X"ABCDEFABCDEFABCD",
      G_OFFSET => 4321,
      G_DEBUG  => G_DEBUG,
      G_RANDOM => G_RANDOM,
      G_FIRST  => '1',
      G_FAST   => G_FAST
    )
    port map (
      clk_i  => clk,
      rst_i  => rst,
      m_axil => s1_axil
    ); -- axil_master_sim_1_inst : entity work.axil_master_sim


  ----------------------------------------------
  -- Instantiate AXI lite pauses
  ----------------------------------------------

  axil_pause_0_inst : entity work.axil_pause
    generic map (
      G_SEED       => X"8765432112345678",
      G_PAUSE_SIZE => G_PAUSE_SIZE
    )
    port map (
      clk_i  => clk,
      rst_i  => rst,
      s_axil => s0_axil,
      m_axil => p0_axil
    ); -- axil_pause_0_inst : entity work.axil_pause

  axil_pause_1_inst : entity work.axil_pause
    generic map (
      G_SEED       => X"ABCDEFABCDEFABCD",
      G_PAUSE_SIZE => G_PAUSE_SIZE
    )
    port map (
      clk_i  => clk,
      rst_i  => rst,
      s_axil => s1_axil,
      m_axil => p1_axil
    ); -- axil_pause_1_inst : entity work.axil_pause

  axil_pause_d_inst : entity work.axil_pause
    generic map (
      G_SEED       => X"DEADBEEFC007BABE",
      G_PAUSE_SIZE => G_PAUSE_SIZE
    )
    port map (
      clk_i  => clk,
      rst_i  => rst,
      s_axil => d_axil,
      m_axil => p_axil
    ); -- axil_pause_d_inst : entity work.axil_pause


  ----------------------------------------------
  -- Instantiate AXI lite slave
  ----------------------------------------------

  axil_slave_sim_inst : entity work.axil_slave_sim
    generic map (
      G_DEBUG => G_DEBUG,
      G_FAST  => G_FAST
    )
    port map (
      clk_i  => clk,
      rst_i  => rst,
      s_axil => p_axil
    ); -- axil_slave_sim_inst : entity work.axil_slave_sim


  ----------------------------------------------
  -- Check
  ----------------------------------------------

  -- s0_busy and s1_busy are asserted when either a AW or W transaction is completed, but not
  -- both.
  axil_busy_0_inst : entity work.axil_busy
    port map (
      clk_i     => clk,
      rst_i     => rst,
      awready_i => s0_axil.awready,
      awvalid_i => s0_axil.awvalid,
      wready_i  => s0_axil.wready,
      wvalid_i  => s0_axil.wvalid,
      busy_o    => s0_busy
    ); -- axil_busy_0_inst : entity work.axil_busy

  axil_busy_1_inst : entity work.axil_busy
    port map (
      clk_i     => clk,
      rst_i     => rst,
      awready_i => s1_axil.awready,
      awvalid_i => s1_axil.awvalid,
      wready_i  => s1_axil.wready,
      wvalid_i  => s1_axil.wvalid,
      busy_o    => s1_busy
    ); -- axil_busy_1_inst : entity work.axil_busy

  check_proc : process (clk)
  begin
    if rising_edge(clk) then
      assert (s0_busy and s1_busy) /= '1'
        report "axi_lite_arbiter: ERROR: Both slaves busy";
    end if;
  end process check_proc;

end architecture simulation;

