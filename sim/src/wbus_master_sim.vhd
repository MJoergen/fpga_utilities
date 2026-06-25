-- ---------------------------------------------------------------------------------------
-- Description: This simulates a Wishbone Master.  It generates a sequence of Writes and
-- Reads, and verifies that the values returned from Read matches the corresponding values
-- during Write.
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

begin

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
    begin
      m_cyc_o   <= '1';
      m_stb_o   <= '1';
      m_addr_o  <= addr;
      m_we_o    <= '1';
      m_wrdat_o <= addr_to_data(addr);
      m_sel_o   <= (others => '1');
      if G_DEBUG then
        report C_REP_STR &
               ": Write to address " & to_hstring(addr) &
               " with data " & to_hstring(addr_to_data(addr));
      end if;
    end procedure issue_write;

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
            assert m_rddat_i = addr_to_data(rd_ptr)
              report C_REP_STR &
                     ": Read failure from address " & to_hstring(rd_ptr) &
                     ". Got " & to_hstring(m_rddat_i) &
                     ", expected " & to_hstring(addr_to_data(rd_ptr));
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

