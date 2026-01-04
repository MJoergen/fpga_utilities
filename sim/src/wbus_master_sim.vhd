-- ----------------------------------------------------------------------------
-- Author     : Michael Jørgensen
-- Platform   : simulation
-- ----------------------------------------------------------------------------
-- Description:
-- This simulates a Wishbone Master.
-- It generates a sequence of Writes and Reads, and verifies that the values
-- returned from Read matches the corresponding values during Write.
-- ----------------------------------------------------------------------------

library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std_unsigned.all;
  use std.env.stop;

entity wbus_master_sim is
  generic (
    G_SEED        : std_logic_vector(63 downto 0) := X"DEADBEEFC007BABE";
    G_NAME        : string                        := "";
    G_TIMEOUT_MAX : natural                       := 200;
    G_DEBUG       : boolean                       := false;
    G_DO_ABORT    : boolean                       := false;
    G_OFFSET      : natural;
    G_ADDR_SIZE   : natural;
    G_DATA_SIZE   : natural
  );
  port (
    clk_i          : in    std_logic;
    rst_i          : in    std_logic;
    m_wbus_cyc_o   : out   std_logic;                                  -- Valid bus cycle
    m_wbus_stall_i : in    std_logic;
    m_wbus_stb_o   : out   std_logic;                                  -- Strobe signals / core select signal
    m_wbus_addr_o  : out   std_logic_vector(G_ADDR_SIZE - 1 downto 0); -- lower address bits
    m_wbus_we_o    : out   std_logic;                                  -- Write enable
    m_wbus_wrdat_o : out   std_logic_vector(G_DATA_SIZE - 1 downto 0); -- Write Databus
    m_wbus_ack_i   : in    std_logic;                                  -- Bus cycle acknowledge
    m_wbus_rddat_i : in    std_logic_vector(G_DATA_SIZE - 1 downto 0)  -- Read Databus
  );
end entity wbus_master_sim;

architecture simulation of wbus_master_sim is

  constant C_RANDOM_SIZE : natural := 16;
  signal   random_s      : std_logic_vector(63 downto 0);

  subtype  R_ABORT is natural range 47 downto 41;

  type     state_type is (IDLE_ST, WRITING_ST, READING_ST, DONE_ST);
  signal   state : state_type      := IDLE_ST;

  signal   wr_ptr : std_logic_vector(G_ADDR_SIZE - 1 downto 0);
  signal   rd_ptr : std_logic_vector(G_ADDR_SIZE - 1 downto 0);

  pure function addr_to_data (
    addr : std_logic_vector
  ) return std_logic_vector is
  begin
    return to_stdlogicvector(2 ** (G_DATA_SIZE - 1) + G_OFFSET - to_integer(addr), G_DATA_SIZE);
  end function addr_to_data;

  signal   do_read  : std_logic;
  signal   do_write : std_logic;
  signal   do_abort : std_logic;

  signal   req_active  : std_logic := '0';
  signal   timeout_cnt : natural range 0 to G_TIMEOUT_MAX;

begin

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

  do_read  <= random_s(C_RANDOM_SIZE - 1) and random_s(0) and not rst_i;
  do_write <= random_s(C_RANDOM_SIZE - 1) and not random_s(0) and not rst_i;
  do_abort <= and(random_s(R_ABORT)) when G_DO_ABORT else
              '0';

  wbus_proc : process (clk_i)
  begin
    if rising_edge(clk_i) then
      if m_wbus_stall_i = '0' then
        m_wbus_stb_o   <= '0';
        m_wbus_addr_o  <= (others => '0');
        m_wbus_we_o    <= '0';
        m_wbus_wrdat_o <= (others => '0');
      end if;

      if m_wbus_ack_i = '1' then
        m_wbus_cyc_o <= '0';
      end if;

      case state is

        when IDLE_ST =>
          assert req_active = '0';
          if do_write = '1' then
            if wr_ptr + 1 = 0 then
              state <= DONE_ST;
            else
              m_wbus_cyc_o   <= '1';
              m_wbus_stb_o   <= '1';
              m_wbus_addr_o  <= wr_ptr;
              m_wbus_we_o    <= '1';
              m_wbus_wrdat_o <= addr_to_data(wr_ptr);
              if G_DEBUG then
                report "WBUS MASTER " & G_NAME & ": Write to address " & to_hstring(wr_ptr) & " with data " & to_hstring(addr_to_data(wr_ptr));
              end if;
              state <= WRITING_ST;
            end if;
          elsif do_read = '1' and rd_ptr < wr_ptr then
            m_wbus_cyc_o  <= '1';
            m_wbus_stb_o  <= '1';
            m_wbus_addr_o <= rd_ptr;
            m_wbus_we_o   <= '0';
            if G_DEBUG then
              report "WBUS MASTER " & G_NAME & ": Read from address " & to_hstring(rd_ptr);
            end if;
            state <= READING_ST;
          end if;

        when WRITING_ST =>
          if m_wbus_ack_i = '1' then
            wr_ptr <= wr_ptr + 1;

            if do_write = '1' then
              if wr_ptr + 1 = 0 then
                state <= DONE_ST;
              else
                m_wbus_cyc_o   <= '1';
                m_wbus_stb_o   <= '1';
                m_wbus_addr_o  <= wr_ptr + 1;
                m_wbus_we_o    <= '1';
                m_wbus_wrdat_o <= addr_to_data(wr_ptr + 1);
                if G_DEBUG then
                  report "WBUS MASTER " & G_NAME & ": Write to address " & to_hstring(wr_ptr + 1) & " with data " & to_hstring(addr_to_data(wr_ptr + 1));
                end if;
                state <= WRITING_ST;
              end if;
            elsif do_read = '1' and rd_ptr < wr_ptr + 1 then
              m_wbus_cyc_o  <= '1';
              m_wbus_stb_o  <= '1';
              m_wbus_addr_o <= rd_ptr;
              m_wbus_we_o   <= '0';
              if G_DEBUG then
                report "WBUS MASTER " & G_NAME & ": Read from address " & to_hstring(rd_ptr);
              end if;
              state <= READING_ST;
            else
              state <= IDLE_ST;
            end if;
          end if;

        when READING_ST =>
          if m_wbus_ack_i = '1' then
            assert m_wbus_rddat_i = addr_to_data(rd_ptr)
              report "WBUS MASTER " & G_NAME &
                     ": Read failure from address " & to_hstring(rd_ptr) &
                     ". Got " & to_hstring(m_wbus_rddat_i) &
                     ", expected " & to_hstring(addr_to_data(rd_ptr));
            rd_ptr <= rd_ptr + 1;

            if do_write = '1' then
              if wr_ptr + 1 = 0 then
                state <= DONE_ST;
              else
                m_wbus_cyc_o   <= '1';
                m_wbus_stb_o   <= '1';
                m_wbus_addr_o  <= wr_ptr;
                m_wbus_we_o    <= '1';
                m_wbus_wrdat_o <= addr_to_data(wr_ptr);
                if G_DEBUG then
                  report "WBUS MASTER " & G_NAME & ": Write to address " & to_hstring(wr_ptr) & " with data " & to_hstring(addr_to_data(wr_ptr));
                end if;
                state <= WRITING_ST;
              end if;
            elsif do_read = '1' and rd_ptr + 1 < wr_ptr then
              m_wbus_cyc_o  <= '1';
              m_wbus_stb_o  <= '1';
              m_wbus_addr_o <= rd_ptr + 1;
              m_wbus_we_o   <= '0';
              if G_DEBUG then
                report "WBUS MASTER " & G_NAME & ": Read from address " & to_hstring(rd_ptr + 1);
              end if;
              state <= READING_ST;
            else
              state <= IDLE_ST;
            end if;
          end if;

        when DONE_ST =>
          report "WBUS MASTER " & G_NAME & ": Done";
          stop;

      end case;

      if do_abort = '1' then
        m_wbus_cyc_o <= '0';
        state        <= IDLE_ST;
      end if;

      if rst_i = '1' then
        m_wbus_cyc_o <= '0';
        m_wbus_stb_o <= '0';
        wr_ptr       <= (others => '0');
        rd_ptr       <= (others => '0');
        state        <= IDLE_ST;
      end if;
    end if;
  end process wbus_proc;


  assert_proc : process (clk_i)
  begin
    if rising_edge(clk_i) then
      if m_wbus_cyc_o = '1' and m_wbus_stall_i = '0' and m_wbus_stb_o = '1' then
        assert req_active = '0'
          report "WBUS MASTER " & G_NAME & ": Repeated access received";
        req_active <= '1';
      end if;

      if m_wbus_cyc_o = '1' and m_wbus_ack_i = '1' then
        assert req_active = '1' or m_wbus_stall_i = '1'
          report "WBUS MASTER " & G_NAME & ": Missing access";
        req_active <= '0';
      end if;

      if rst_i = '1' or m_wbus_cyc_o = '0' or do_abort = '1' then
        req_active <= '0';
      end if;
    end if;
  end process assert_proc;

  timeout_proc : process (clk_i)
  begin
    if rising_edge(clk_i) then
      assert timeout_cnt < G_TIMEOUT_MAX
        report "WBUS MASTER " & G_NAME & ": Timeout waiting for response";

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

end architecture simulation;

