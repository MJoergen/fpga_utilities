-- ---------------------------------------------------------------------------------------
-- Description: Arbitrate between two different AXI Streams.  The arbitration is
-- round-robin, so if both inputs want to forward data, then they are alternately granted
-- access.
-- ---------------------------------------------------------------------------------------

library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std.all;

entity axis_arbiter is
  generic (
    G_DATA_SIZE : positive
  );
  port (
    clk_i      : in    std_logic;
    rst_i      : in    std_logic;

    -- AXI stream input interface #0
    s0_ready_o : out   std_logic;
    s0_valid_i : in    std_logic;
    s0_data_i  : in    std_logic_vector(G_DATA_SIZE - 1 downto 0);

    -- AXI stream input interface #1
    s1_ready_o : out   std_logic;
    s1_valid_i : in    std_logic;
    s1_data_i  : in    std_logic_vector(G_DATA_SIZE - 1 downto 0);

    -- AXI stream output interface
    m_ready_i  : in    std_logic;
    m_valid_o  : out   std_logic;
    m_data_o   : out   std_logic_vector(G_DATA_SIZE - 1 downto 0)
  );
end entity axis_arbiter;

architecture synthesis of axis_arbiter is

  type   state_type is (INPUT_0_ST, INPUT_1_ST);
  signal state : state_type := INPUT_0_ST;

begin

  s0_ready_o <= (m_ready_i or not m_valid_o) when state = INPUT_0_ST else
                '0';
  s1_ready_o <= (m_ready_i or not m_valid_o) when state = INPUT_1_ST else
                '0';

  fsm_proc : process (clk_i)
  begin
    if rising_edge(clk_i) then
      if m_ready_i = '1' then
        m_valid_o <= '0';
      end if;

      case state is

        when INPUT_0_ST =>
          if s0_valid_i = '1' and s0_ready_o = '1' then
            m_data_o  <= s0_data_i;
            m_valid_o <= '1';
          end if;

          if s1_valid_i = '1' then
            state <= INPUT_1_ST;
          end if;

        when INPUT_1_ST =>
          if s1_valid_i = '1' and s1_ready_o = '1' then
            m_data_o  <= s1_data_i;
            m_valid_o <= '1';
          end if;

          if s0_valid_i = '1' then
            state <= INPUT_0_ST;
          end if;

      end case;

      if rst_i = '1' then
        m_valid_o <= '0';
        state     <= INPUT_0_ST;
      end if;
    end if;
  end process fsm_proc;

end architecture synthesis;

