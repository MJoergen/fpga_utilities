-- ----------------------------------------------------------------------------
-- Author     : Michael Jørgensen
-- Platform   : AMD Artix 7
-- ----------------------------------------------------------------------------
-- Description:
-- This module generates a stream of bytes from a wider bus interface.
-- The first byte sent is read from MSB, i.e. s_data_o(G_DATA_BYTES*8-1 downto G_DATA_BYTES*8-8);
-- ----------------------------------------------------------------------------

library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std.all;

entity axip_to_axis is
  generic (
    G_DATA_BYTES : natural
  );
  port (
    clk_i     : in    std_logic;
    rst_i     : in    std_logic;

    -- Input interface (wide data bus).
    s_ready_o : out   std_logic;
    s_valid_i : in    std_logic;
    s_data_i  : in    std_logic_vector(G_DATA_BYTES * 8 - 1 downto 0);
    s_last_i  : in    std_logic;
    s_bytes_i : in    natural range 0 to G_DATA_BYTES;          -- Only used when s_last_i is asserted.

    -- Output interface (byte data bus).
    m_ready_i : in    std_logic;
    m_valid_o : out   std_logic;
    m_data_o  : out   std_logic_vector(7 downto 0);
    m_last_o  : out   std_logic
  );
end entity axip_to_axis;

architecture synthesis of axip_to_axis is

  type   state_type is (IDLE_ST, FWD_ST);
  signal state : state_type := IDLE_ST;

  signal s_data  : std_logic_vector(G_DATA_BYTES * 8 - 1 downto 0);
  signal s_last  : std_logic;
  signal s_bytes : natural range 0 to G_DATA_BYTES;

begin

  s_ready_o <= '1' when state = IDLE_ST else
               '0';

  fsm_proc : process (clk_i)
  begin
    if rising_edge(clk_i) then
      if m_ready_i = '1' then
        m_valid_o <= '0';
        m_last_o  <= '0';
      end if;

      case state is

        when IDLE_ST =>
          if s_valid_i = '1' then
            s_last  <= s_last_i;
            s_bytes <= s_bytes_i;
            s_data  <= s_data_i;
            if s_last_i = '0' then
              s_bytes <= 0;
            end if;
            state <= FWD_ST;
          end if;

        when FWD_ST =>
          if m_ready_i = '1' then
            m_valid_o <= '1';
            m_last_o  <= '0';
            m_data_o  <= s_data(G_DATA_BYTES * 8 - 1 downto G_DATA_BYTES * 8 - 8);
            if s_bytes = 1 then
              m_last_o <= s_last;
              state    <= IDLE_ST;
            else
              s_data <= s_data(G_DATA_BYTES * 8 - 9 downto 0) & x"00";
              if s_bytes > 0 then
                s_bytes <= s_bytes - 1;
              else
                s_bytes <= G_DATA_BYTES - 1;
              end if;
            end if;
          end if;

      end case;

      if rst_i = '1' then
        m_valid_o <= '0';
        m_last_o  <= '0';
        state     <= IDLE_ST;
      end if;
    end if;
  end process fsm_proc;

end architecture synthesis;

