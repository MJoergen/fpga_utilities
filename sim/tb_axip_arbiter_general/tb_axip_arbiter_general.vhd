-- ---------------------------------------------------------------------------------------
-- Description: Verify axip_arbiter_general
--
-- G_NUM_MASTERS packet generators share a single AXI packet stream through the DUT.
-- A one-byte header holding the master index is inserted in front of each packet
-- before the DUT, and is used after the DUT to route the packet back to the checker
-- belonging to the same master. Each checker verifies that it receives exactly the
-- packets sent by its master, in order and unmodified.
--
-- A watchdog checks that no master waits too long to be granted access.
--
-- SPDX-License-Identifier: MIT
-- ---------------------------------------------------------------------------------------

library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std.all;

library work;
  use work.axip_pkg.all;

entity tb_axip_arbiter_general is
  generic (
    G_RANDOM      : boolean;
    G_DEBUG       : boolean;
    G_MIN_LENGTH  : natural;
    G_MAX_LENGTH  : natural;
    G_FAST        : boolean;
    G_CNT_SIZE    : natural;
    G_NUM_MASTERS : positive;
    G_DATA_BYTES  : positive
  );
end entity tb_axip_arbiter_general;

architecture tb of tb_axip_arbiter_general is

  -- Maximum number of clock cycles a master may wait with valid data before its
  -- data is accepted.
  constant C_WATCHDOG_MAX : natural := 2000;

  subtype  data_type is std_logic_vector(G_DATA_BYTES * 8 - 1 downto 0);
  type     data_array_type is array (natural range <>) of data_type;
  type     nat_array_type is array (natural range <>) of natural range 0 to G_DATA_BYTES;

  signal   clk : std_logic := '1';
  signal   rst : std_logic := '1';

  -- Packet generators
  signal   g_ready : std_logic_vector(G_NUM_MASTERS - 1 downto 0);
  signal   g_valid : std_logic_vector(G_NUM_MASTERS - 1 downto 0);
  signal   g_data  : data_array_type(G_NUM_MASTERS - 1 downto 0);
  signal   g_last  : std_logic_vector(G_NUM_MASTERS - 1 downto 0);
  signal   g_bytes : nat_array_type(G_NUM_MASTERS - 1 downto 0);

  -- DUT inputs (with header)
  signal   s_ready : std_logic_vector(G_NUM_MASTERS - 1 downto 0);
  signal   s_valid : std_logic_vector(G_NUM_MASTERS - 1 downto 0);
  signal   s_data  : std_logic_vector(G_NUM_MASTERS * G_DATA_BYTES * 8 - 1 downto 0);
  signal   s_last  : std_logic_vector(G_NUM_MASTERS - 1 downto 0);
  signal   s_bytes : bytes_array_type(G_NUM_MASTERS - 1 downto 0);
  signal   h_bytes : nat_array_type(G_NUM_MASTERS - 1 downto 0);

  -- DUT output (with header)
  signal   d_ready : std_logic;
  signal   d_valid : std_logic;
  signal   d_data  : data_type;
  signal   d_last  : std_logic;
  signal   d_bytes : bytes_type;
  signal   d_bytes_n : natural range 0 to G_DATA_BYTES;

  -- After header removal
  signal   dh_ready : std_logic;
  signal   dh_valid : std_logic;
  signal   dh_data  : data_type;
  signal   dh_last  : std_logic;
  signal   dh_bytes : natural range 0 to G_DATA_BYTES;
  signal   dh_first : std_logic;

  signal   h_data : std_logic_vector(7 downto 0);
  signal   dst    : natural range 0 to G_NUM_MASTERS - 1;
  signal   dst_r  : natural range 0 to G_NUM_MASTERS - 1;

  -- Packet checkers
  signal   c_ready : std_logic_vector(G_NUM_MASTERS - 1 downto 0);
  signal   c_valid : std_logic_vector(G_NUM_MASTERS - 1 downto 0);

begin

  assert G_NUM_MASTERS <= 256
    report "tb_axip_arbiter_general: G_NUM_MASTERS must be <= 256"
    severity failure;


  --------------------------------
  -- Clock and Reset
  --------------------------------

  clk <= not clk after 5 ns;
  rst <= '1', '0' after 100 ns;


  --------------------------------
  -- Instantiate DUT
  --------------------------------

  axip_arbiter_general_inst : entity work.axip_arbiter_general
    generic map (
      G_NUM_MASTERS => G_NUM_MASTERS,
      G_DATA_BYTES  => G_DATA_BYTES
    )
    port map (
      clk_i     => clk,
      rst_i     => rst,
      s_ready_o => s_ready,
      s_valid_i => s_valid,
      s_data_i  => s_data,
      s_last_i  => s_last,
      s_bytes_i => s_bytes,
      m_ready_i => d_ready,
      m_valid_o => d_valid,
      m_data_o  => d_data,
      m_last_o  => d_last,
      m_bytes_o => d_bytes
    ); -- axip_arbiter_general_inst : entity work.axip_arbiter_general


  --------------------------------
  -- Remove header and route each packet to its checker
  --------------------------------

  axip_remove_fixed_header_inst : entity work.axip_remove_fixed_header
    generic map (
      G_DATA_BYTES   => G_DATA_BYTES,
      G_HEADER_BYTES => 1
    )
    port map (
      clk_i     => clk,
      rst_i     => rst,
      s_ready_o => d_ready,
      s_valid_i => d_valid,
      s_data_i  => d_data,
      s_last_i  => d_last,
      s_bytes_i => d_bytes_n,
      m_ready_i => dh_ready,
      m_valid_o => dh_valid,
      m_data_o  => dh_data,
      m_last_o  => dh_last,
      m_bytes_o => dh_bytes,
      h_ready_i => '1',
      h_valid_o => open,
      h_data_o  => h_data
    ); -- axip_remove_fixed_header_inst : entity work.axip_remove_fixed_header

  -- The header is sampled on the first beat of each packet (as in axip_demux)
  dst_proc : process (clk)
  begin
    if rising_edge(clk) then
      if dh_valid = '1' and dh_ready = '1' then
        dh_first <= dh_last;
        dst_r    <= dst;
      end if;
      if rst = '1' then
        dh_first <= '1';
        dst_r    <= 0;
      end if;
    end if;
  end process dst_proc;

  dst <= to_integer(unsigned(h_data)) when dh_first = '1' and dh_valid = '1' else
         dst_r;

  dh_ready <= c_ready(dst);

  d_bytes_n <= d_bytes;


  --------------------------------
  -- Packet generators and checkers, one per master
  --------------------------------

  master_gen : for k in 0 to G_NUM_MASTERS - 1 generate
    signal wait_cnt : natural := 0;
  begin

    axip_sim_inst : entity work.axip_sim
      generic map (
        G_SEED       => std_logic_vector(to_unsigned(k * 7919 + 1234567, 64)),
        G_NAME       => integer'image(k),
        G_DEBUG      => G_DEBUG,
        G_RANDOM     => G_RANDOM,
        G_FAST       => G_FAST,
        G_MIN_LENGTH => G_MIN_LENGTH,
        G_MAX_LENGTH => G_MAX_LENGTH,
        G_CNT_SIZE   => G_CNT_SIZE,
        G_DATA_BYTES => G_DATA_BYTES
      )
      port map (
        clk_i     => clk,
        rst_i     => rst,
        m_ready_i => g_ready(k),
        m_valid_o => g_valid(k),
        m_data_o  => g_data(k),
        m_last_o  => g_last(k),
        m_bytes_o => g_bytes(k),
        s_ready_o => c_ready(k),
        s_valid_i => c_valid(k),
        s_data_i  => dh_data,
        s_last_i  => dh_last,
        s_bytes_i => dh_bytes
      ); -- axip_sim_inst : entity work.axip_sim

    axip_insert_fixed_header_inst : entity work.axip_insert_fixed_header
      generic map (
        G_DATA_BYTES   => G_DATA_BYTES,
        G_HEADER_BYTES => 1
      )
      port map (
        clk_i     => clk,
        rst_i     => rst,
        h_ready_o => open,
        h_valid_i => '1',
        h_data_i  => std_logic_vector(to_unsigned(k, 8)),
        s_ready_o => g_ready(k),
        s_valid_i => g_valid(k),
        s_data_i  => g_data(k),
        s_last_i  => g_last(k),
        s_bytes_i => g_bytes(k),
        m_ready_i => s_ready(k),
        m_valid_o => s_valid(k),
        m_data_o  => s_data((k + 1) * G_DATA_BYTES * 8 - 1 downto k * G_DATA_BYTES * 8),
        m_last_o  => s_last(k),
        m_bytes_o => h_bytes(k)
      ); -- axip_insert_fixed_header_inst : entity work.axip_insert_fixed_header

    s_bytes(k) <= h_bytes(k);

    c_valid(k) <= dh_valid when dst = k else
                  '0';

    -- Each master must be granted access within C_WATCHDOG_MAX clock cycles
    watchdog_proc : process (clk)
    begin
      if rising_edge(clk) then
        if s_valid(k) = '1' and s_ready(k) = '0' then
          wait_cnt <= wait_cnt + 1;
          assert wait_cnt < C_WATCHDOG_MAX
            report "tb_axip_arbiter_general: master " & integer'image(k) &
                   " not granted access within " & integer'image(C_WATCHDOG_MAX) & " cycles"
            severity failure;
        else
          wait_cnt <= 0;
        end if;
      end if;
    end process watchdog_proc;

  end generate master_gen;

end architecture tb;
