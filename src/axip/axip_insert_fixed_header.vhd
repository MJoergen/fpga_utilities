-- ----------------------------------------------------------------------------
-- Author     : Michael Jørgensen
-- Platform   : AMD Artix 7
-- ----------------------------------------------------------------------------
-- Description:
-- This takes an AXI packet stream as input, and inserts a fixed-size header to the start of the packet.
-- First byte is in the left-most (MSB) position.
-- s_bytes_i is only valid when s_last_i is 1.
-- m_bytes_o is only valid when m_last_o is 1.
-- ----------------------------------------------------------------------------

library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std.all;

entity axip_insert_fixed_header is
  generic (
    G_DATA_BYTES   : natural;
    G_HEADER_BYTES : natural
  );
  port (
    clk_i     : in    std_logic;
    rst_i     : in    std_logic;

    h_ready_o : out   std_logic;
    h_valid_i : in    std_logic;
    h_data_i  : in    std_logic_vector(G_HEADER_BYTES * 8 - 1 downto 0);

    s_ready_o : out   std_logic;
    s_valid_i : in    std_logic;
    s_data_i  : in    std_logic_vector(G_DATA_BYTES * 8 - 1 downto 0);
    s_last_i  : in    std_logic;
    s_bytes_i : in    natural range 0 to G_DATA_BYTES;

    m_ready_i : in    std_logic;
    m_valid_o : out   std_logic;
    m_data_o  : out   std_logic_vector(G_DATA_BYTES * 8 - 1 downto 0);
    m_last_o  : out   std_logic;
    m_bytes_o : out   natural range 0 to G_DATA_BYTES
  );
end entity axip_insert_fixed_header;

architecture synthesis of axip_insert_fixed_header is

  type   state_type is (IDLE_ST, WAIT_HEADER_ST, WAIT_DATA_ST, BUSY_ST, LAST_ST);
  signal state : state_type := IDLE_ST;

  signal h_data  : std_logic_vector(G_HEADER_BYTES * 8 - 1 downto 0);
  signal s_data  : std_logic_vector(G_DATA_BYTES * 8 - 1 downto 0);
  signal s_last  : std_logic;
  signal s_bytes : natural range 0 to G_DATA_BYTES;

begin

  s_ready_o <= (m_ready_i or not m_valid_o) when state = IDLE_ST or state = WAIT_DATA_ST or state = BUSY_ST else
               '0';
  h_ready_o <= (m_ready_i or not m_valid_o) when state = IDLE_ST or state = WAIT_HEADER_ST else
               '0';

  state_proc : process (clk_i)
  begin
    if rising_edge(clk_i) then
      if m_ready_i = '1' then
        m_valid_o <= '0';
        m_last_o  <= '0';
        m_bytes_o <= 0;
      end if;

      case state is

        when IDLE_ST =>
          if s_valid_i = '1' and s_ready_o = '1' and h_valid_i = '1' and h_ready_o = '1' then
            s_data    <= s_data_i;
            s_last    <= s_last_i;
            s_bytes   <= s_bytes_i;
            m_valid_o <= '1';
            m_data_o  <= h_data_i & s_data_i(G_DATA_BYTES * 8 - 1 downto G_HEADER_BYTES * 8);
            m_last_o  <= '0';
            m_bytes_o <= G_DATA_BYTES;
            state     <= BUSY_ST;
            if s_last_i = '1' then
              if s_bytes_i > G_DATA_BYTES - G_HEADER_BYTES then
                state     <= LAST_ST;
              else
                m_last_o  <= '1';
                m_bytes_o <= s_bytes_i + G_HEADER_BYTES;
                state     <= IDLE_ST;
              end if;
            end if;
          elsif s_valid_i = '1' and s_ready_o = '1' then
            s_data  <= s_data_i;
            s_last  <= s_last_i;
            s_bytes <= s_bytes_i;
            state   <= WAIT_HEADER_ST;
          elsif h_valid_i = '1' and h_ready_o = '1' then
            h_data  <= h_data_i;
            state   <= WAIT_DATA_ST;
          end if;

        when WAIT_HEADER_ST =>
          if h_valid_i = '1' and h_ready_o = '1' then
            m_valid_o <= '1';
            m_data_o  <= h_data_i & s_data(G_DATA_BYTES * 8 - 1 downto G_HEADER_BYTES * 8);
            m_last_o  <= '0';
            m_bytes_o <= G_DATA_BYTES;
            state     <= BUSY_ST;
            if s_last = '1' then
              if s_bytes > G_DATA_BYTES - G_HEADER_BYTES then
                state     <= LAST_ST;
              else
                m_last_o  <= '1';
                m_bytes_o <= s_bytes + G_HEADER_BYTES;
                state     <= IDLE_ST;
              end if;
            end if;
          end if;

        when WAIT_DATA_ST =>
          if s_valid_i = '1' and s_ready_o = '1' then
            s_data    <= s_data_i;
            s_last    <= s_last_i;
            s_bytes   <= s_bytes_i;
            m_valid_o <= '1';
            m_data_o  <= h_data & s_data_i(G_DATA_BYTES * 8 - 1 downto G_HEADER_BYTES * 8);
            m_last_o  <= '0';
            m_bytes_o <= G_DATA_BYTES;
            state     <= BUSY_ST;
            if s_last_i = '1' then
              if s_bytes_i > G_DATA_BYTES - G_HEADER_BYTES then
                state     <= LAST_ST;
              else
                m_last_o  <= '1';
                m_bytes_o <= s_bytes_i + G_HEADER_BYTES;
                state     <= IDLE_ST;
              end if;
            end if;
          end if;

        when BUSY_ST =>
          if s_valid_i = '1' and s_ready_o = '1' then
            s_data    <= s_data_i;
            s_bytes   <= s_bytes_i;
            m_valid_o <= '1';
            m_data_o  <= s_data(G_HEADER_BYTES * 8 - 1 downto 0) & s_data_i(G_DATA_BYTES * 8 - 1 downto G_HEADER_BYTES * 8);
            m_last_o  <= '0';
            m_bytes_o <= G_DATA_BYTES;
            if s_last_i = '1' then
              if s_bytes_i > G_DATA_BYTES - G_HEADER_BYTES then
                state <= LAST_ST;
              else
                m_last_o  <= '1';
                m_bytes_o <= s_bytes_i + G_HEADER_BYTES;
                state     <= IDLE_ST;
              end if;
            end if;
          end if;

        when LAST_ST =>
          if m_ready_i or not m_valid_o then
            m_valid_o <= '1';
            m_data_o  <= s_data(G_HEADER_BYTES * 8 - 1 downto 0) & s_data_i(G_DATA_BYTES * 8 - 1 downto G_HEADER_BYTES * 8);
            m_last_o  <= '1';
            m_bytes_o <= s_bytes - (G_DATA_BYTES - G_HEADER_BYTES);
            state     <= IDLE_ST;
          end if;

      end case;

      if rst_i = '1' then
        m_valid_o <= '0';
        m_data_o  <= (others => '0');
        m_last_o  <= '0';
        m_bytes_o <= 0;
        state     <= IDLE_ST;
      end if;
    end if;
  end process state_proc;

end architecture synthesis;

