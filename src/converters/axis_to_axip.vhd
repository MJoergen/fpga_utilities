-- ---------------------------------------------------------------------------------------
-- Description: This module converts a stream of bytes into a wider bus interface.  The
-- first byte received is placed in MSB, i.e.  m_data_o(G_DATA_BYTES*8-1 downto
-- G_DATA_BYTES*8-8);
-- ---------------------------------------------------------------------------------------

library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std_unsigned.all;

entity axis_to_axip is
  generic (
    G_DATA_BYTES : positive
  );
  port (
    clk_i     : in    std_logic;
    rst_i     : in    std_logic;

    -- AXI stream input
    s_ready_o : out   std_logic;
    s_valid_i : in    std_logic;
    s_data_i  : in    std_logic_vector(7 downto 0);
    s_last_i  : in    std_logic;

    -- AXI packet output
    m_ready_i : in    std_logic;
    m_valid_o : out   std_logic;
    m_data_o  : out   std_logic_vector(G_DATA_BYTES * 8 - 1 downto 0);
    m_last_o  : out   std_logic;
    m_bytes_o : out   natural range 0 to G_DATA_BYTES
  );
end entity axis_to_axip;

architecture synthesis of axis_to_axip is

  type     state_type is (IDLE_ST, FWD_ST);
  signal   state : state_type                                          := IDLE_ST;

  constant C_PADDING : std_logic_vector(G_DATA_BYTES * 8 - 9 downto 0) := (others => '0');

begin

  s_ready_o <= m_ready_i or not m_valid_o;

  fsm_proc : process (clk_i)
  begin
    if rising_edge(clk_i) then
      if m_ready_i = '1' then
        m_valid_o <= '0';
      end if;

      case state is

        when IDLE_ST =>
          if s_valid_i = '1' and s_ready_o = '1' then
            m_valid_o <= '0';
            -- Write first byte to MSB.
            m_data_o  <= s_data_i & C_PADDING;
            m_last_o  <= '0';
            -- Number of bytes written so far.
            m_bytes_o <= 1;
            state     <= FWD_ST;

            -- Forward last chunk.
            if s_last_i = '1' then
              m_valid_o <= '1';
              m_last_o  <= '1';
              state     <= IDLE_ST;
            end if;
          end if;

        when FWD_ST =>
          if s_valid_i = '1' and s_ready_o = '1' then
            -- Write next byte
            if m_bytes_o = G_DATA_BYTES then
              m_data_o  <= s_data_i & C_PADDING;
              m_bytes_o <= 1;
            else
              m_data_o(G_DATA_BYTES * 8 - 1 - m_bytes_o * 8 downto G_DATA_BYTES * 8 - 8 - m_bytes_o * 8) <= s_data_i;
              m_bytes_o                                                                                  <= m_bytes_o + 1;
            end if;

            -- If G_DATA_BYTES received, forward them.
            if m_bytes_o = G_DATA_BYTES - 1 then
              m_valid_o <= '1';
            end if;

            -- Forward last chunk.
            if s_last_i = '1' then
              m_valid_o <= '1';
              m_last_o  <= '1';
              state     <= IDLE_ST;
            end if;
          end if;

      end case;

      if rst_i = '1' then
        m_valid_o <= '0';
        state     <= IDLE_ST;
      end if;
    end if;
  end process fsm_proc;

end architecture synthesis;

