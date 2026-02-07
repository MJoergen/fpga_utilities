-- ---------------------------------------------------------------------------------------
-- Description: Arbitrate between two different AXI Streams.  The arbitration is
-- round-robin, so if both inputs want to forward data, then they are alternately granted
-- access.
-- ---------------------------------------------------------------------------------------

library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std.all;

library work;
  use work.axis_pkg.all;

entity axis_arbiter is
  port (
    clk_i   : in    std_logic;
    rst_i   : in    std_logic;
    s0_axis : view  axis_slave_view;
    s1_axis : view  axis_slave_view;
    m_axis  : view  axis_master_view
  );
end entity axis_arbiter;

architecture synthesis of axis_arbiter is

  type   state_type is (INPUT_0_ST, INPUT_1_ST);
  signal state : state_type := INPUT_0_ST;

begin

  s0_axis.ready <= (m_axis.ready or not m_axis.valid) when state = INPUT_0_ST else
                   '0';
  s1_axis.ready <= (m_axis.ready or not m_axis.valid) when state = INPUT_1_ST else
                   '0';

  fsm_proc : process (clk_i)
  begin
    if rising_edge(clk_i) then
      if m_axis.ready = '1' then
        m_axis.valid <= '0';
      end if;

      case state is

        when INPUT_0_ST =>
          if s0_axis.valid = '1' and s0_axis.ready = '1' then
            m_axis.data  <= s0_axis.data;
            m_axis.valid <= '1';
          end if;

          if s1_axis.valid = '1' then
            state <= INPUT_1_ST;
          end if;

        when INPUT_1_ST =>
          if s1_axis.valid = '1' and s1_axis.ready = '1' then
            m_axis.data  <= s1_axis.data;
            m_axis.valid <= '1';
          end if;

          if s0_axis.valid = '1' then
            state <= INPUT_0_ST;
          end if;

      end case;

      if rst_i = '1' then
        m_axis.valid <= '0';
        state        <= INPUT_0_ST;
      end if;
    end if;
  end process fsm_proc;

end architecture synthesis;

