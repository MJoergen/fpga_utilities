-- ---------------------------------------------------------------------------------------
-- Description: This simulates a Wishbone Master.  It generates a sequence of Writes and
-- Reads, and verifies that the values returned from Read matches the corresponding values
-- during Write.
--
-- With G_RANDOM_SEL = true, each write uses a random SEL (at least one lane selected).
-- Lanes that are not selected carry a deliberately wrong value, and the read-back check
-- verifies both that the selected lanes were written and that the unselected lanes were
-- not.
--
-- SPDX-License-Identifier: MIT
-- ---------------------------------------------------------------------------------------

library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std_unsigned.all;
  use std.env.stop;

entity wbus_master_sim is
  generic (
    G_ADDR_BITS   : natural;
    G_DATA_BITS   : natural;
    G_RANDOM_SEL  : boolean                       := false;
    G_SEED        : std_logic_vector(63 downto 0) := X"DEADBEEFC007BABE";
    G_NAME        : string                        := "";
    G_TIMEOUT_MAX : natural                       := 0;
    G_DEBUG       : boolean                       := false;
    G_DO_ABORT    : boolean                       := false;
    G_OFFSET      : natural                       := 1234
  );
  port (
    clk_i     : in    std_logic;
    rst_i     : in    std_logic;
    m_cyc_o   : out   std_logic;
    m_stall_i : in    std_logic;
    m_stb_o   : out   std_logic;
    m_addr_o  : out   std_logic_vector(G_ADDR_BITS - 1 downto 0);
    m_we_o    : out   std_logic;
    m_wrdat_o : out   std_logic_vector(G_DATA_BITS - 1 downto 0);
    m_sel_o   : out   std_logic_vector(G_DATA_BITS / 8 - 1 downto 0);
    m_ack_i   : in    std_logic;
    m_rddat_i : in    std_logic_vector(G_DATA_BITS - 1 downto 0)
  );
end entity wbus_master_sim;

architecture simulation of wbus_master_sim is

  constant C_REP_STR : string      := "WBUS MASTER " & G_NAME;

  constant C_RANDOM_SIZE : natural := 16;
  signal   random_s      : std_logic_vector(63 downto 0);

  subtype  R_ABORT is natural range 47 downto 41;

  type     state_type is (IDLE_ST, WRITING_ST, READING_ST, DONE_ST);
  signal   state : state_type      := IDLE_ST;

  signal   wr_ptr      : std_logic_vector(G_ADDR_BITS - 1 downto 0);
  signal   wr_ptr_next : std_logic_vector(G_ADDR_BITS - 1 downto 0);
  signal   rd_ptr      : std_logic_vector(G_ADDR_BITS - 1 downto 0);
  signal   rd_ptr_next : std_logic_vector(G_ADDR_BITS - 1 downto 0);

  pure function addr_to_data (
    addr : std_logic_vector
  ) return std_logic_vector is
  begin
    return resize(addr, G_DATA_BITS) + G_OFFSET;
  end function addr_to_data;

  signal   do_read  : std_logic;
  signal   do_write : std_logic;
  signal   do_abort : std_logic;

  signal   req_active  : std_logic := '0';
  signal   timeout_cnt : natural range 0 to G_TIMEOUT_MAX;

  constant C_SEL_BITS : natural := G_DATA_BITS / 8;

  -- Bit-field selector within random_s used for a random SEL.
  subtype  R_SEL is natural range 48 + C_SEL_BITS - 1 downto 48;

  -- SEL used for the most recent write to each address.
  type     sel_mem_type is array (natural range <>) of std_logic_vector(C_SEL_BITS - 1 downto 0);
  signal   sel_mem : sel_mem_type(0 to 2 ** G_ADDR_BITS - 1);

  -- Value driven on a byte lane that is not selected. It differs from the expected
  -- byte, and is never zero, so it can be told apart both from the expected data and
  -- from memory that was never written (zero or 'U').
  pure function garbage_byte (
    b : std_logic_vector(7 downto 0)
  ) return std_logic_vector is
    variable res_v : std_logic_vector(7 downto 0);
  begin
    res_v := b xor X"A5";
    if res_v = X"00" then
      res_v := X"5A";
    end if;
    return res_v;
  end function garbage_byte;

  -- Write data: the expected data on selected lanes, and garbage elsewhere.
  pure function sel_data (
    data : std_logic_vector(G_DATA_BITS - 1 downto 0);
    sel  : std_logic_vector(C_SEL_BITS - 1 downto 0)
  ) return std_logic_vector is
    variable res_v : std_logic_vector(G_DATA_BITS - 1 downto 0);
  begin
    for i in 0 to C_SEL_BITS - 1 loop
      if sel(i) = '1' then
        res_v(8 * i + 7 downto 8 * i) := data(8 * i + 7 downto 8 * i);
      else
        res_v(8 * i + 7 downto 8 * i) := garbage_byte(data(8 * i + 7 downto 8 * i));
      end if;
    end loop;
    return res_v;
  end function sel_data;

begin

  assert C_SEL_BITS <= 16
    report C_REP_STR & ": G_DATA_BITS must be at most 128"
    severity failure;

  wr_ptr_next <= wr_ptr + 1;
  rd_ptr_next <= rd_ptr + 1;

  --------------------------------
  -- Instantiate random number generator
  --------------------------------

  random_inst : entity work.random
    generic map (
      G_SEED => G_SEED
    )
    port map (
      clk_i    => clk_i,
      rst_i    => rst_i,
      update_i => '1',
      output_o => random_s
    ); -- random_inst : entity work.random

  -- do_write / do_read each fire with ~1/4 probability per cycle (top bit of the random
  -- word selects 'fire'; bit 0 selects write vs. read);
  -- do_abort fires with 1/128 probability (AND of 7 bits) when G_DO_ABORT = true.
  do_read  <= random_s(C_RANDOM_SIZE - 1) and random_s(0) and not rst_i;
  do_write <= random_s(C_RANDOM_SIZE - 1) and not random_s(0) and not rst_i;
  do_abort <= and(random_s(R_ABORT)) when G_DO_ABORT else
              '0';

  -- writes append to address wr_ptr with data addr_to_data(wr_ptr); reads from address
  -- rd_ptr (with rd_ptr < wr_ptr) must return addr_to_data(rd_ptr). End of test is when
  -- the writer wraps.
  wbus_proc : process (clk_i)
    --

    procedure issue_write (
      signal addr : in std_logic_vector
    ) is
      variable sel_v : std_logic_vector(C_SEL_BITS - 1 downto 0);
    begin
      sel_v := (others => '1');
      if G_RANDOM_SEL then
        sel_v := random_s(R_SEL);
        if sel_v = 0 then
          sel_v(0) := '1';
        end if;
      end if;
      m_cyc_o                     <= '1';
      m_stb_o                     <= '1';
      m_addr_o                    <= addr;
      m_we_o                      <= '1';
      m_wrdat_o                   <= sel_data(addr_to_data(addr), sel_v);
      m_sel_o                     <= sel_v;
      sel_mem(to_integer(addr))   <= sel_v;
      if G_DEBUG then
        report C_REP_STR &
               ": Write to address " & to_hstring(addr) &
               " with data " & to_hstring(sel_data(addr_to_data(addr), sel_v)) &
               " sel " & to_hstring(sel_v);
      end if;
    end procedure issue_write;

    -- Verify read data: selected lanes of the last write must hold the expected
    -- data, and the other lanes must not hold the garbage written to them.
    procedure verify_read (
      signal addr : in std_logic_vector;
      data        : std_logic_vector
    ) is
      variable exp_v : std_logic_vector(G_DATA_BITS - 1 downto 0);
      variable sel_v : std_logic_vector(C_SEL_BITS - 1 downto 0);
    begin
      exp_v := addr_to_data(addr);
      sel_v := sel_mem(to_integer(addr));
      for i in 0 to C_SEL_BITS - 1 loop
        if sel_v(i) = '1' then
          assert data(8 * i + 7 downto 8 * i) = exp_v(8 * i + 7 downto 8 * i)
            report C_REP_STR &
                   ": Read failure from address " & to_hstring(addr) &
                   ". Got " & to_hstring(data) &
                   ", expected " & to_hstring(exp_v) &
                   " in byte lane " & integer'image(i);
        else
          assert data(8 * i + 7 downto 8 * i) /= garbage_byte(exp_v(8 * i + 7 downto 8 * i))
            report C_REP_STR &
                   ": Byte lane " & integer'image(i) & " of address " & to_hstring(addr) &
                   " was written although SEL was low. Got " & to_hstring(data);
        end if;
      end loop;
    end procedure verify_read;

    procedure issue_read (
      signal addr : in std_logic_vector
    ) is
    begin
      m_cyc_o   <= '1';
      m_stb_o   <= '1';
      m_addr_o  <= addr;
      m_we_o    <= '0';
      m_wrdat_o <= (others => '0');
      m_sel_o   <= (others => '1');
      if G_DEBUG then
        report C_REP_STR &
               ": Read from address " & to_hstring(addr);
      end if;
    end procedure issue_read;

  begin
    if rising_edge(clk_i) then
      if m_stall_i = '0' then
        m_stb_o   <= '0';
        m_addr_o  <= (others => '0');
        m_we_o    <= '0';
        m_wrdat_o <= (others => '0');
        m_sel_o   <= (others => '0');
      end if;

      if m_ack_i = '1' then
        m_cyc_o <= '0';
      end if;

      case state is

        when IDLE_ST =>
          assert req_active = '0';
          if do_write = '1' then
            if wr_ptr + 1 = 0 then
              state <= DONE_ST;
            else
              issue_write(wr_ptr);
              state <= WRITING_ST;
            end if;
          elsif do_read = '1' and rd_ptr < wr_ptr then
            issue_read(rd_ptr);
            state <= READING_ST;
          end if;

        when WRITING_ST =>
          if m_ack_i = '1' then
            wr_ptr <= wr_ptr + 1;

            if do_write = '1' then
              -- address-space-wraparound termination condition
              if wr_ptr + 1 = 0 then
                state <= DONE_ST;
              else
                issue_write(wr_ptr_next);
                state <= WRITING_ST;
              end if;
            elsif do_read = '1' and rd_ptr < wr_ptr + 1 then
              issue_read(rd_ptr);
              state <= READING_ST;
            else
              state <= IDLE_ST;
            end if;
          end if;

        when READING_ST =>
          if m_ack_i = '1' then
            verify_read(rd_ptr, m_rddat_i);
            rd_ptr <= rd_ptr + 1;

            if do_write = '1' then
              if wr_ptr + 1 = 0 then
                state <= DONE_ST;
              else
                issue_write(wr_ptr);
                state <= WRITING_ST;
              end if;
            elsif do_read = '1' and rd_ptr + 1 < wr_ptr then
              issue_read(rd_ptr_next);
              state <= READING_ST;
            else
              state <= IDLE_ST;
            end if;
          end if;

        when DONE_ST =>
          report C_REP_STR & ": Done";
          stop;

      end case;

      if do_abort = '1' then
        m_cyc_o <= '0';
        state   <= IDLE_ST;
      end if;

      if rst_i = '1' then
        m_cyc_o <= '0';
        m_stb_o <= '0';
        wr_ptr  <= (others => '0');
        rd_ptr  <= (others => '0');
        state   <= IDLE_ST;
      end if;
    end if;
  end process wbus_proc;


  -- At any time, at most one Wishbone request is outstanding.
  assert_proc : process (clk_i)
  begin
    if rising_edge(clk_i) then
      if m_cyc_o = '1' and m_stall_i = '0' and m_stb_o = '1' then
        assert req_active = '0'
          report C_REP_STR & ": Master started a new request before previous one was acked";
        req_active <= '1';
      end if;

      if m_cyc_o = '1' and m_ack_i = '1' then
        assert req_active = '1' or m_stall_i = '1'
          report C_REP_STR & ": Slave acked a request that wasn't outstanding";
        req_active <= '0';
      end if;

      if rst_i = '1' or m_cyc_o = '0' or do_abort = '1' then
        req_active <= '0';
      end if;
    end if;
  end process assert_proc;

  timeout_gen : if G_TIMEOUT_MAX > 0 generate

    timeout_proc : process (clk_i)
    begin
      if rising_edge(clk_i) then
        assert timeout_cnt < G_TIMEOUT_MAX or rst_i = '1'
          report C_REP_STR & ": Timeout waiting for response"
          severity failure;

        if req_active = '1' then
          timeout_cnt <= timeout_cnt + 1;
        else
          timeout_cnt <= 0;
        end if;

        if rst_i = '1' then
          timeout_cnt <= 0;
        end if;
      end if;
    end process timeout_proc;

  end generate timeout_gen;

end architecture simulation;

