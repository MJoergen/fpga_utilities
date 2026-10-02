-- ---------------------------------------------------------------------------------------
-- Description: Verify wbus_mapper
--
-- The DUT has three slaves, selected by a two-bit slave index, so index 3 is not mapped:
--   * Slaves 0 and 1 are memories, with random stalls.
--   * Slave 2 never responds: on even addresses it stalls forever, and on odd addresses
--     it accepts the request but never acknowledges it.
--
-- A random master issues reads and writes to all four slave indices, and occasionally
-- aborts a transaction by deasserting CYC. It checks that:
--   * Reads from slaves 0 and 1 return the data written (honouring SEL).
--   * Every request to slave 2 is acknowledged after the timeout, and a read returns
--     the timeout pattern.
--   * Every request to the unmapped index is acknowledged at once, and a read returns
--     the bad-slave pattern.
-- Monitors check the Wishbone rules: on the slave side, STB is only asserted together
-- with CYC, and at most one STB is asserted at a time; on the master side, ACK is only
-- asserted while a request is outstanding (e.g. not for an aborted request).
--
-- SPDX-License-Identifier: MIT
-- ---------------------------------------------------------------------------------------

library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std.all;
  use ieee.math_real.all;

library std;
  use std.env.stop;

library work;
  use work.wbus_pkg.all;

entity tb_wbus_mapper is
  generic (
    G_DEBUG            : boolean;
    G_NUM_TRANSACTIONS : positive;
    G_TIMEOUT_MAX      : positive
  );
end entity tb_wbus_mapper;

architecture tb of tb_wbus_mapper is

  constant C_NUM_SLAVES       : positive := 3;
  constant C_SLAVE_ADDR_BITS  : positive := 4;
  constant C_MASTER_ADDR_BITS : positive := C_SLAVE_ADDR_BITS + 2;
  constant C_DATA_BITS        : positive := 32;
  constant C_SEL_BITS         : positive := C_DATA_BITS / 8;

  constant C_BAD_SLAVE : std_logic_vector(C_DATA_BITS - 1 downto 0) := x"BAD51A73";
  constant C_TIMEOUT   : std_logic_vector(C_DATA_BITS - 1 downto 0) := x"DEADBEEF";

  signal   clk : std_logic := '1';
  signal   rst : std_logic := '1';

  -- Upstream master
  signal   s_cyc   : std_logic := '0';
  signal   s_stall : std_logic;
  signal   s_stb   : std_logic := '0';
  signal   s_addr  : std_logic_vector(C_MASTER_ADDR_BITS - 1 downto 0);
  signal   s_we    : std_logic;
  signal   s_wrdat : std_logic_vector(C_DATA_BITS - 1 downto 0);
  signal   s_sel   : std_logic_vector(C_SEL_BITS - 1 downto 0);
  signal   s_ack   : std_logic;
  signal   s_rddat : std_logic_vector(C_DATA_BITS - 1 downto 0);

  -- A request has been accepted and not yet acknowledged or aborted
  signal   s_pending : boolean := false;

  -- Downstream slaves
  signal   m_rst   : std_logic_vector(C_NUM_SLAVES - 1 downto 0);
  signal   m_cyc   : std_logic;
  signal   m_stall : std_logic_vector(C_NUM_SLAVES - 1 downto 0);
  signal   m_stb   : std_logic_vector(C_NUM_SLAVES - 1 downto 0);
  signal   m_addr  : std_logic_vector(C_SLAVE_ADDR_BITS - 1 downto 0);
  signal   m_we    : std_logic;
  signal   m_wrdat : std_logic_vector(C_DATA_BITS - 1 downto 0);
  signal   m_sel   : std_logic_vector(C_SEL_BITS - 1 downto 0);
  signal   m_ack   : std_logic_vector(C_NUM_SLAVES - 1 downto 0);
  signal   m_rddat : slv_array_type(C_NUM_SLAVES - 1 downto 0)(C_DATA_BITS - 1 downto 0);

begin

  --------------------------------
  -- Clock and Reset
  --------------------------------

  clk <= not clk after 5 ns;
  rst <= '1', '0' after 100 ns;


  --------------------------------
  -- Instantiate DUT
  --------------------------------

  wbus_mapper_inst : entity work.wbus_mapper
    generic map (
      G_TIMEOUT_MAX      => G_TIMEOUT_MAX,
      G_NUM_SLAVES       => C_NUM_SLAVES,
      G_MASTER_ADDR_BITS => C_MASTER_ADDR_BITS,
      G_SLAVE_ADDR_BITS  => C_SLAVE_ADDR_BITS,
      G_DATA_BITS        => C_DATA_BITS
    )
    port map (
      clk_i     => clk,
      rst_i     => rst,
      s_cyc_i   => s_cyc,
      s_stall_o => s_stall,
      s_stb_i   => s_stb,
      s_addr_i  => s_addr,
      s_we_i    => s_we,
      s_wrdat_i => s_wrdat,
      s_sel_i   => s_sel,
      s_ack_o   => s_ack,
      s_rddat_o => s_rddat,
      m_rst_o   => m_rst,
      m_cyc_o   => m_cyc,
      m_stall_i => m_stall,
      m_stb_o   => m_stb,
      m_addr_o  => m_addr,
      m_we_o    => m_we,
      m_wrdat_o => m_wrdat,
      m_sel_o   => m_sel,
      m_ack_i   => m_ack,
      m_rddat_i => m_rddat
    ); -- wbus_mapper_inst : entity work.wbus_mapper


  --------------------------------
  -- Slaves 0 and 1: memories with random stalls
  --------------------------------

  memory_gen : for i in 0 to 1 generate
    signal p_cyc   : std_logic;
    signal p_stall : std_logic;
    signal p_stb   : std_logic;
    signal p_addr  : std_logic_vector(C_SLAVE_ADDR_BITS - 1 downto 0);
    signal p_we    : std_logic;
    signal p_wrdat : std_logic_vector(C_DATA_BITS - 1 downto 0);
    signal p_sel   : std_logic_vector(C_SEL_BITS - 1 downto 0);
    signal p_ack   : std_logic;
    signal p_rddat : std_logic_vector(C_DATA_BITS - 1 downto 0);
  begin

    wbus_pause_inst : entity work.wbus_pause
      generic map (
        G_SEED       => std_logic_vector(to_unsigned(i * 4711 + 1234567, 64)),
        G_PAUSE_SIZE => 3,
        G_ADDR_BITS  => C_SLAVE_ADDR_BITS,
        G_DATA_BITS  => C_DATA_BITS
      )
      port map (
        clk_i     => clk,
        rst_i     => m_rst(i),
        s_cyc_i   => m_cyc,
        s_stall_o => m_stall(i),
        s_stb_i   => m_stb(i),
        s_addr_i  => m_addr,
        s_we_i    => m_we,
        s_wrdat_i => m_wrdat,
        s_sel_i   => m_sel,
        s_ack_o   => m_ack(i),
        s_rddat_o => m_rddat(i),
        m_cyc_o   => p_cyc,
        m_stall_i => p_stall,
        m_stb_o   => p_stb,
        m_addr_o  => p_addr,
        m_we_o    => p_we,
        m_wrdat_o => p_wrdat,
        m_sel_o   => p_sel,
        m_ack_i   => p_ack,
        m_rddat_i => p_rddat
      ); -- wbus_pause_inst : entity work.wbus_pause

    wbus_slave_sim_inst : entity work.wbus_slave_sim
      generic map (
        G_NAME      => integer'image(i),
        G_DEBUG     => G_DEBUG,
        G_ADDR_BITS => C_SLAVE_ADDR_BITS,
        G_DATA_BITS => C_DATA_BITS
      )
      port map (
        clk_i     => clk,
        rst_i     => m_rst(i),
        s_cyc_i   => p_cyc,
        s_stall_o => p_stall,
        s_stb_i   => p_stb,
        s_addr_i  => p_addr,
        s_we_i    => p_we,
        s_wrdat_i => p_wrdat,
        s_sel_i   => p_sel,
        s_ack_o   => p_ack,
        s_rddat_o => p_rddat
      ); -- wbus_slave_sim_inst : entity work.wbus_slave_sim

  end generate memory_gen;


  --------------------------------
  -- Slave 2: never responds. Even addresses stall forever; odd addresses are
  -- accepted but never acknowledged.
  --------------------------------

  m_stall(2) <= not m_addr(0);
  m_ack(2)   <= '0';
  m_rddat(2) <= (others => '0');


  --------------------------------
  -- Monitor the Wishbone rules on the slave side
  --------------------------------

  monitor_proc : process (clk)
    variable count_v : natural;
  begin
    if rising_edge(clk) then
      if rst = '0' then
        count_v := 0;
        for i in 0 to C_NUM_SLAVES - 1 loop
          assert m_stb(i) = '0' or m_cyc = '1'
            report "tb_wbus_mapper: STB to slave " & integer'image(i) & " is asserted without CYC"
            severity failure;
          if m_stb(i) = '1' then
            count_v := count_v + 1;
          end if;
        end loop;
        assert count_v <= 1
          report "tb_wbus_mapper: More than one STB is asserted"
          severity failure;
        assert s_ack = '0' or s_cyc = '0' or s_pending
          report "tb_wbus_mapper: ACK without an outstanding request"
          severity failure;
      end if;
    end if;
  end process monitor_proc;


  --------------------------------
  -- Random master
  --------------------------------

  master_proc : process
    type     mem_type is array (0 to 1, 0 to 2 ** C_SLAVE_ADDR_BITS - 1) of std_logic_vector(C_DATA_BITS - 1 downto 0);
    type     valid_type is array (0 to 1, 0 to 2 ** C_SLAVE_ADDR_BITS - 1) of std_logic_vector(C_SEL_BITS - 1 downto 0);
    variable mem_v    : mem_type;
    variable valid_v  : valid_type := (others => (others => (others => '0')));
    variable seed1_v  : positive   := 42;
    variable seed2_v  : positive   := 4711;
    variable target_v : natural range 0 to 4;
    variable idx_v    : natural range 0 to 3;
    variable addr_v   : natural range 0 to 2 ** C_SLAVE_ADDR_BITS - 1;
    variable we_v     : std_logic;
    variable wrdat_v  : std_logic_vector(C_DATA_BITS - 1 downto 0);
    variable sel_v    : std_logic_vector(C_SEL_BITS - 1 downto 0);
    variable abort_v  : boolean;
    variable cycles_v : natural;
    variable count_v  : natural := 0;

    impure function rand_int (
      n : positive
    ) return natural is
      variable r_v : real;
    begin
      uniform(seed1_v, seed2_v, r_v);
      return integer(floor(r_v * real(n)));
    end function rand_int;

    impure function rand_slv (
      n : positive
    ) return std_logic_vector is
      variable res_v : std_logic_vector(n - 1 downto 0);
    begin
      for i in res_v'range loop
        if rand_int(2) = 1 then
          res_v(i) := '1';
        else
          res_v(i) := '0';
        end if;
      end loop;
      return res_v;
    end function rand_slv;

  begin
    s_cyc <= '0';
    s_stb <= '0';
    wait until rst = '0';
    wait until rising_edge(clk);

    while count_v < G_NUM_TRANSACTIONS loop
      -- Choose the transaction
      --   0, 1 : memory slave 0 or 1
      --   2    : slave 2, even address (stalls forever)
      --   3    : slave 2, odd address (never acknowledges)
      --   4    : unmapped slave index
      target_v := rand_int(5);
      addr_v   := rand_int(2 ** C_SLAVE_ADDR_BITS);
      case target_v is
        when 0 | 1 =>
          idx_v := target_v;
        when 2 =>
          idx_v  := 2;
          addr_v := addr_v - (addr_v mod 2);
        when 3 =>
          idx_v  := 2;
          addr_v := addr_v - (addr_v mod 2) + 1;
        when others =>
          idx_v := 3;
      end case;
      we_v    := rand_slv(1)(0);
      wrdat_v := rand_slv(C_DATA_BITS);
      sel_v   := rand_slv(C_SEL_BITS);
      if sel_v = "0000" then
        sel_v := "0001";
      end if;
      abort_v := rand_int(16) = 0;

      if G_DEBUG then
        report "tb_wbus_mapper: " & (1 to 1 => character'val(48 + idx_v)) & " " &
               to_string(we_v) & " " & integer'image(addr_v) & " " & to_hstring(wrdat_v) & " " & to_hstring(sel_v);
      end if;

      -- Issue the request
      s_cyc   <= '1';
      s_stb   <= '1';
      s_addr  <= std_logic_vector(to_unsigned(idx_v, 2)) & std_logic_vector(to_unsigned(addr_v, C_SLAVE_ADDR_BITS));
      s_we    <= we_v;
      s_wrdat <= wrdat_v;
      s_sel   <= sel_v;
      loop
        wait until rising_edge(clk);
        exit when s_stall = '0';
      end loop;
      s_stb     <= '0';
      s_pending <= true;

      if abort_v then
        -- Abort the transaction after a random number of clock cycles. A write to a
        -- memory slave may or may not have taken place.
        for i in 1 to rand_int(4) loop
          wait until rising_edge(clk);
        end loop;
        if idx_v <= 1 and we_v = '1' then
          valid_v(idx_v, addr_v) := valid_v(idx_v, addr_v) and not sel_v;
        end if;
      else
        -- Wait for the acknowledge
        cycles_v := 0;
        loop
          wait until rising_edge(clk);
          exit when s_ack = '1';
          cycles_v := cycles_v + 1;
          assert cycles_v < G_TIMEOUT_MAX + 10
            report "tb_wbus_mapper: No acknowledge from slave " & integer'image(idx_v)
            severity failure;
        end loop;

        case idx_v is

          when 0 | 1 =>
            if we_v = '1' then
              for i in 0 to C_SEL_BITS - 1 loop
                if sel_v(i) = '1' then
                  mem_v(idx_v, addr_v)(8 * i + 7 downto 8 * i) := wrdat_v(8 * i + 7 downto 8 * i);
                end if;
              end loop;
              valid_v(idx_v, addr_v) := valid_v(idx_v, addr_v) or sel_v;
            else
              for i in 0 to C_SEL_BITS - 1 loop
                if valid_v(idx_v, addr_v)(i) = '1' then
                  assert s_rddat(8 * i + 7 downto 8 * i) = mem_v(idx_v, addr_v)(8 * i + 7 downto 8 * i)
                    report "tb_wbus_mapper: Read from slave " & integer'image(idx_v) &
                           " address " & integer'image(addr_v) &
                           ". Got " & to_hstring(s_rddat) &
                           ", expected " & to_hstring(mem_v(idx_v, addr_v)) &
                           " in byte lane " & integer'image(i)
                    severity failure;
                end if;
              end loop;
            end if;

          when 2 =>
            assert cycles_v >= G_TIMEOUT_MAX
              report "tb_wbus_mapper: Timeout after only " & integer'image(cycles_v) & " clock cycles"
              severity failure;
            assert we_v = '1' or s_rddat = C_TIMEOUT
              report "tb_wbus_mapper: Read from slave 2 returned " & to_hstring(s_rddat) &
                     ", expected " & to_hstring(C_TIMEOUT)
              severity failure;

          when others =>
            assert cycles_v = 0
              report "tb_wbus_mapper: Unmapped slave acknowledged after " & integer'image(cycles_v) & " clock cycles"
              severity failure;
            assert we_v = '1' or s_rddat = C_BAD_SLAVE
              report "tb_wbus_mapper: Read from unmapped slave returned " & to_hstring(s_rddat) &
                     ", expected " & to_hstring(C_BAD_SLAVE)
              severity failure;

        end case;
      end if;

      -- End the bus cycle
      s_pending <= false;
      s_cyc     <= '0';
      wait until rising_edge(clk);
      count_v := count_v + 1;
    end loop;

    report "tb_wbus_mapper: Test finished";
    stop;
  end process master_proc;

end architecture tb;
