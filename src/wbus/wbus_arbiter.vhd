-- ---------------------------------------------------------------------------------------
-- Description: Arbitrate between two different Wishbone masters
-- ---------------------------------------------------------------------------------------

library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std.all;

library work;
  use work.wbus_pkg.all;

entity wbus_arbiter is
  port (
    clk_i   : in    std_logic;
    rst_i   : in    std_logic;
    s0_wbus : view  wbus_slave_view;
    s1_wbus : view  wbus_slave_view;
    m_wbus  : view  wbus_master_view
  );
end entity wbus_arbiter;

architecture synthesis of wbus_arbiter is

  type   state_type is (INPUT_0_IDLE_ST, INPUT_1_IDLE_ST, INPUT_0_BUSY_ST, INPUT_1_BUSY_ST);
  signal state : state_type := INPUT_0_IDLE_ST;

begin

  s0_wbus.stall <= '0' when state = INPUT_0_IDLE_ST else
                   '1';
  s1_wbus.stall <= '0' when state = INPUT_1_IDLE_ST else
                   '1';

  fsm_proc : process (clk_i)
  begin
    if rising_edge(clk_i) then
      if m_wbus.ack = '1' then
        m_wbus.cyc <= '0';
      end if;
      if m_wbus.stall = '0' then
        m_wbus.stb <= '0';
      end if;

      s0_wbus.ack <= '0';
      s1_wbus.ack <= '0';

      case state is

        when INPUT_0_IDLE_ST =>
          -- Validate invariant
          f_slave0 : assert (m_wbus.cyc = '0' and m_wbus.stb = '0') or rst_i = '1';

          if s0_wbus.cyc = '0' and s1_wbus.cyc = '1' then
            state <= INPUT_1_IDLE_ST;
          elsif s0_wbus.cyc = '1' and s0_wbus.stb = '1' then
            m_wbus.cyc   <= s0_wbus.cyc;
            m_wbus.stb   <= s0_wbus.stb;
            m_wbus.addr  <= s0_wbus.addr;
            m_wbus.we    <= s0_wbus.we;
            m_wbus.wrdat <= s0_wbus.wrdat;
            state        <= INPUT_0_BUSY_ST;
          end if;

        when INPUT_1_IDLE_ST =>
          -- Validate invariant
          f_slave1 : assert (m_wbus.cyc = '0' and m_wbus.stb = '0') or rst_i = '1';

          if s0_wbus.cyc = '1' and s1_wbus.cyc = '0' then
            state <= INPUT_0_IDLE_ST;
          elsif s1_wbus.cyc = '1' and s1_wbus.stb = '1' then
            m_wbus.cyc   <= s1_wbus.cyc;
            m_wbus.stb   <= s1_wbus.stb;
            m_wbus.addr  <= s1_wbus.addr;
            m_wbus.we    <= s1_wbus.we;
            m_wbus.wrdat <= s1_wbus.wrdat;
            state        <= INPUT_1_BUSY_ST;
          end if;

        when INPUT_0_BUSY_ST =>
          if m_wbus.ack = '1' then
            s0_wbus.ack   <= '1';
            s0_wbus.rddat <= m_wbus.rddat;
            state         <= INPUT_1_IDLE_ST;
          end if;
          if s0_wbus.cyc = '0' then
            m_wbus.cyc  <= '0';
            m_wbus.stb  <= '0';
            s0_wbus.ack <= '0';
            state       <= INPUT_1_IDLE_ST;
          end if;

        when INPUT_1_BUSY_ST =>
          if m_wbus.ack = '1' then
            s1_wbus.ack   <= '1';
            s1_wbus.rddat <= m_wbus.rddat;
            state         <= INPUT_0_IDLE_ST;
          end if;
          if s1_wbus.cyc = '0' then
            m_wbus.cyc  <= '0';
            m_wbus.stb  <= '0';
            s1_wbus.ack <= '0';
            state       <= INPUT_0_IDLE_ST;
          end if;

      end case;

      if rst_i = '1' then
        m_wbus.cyc  <= '0';
        m_wbus.stb  <= '0';
        s0_wbus.ack <= '0';
        s1_wbus.ack <= '0';
        state       <= INPUT_0_IDLE_ST;
      end if;
    end if;
  end process fsm_proc;

end architecture synthesis;

