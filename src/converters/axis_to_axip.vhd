-- ----------------------------------------------------------------------------
-- Title      : Main FPGA
-- Project    : XENTA, RCU, PCB1036 Board
-- ----------------------------------------------------------------------------
-- File       : axis_to_axip.vhd
-- Author     : Michael Jørgensen
-- Company    : Weibel Scientific
-- Created    : 2025-05-19
-- Platform   : AMD Artix 7
-- ----------------------------------------------------------------------------
-- Description:
-- This module converts a stream of bytes into a wider bus interface.
-- The first byte received is placed in MSB, i.e.  m_data_o(G_DATA_BYTES*8-1 downto G_DATA_BYTES*8-8);
-- ----------------------------------------------------------------------------

library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std_unsigned.all;

entity axis_to_axip is
  generic (
    G_DATA_BYTES : natural
  );
  port (
    clk_i     : in    std_logic;
    rst_i     : in    std_logic;

    -- Input interface (byte oriented data bus).
    s_ready_o : out   std_logic;
    s_valid_i : in    std_logic;
    s_data_i  : in    std_logic_vector(7 downto 0);
    s_last_i  : in    std_logic;

    -- Output interface (wide data bus).
    m_ready_i : in    std_logic;
    m_valid_o : out   std_logic;
    m_data_o  : out   std_logic_vector(G_DATA_BYTES * 8 - 1 downto 0);
    m_last_o  : out   std_logic;
    m_bytes_o : out   natural range 0 to G_DATA_BYTES  -- Only when m_last_o is asserted.
  );
end entity axis_to_axip;

architecture synthesis of axis_to_axip is

  type   state_type is (IDLE_ST, FWD_ST);
  signal state : state_type := IDLE_ST;

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
            m_valid_o                                                  <= '0';
            m_last_o                                                   <= '0';
            m_data_o                                                   <= (others => '0');
            -- Write first byte to MSB.
            m_data_o(G_DATA_BYTES * 8 - 1 downto G_DATA_BYTES * 8 - 8) <= s_data_i;
            -- Number of bytes written so far.
            m_bytes_o                                                  <= 1;
            state                                                      <= FWD_ST;

            -- Forward last chunk.
            if s_last_i = '1' then
              m_valid_o <= '1';
              m_last_o  <= '1';
              state     <= IDLE_ST;
            end if;
          end if;

        when FWD_ST =>
          if s_valid_i = '1' and s_ready_o = '1' then
            if m_bytes_o = 0 then
              m_data_o <= (others => '0');
            end if;

            -- Write next byte
            if m_bytes_o = G_DATA_BYTES then
              m_data_o(G_DATA_BYTES * 8 - 1 downto G_DATA_BYTES * 8 - 8) <= s_data_i;
              m_bytes_o <= 1;
            else
              m_data_o(G_DATA_BYTES * 8 - 1 - m_bytes_o * 8 downto G_DATA_BYTES * 8 - 8 - m_bytes_o * 8) <= s_data_i;
              m_bytes_o <= m_bytes_o + 1;
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

