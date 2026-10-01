-- ---------------------------------------------------------------------------------------
-- Description: Verify wbus_arbiter_general
--
-- G_NUM_MASTERS Wishbone masters share a single Wishbone slave through the DUT. Each
-- master is given its own region of the slave's address space (the master index is
-- prepended to the address), so each master can verify its own read-back data.
--
-- SPDX-License-Identifier: MIT
-- ---------------------------------------------------------------------------------------

library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std.all;

library work;
  use work.wbus_pkg.all;

entity tb_wbus_arbiter_general is
  generic (
    G_DEBUG       : boolean;
    G_DO_ABORT    : boolean;
    G_NUM_MASTERS : positive;
    G_ADDR_BITS   : positive;
    G_DATA_BITS   : positive
  );
end entity tb_wbus_arbiter_general;

architecture tb of tb_wbus_arbiter_general is

  -- Number of address bits used to select the region belonging to each master
  constant C_IDX_BITS : positive := 2;

  signal   clk : std_logic := '1';
  signal   rst : std_logic := '1';

  signal   s_cyc   : std_logic_vector(G_NUM_MASTERS - 1 downto 0);
  signal   s_stall : std_logic_vector(G_NUM_MASTERS - 1 downto 0);
  signal   s_stb   : std_logic_vector(G_NUM_MASTERS - 1 downto 0);
  signal   s_addr  : slv_array_type(G_NUM_MASTERS - 1 downto 0)(G_ADDR_BITS - 1 downto 0);
  signal   s_we    : std_logic_vector(G_NUM_MASTERS - 1 downto 0);
  signal   s_wrdat : slv_array_type(G_NUM_MASTERS - 1 downto 0)(G_DATA_BITS - 1 downto 0);
  signal   s_sel   : slv_array_type(G_NUM_MASTERS - 1 downto 0)(G_DATA_BITS / 8 - 1 downto 0);
  signal   s_ack   : std_logic_vector(G_NUM_MASTERS - 1 downto 0);
  signal   s_rddat : slv_array_type(G_NUM_MASTERS - 1 downto 0)(G_DATA_BITS - 1 downto 0);

  -- Master addresses, prefixed with the master index
  signal   s_addr_idx : slv_array_type(G_NUM_MASTERS - 1 downto 0)(C_IDX_BITS + G_ADDR_BITS - 1 downto 0);

  signal   m_cyc   : std_logic;
  signal   m_stall : std_logic;
  signal   m_stb   : std_logic;
  signal   m_addr  : std_logic_vector(C_IDX_BITS + G_ADDR_BITS - 1 downto 0);
  signal   m_we    : std_logic;
  signal   m_wrdat : std_logic_vector(G_DATA_BITS - 1 downto 0);
  signal   m_sel   : std_logic_vector(G_DATA_BITS / 8 - 1 downto 0);
  signal   m_ack   : std_logic;
  signal   m_rddat : std_logic_vector(G_DATA_BITS - 1 downto 0);

begin

  assert G_NUM_MASTERS <= 2 ** C_IDX_BITS
    report "tb_wbus_arbiter_general: G_NUM_MASTERS must be <= " & integer'image(2 ** C_IDX_BITS)
    severity failure;


  --------------------------------
  -- Clock and Reset
  --------------------------------

  clk <= not clk after 5 ns;
  rst <= '1', '0' after 100 ns;


  --------------------------------
  -- Instantiate DUT
  --------------------------------

  wbus_arbiter_general_inst : entity work.wbus_arbiter_general
    generic map (
      G_ADDR_BITS   => C_IDX_BITS + G_ADDR_BITS,
      G_DATA_BITS   => G_DATA_BITS,
      G_NUM_MASTERS => G_NUM_MASTERS
    )
    port map (
      clk_i     => clk,
      rst_i     => rst,
      s_cyc_i   => s_cyc,
      s_stall_o => s_stall,
      s_stb_i   => s_stb,
      s_addr_i  => s_addr_idx,
      s_we_i    => s_we,
      s_wrdat_i => s_wrdat,
      s_sel_i   => s_sel,
      s_ack_o   => s_ack,
      s_rddat_o => s_rddat,
      m_cyc_o   => m_cyc,
      m_stall_i => m_stall,
      m_stb_o   => m_stb,
      m_addr_o  => m_addr,
      m_we_o    => m_we,
      m_wrdat_o => m_wrdat,
      m_sel_o   => m_sel,
      m_ack_i   => m_ack,
      m_rddat_i => m_rddat
    ); -- wbus_arbiter_general_inst : entity work.wbus_arbiter_general


  --------------------------------
  -- Instantiate Wishbone masters
  --------------------------------

  master_gen : for i in 0 to G_NUM_MASTERS - 1 generate

    s_addr_idx(i) <= std_logic_vector(to_unsigned(i, C_IDX_BITS)) & s_addr(i);

    wbus_master_sim_inst : entity work.wbus_master_sim
      generic map (
        G_SEED        => std_logic_vector(to_unsigned(i + 1, 64)) xor X"DEADBEEFC007BABE",
        G_NAME        => integer'image(i),
        G_TIMEOUT_MAX => 200,
        G_DEBUG       => G_DEBUG,
        G_DO_ABORT    => G_DO_ABORT,
        G_OFFSET      => 1234 + 1000 * i,
        G_ADDR_BITS   => G_ADDR_BITS,
        G_DATA_BITS   => G_DATA_BITS
      )
      port map (
        clk_i     => clk,
        rst_i     => rst,
        m_cyc_o   => s_cyc(i),
        m_stall_i => s_stall(i),
        m_stb_o   => s_stb(i),
        m_addr_o  => s_addr(i),
        m_we_o    => s_we(i),
        m_wrdat_o => s_wrdat(i),
        m_sel_o   => s_sel(i),
        m_ack_i   => s_ack(i),
        m_rddat_i => s_rddat(i)
      ); -- wbus_master_sim_inst : entity work.wbus_master_sim

  end generate master_gen;


  --------------------------------
  -- Instantiate Wishbone slave
  --------------------------------

  wbus_slave_sim_inst : entity work.wbus_slave_sim
    generic map (
      G_DEBUG     => G_DEBUG,
      G_ADDR_BITS => C_IDX_BITS + G_ADDR_BITS,
      G_DATA_BITS => G_DATA_BITS
    )
    port map (
      clk_i     => clk,
      rst_i     => rst,
      s_cyc_i   => m_cyc,
      s_stall_o => m_stall,
      s_stb_i   => m_stb,
      s_addr_i  => m_addr,
      s_we_i    => m_we,
      s_wrdat_i => m_wrdat,
      s_sel_i   => m_sel,
      s_ack_o   => m_ack,
      s_rddat_o => m_rddat
    ); -- wbus_slave_sim_inst : entity work.wbus_slave_sim

end architecture tb;
