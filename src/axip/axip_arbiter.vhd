-- ---------------------------------------------------------------------------------------
-- Description: Arbitrate between two different AXI masters If both Masters request
-- simultaneously, then they are granted access alternately.
-- ---------------------------------------------------------------------------------------

library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std.all;

library work;
  use work.axip_pkg.all;

entity axip_arbiter is
  port (
    clk_i   : in    std_logic;
    rst_i   : in    std_logic;
    s0_axip : view axip_slave_view;
    s1_axip : view axip_slave_view;
    m_axip  : view axip_master_view
  );
end entity axip_arbiter;

architecture synthesis of axip_arbiter is

  -- The state determines which Master is granted access.
  -- Note: Only one Master may be granted access at a time.
  -- If both Masters need to deliver data simultaneously then
  -- additional FIFOs can be inserted before this arbiter.

  type   state_type is (MASTER_0_ST, MASTER_1_ST);
  signal state : state_type := MASTER_0_ST;

begin

  -- Data is accepted only when we can process it, i.e. when m_valid_o is 0 or will be set
  -- to zero in this clock cycle.
  s0_axip.ready <= (m_axip.ready or not m_axip.valid) when state = MASTER_0_ST else
                   '0';
  s1_axip.ready <= (m_axip.ready or not m_axip.valid) when state = MASTER_1_ST else
                   '0';

  fsm_proc : process (clk_i)
  begin
    if rising_edge(clk_i) then
      -- The slave has accepted our data.
      if m_axip.ready = '1' then
        m_axip.valid <= '0';
      end if;

      case state is

        when MASTER_0_ST =>
          -- Accept data from Master 0
          if s0_axip.valid = '1' and s0_axip.ready = '1' then
            m_axip.valid <= '1';
            m_axip.data  <= s0_axip.data;
            m_axip.last  <= s0_axip.last;
            m_axip.bytes <= s0_axip.bytes;

            if s1_axip.valid = '1' and s0_axip.last = '1' then
              state <= MASTER_1_ST;
            end if;
          end if;

          -- Grant access to Master 1 on next clock cycle, if requested
          if s0_axip.valid = '0' and s1_axip.valid = '1' and m_axip.last = '1' then
            state <= MASTER_1_ST;
          end if;

        when MASTER_1_ST =>
          -- Accept data from Master 1
          if s1_axip.valid = '1' and s1_axip.ready = '1' then
            m_axip.valid <= '1';
            m_axip.data  <= s1_axip.data;
            m_axip.last  <= s1_axip.last;
            m_axip.bytes <= s1_axip.bytes;

            if s0_axip.valid = '1' and s1_axip.last = '1' then
              state <= MASTER_0_ST;
            end if;
          end if;

          -- Grant access to Master 0 on next clock cycle, if requested
          if s0_axip.valid = '1' and s1_axip.valid = '0' and m_axip.last = '1' then
            state <= MASTER_0_ST;
          end if;

      end case;

      if rst_i = '1' then
        m_axip.valid <= '0';
        m_axip.last  <= '1';
        state        <= MASTER_0_ST;
      end if;
    end if;
  end process fsm_proc;

end architecture synthesis;

