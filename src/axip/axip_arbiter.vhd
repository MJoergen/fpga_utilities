-- ---------------------------------------------------------------------------------------
-- Description: Arbitrate between two different AXI masters If both Masters request
-- simultaneously, then they are granted access alternately.
--
-- s?_bytes_i is only valid when s?_last_i is 1.
-- m_bytes_o is only valid when m_last_o is 1.
--
-- SPDX-License-Identifier: MIT
-- ---------------------------------------------------------------------------------------

library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std.all;

entity axip_arbiter is
  generic (
    G_DATA_BYTES : positive
  );
  port (
    clk_i      : in    std_logic;
    rst_i      : in    std_logic;

    s0_ready_o : out   std_logic;
    s0_valid_i : in    std_logic;
    s0_data_i  : in    std_logic_vector(G_DATA_BYTES * 8 - 1 downto 0);
    s0_last_i  : in    std_logic;
    s0_bytes_i : in    natural range 0 to G_DATA_BYTES;

    s1_ready_o : out   std_logic;
    s1_valid_i : in    std_logic;
    s1_data_i  : in    std_logic_vector(G_DATA_BYTES * 8 - 1 downto 0);
    s1_last_i  : in    std_logic;
    s1_bytes_i : in    natural range 0 to G_DATA_BYTES;

    m_ready_i  : in    std_logic;
    m_valid_o  : out   std_logic;
    m_data_o   : out   std_logic_vector(G_DATA_BYTES * 8 - 1 downto 0);
    m_last_o   : out   std_logic;
    m_bytes_o  : out   natural range 0 to G_DATA_BYTES
  );
end entity axip_arbiter;

architecture rtl of axip_arbiter is

  -- The state determines which Master is granted access.
  -- Note: Only one Master may be granted access at a time.
  -- If both Masters need to deliver data simultaneously then
  -- additional FIFOs can be inserted before this arbiter.

  type   state_type is (S0_ST, S1_ST);
  signal state : state_type := S0_ST;

begin

  -- Data is accepted only when we can process it, i.e. when m_valid_o is 0 or will be set
  -- to zero in this clock cycle.
  s0_ready_o <= (m_ready_i or not m_valid_o) when state = S0_ST else
                '0';
  s1_ready_o <= (m_ready_i or not m_valid_o) when state = S1_ST else
                '0';

  fsm_proc : process (clk_i)
  begin
    if rising_edge(clk_i) then
      -- The slave has accepted our data.
      if m_ready_i = '1' then
        m_valid_o <= '0';
      end if;

      case state is

        when S0_ST =>
          -- Accept data from Master 0
          if s0_valid_i = '1' and s0_ready_o = '1' then
            m_valid_o <= '1';
            m_data_o  <= s0_data_i;
            m_last_o  <= s0_last_i;
            m_bytes_o <= s0_bytes_i;

            if s1_valid_i = '1' and s0_last_i = '1' then
              state <= S1_ST;
            end if;
          end if;

          -- Grant access to Master 1 on next clock cycle, if requested
          if s0_valid_i = '0' and s1_valid_i = '1' and m_last_o = '1' then
            state <= S1_ST;
          end if;

        when S1_ST =>
          -- Accept data from Master 1
          if s1_valid_i = '1' and s1_ready_o = '1' then
            m_valid_o <= '1';
            m_data_o  <= s1_data_i;
            m_last_o  <= s1_last_i;
            m_bytes_o <= s1_bytes_i;

            if s0_valid_i = '1' and s1_last_i = '1' then
              state <= S0_ST;
            end if;
          end if;

          -- Grant access to Master 0 on next clock cycle, if requested
          if s0_valid_i = '1' and s1_valid_i = '0' and m_last_o = '1' then
            state <= S0_ST;
          end if;

      end case;

      if rst_i = '1' then
        m_valid_o <= '0';
        m_last_o  <= '1';
        state     <= S0_ST;
      end if;
    end if;
  end process fsm_proc;

end architecture rtl;

