-- ----------------------------------------------------------------------------
-- Author     : Michael Jørgensen
-- Platform   : AMD Artix 7
-- ----------------------------------------------------------------------------
-- Description:
-- This takes an AXI packet stream as input, and extracts a fixed-size header from the start of the packet.
-- First byte is in the left-most (MSB) position.
-- s_bytes_i is only valid when s_last_i is 1.
-- m_bytes_o is only valid when m_last_o is 1.
-- ----------------------------------------------------------------------------

library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std.all;

entity axip_remove_fixed_header is
  generic (
    G_DATA_BYTES   : natural;
    G_HEADER_BYTES : natural
  );
  port (
    clk_i     : in    std_logic;
    rst_i     : in    std_logic;

    s_ready_o : out   std_logic;
    s_valid_i : in    std_logic;
    s_data_i  : in    std_logic_vector(G_DATA_BYTES * 8 - 1 downto 0);
    s_last_i  : in    std_logic;
    s_bytes_i : in    natural range 0 to G_DATA_BYTES;

    m_ready_i : in    std_logic;
    m_valid_o : out   std_logic;
    m_data_o  : out   std_logic_vector(G_DATA_BYTES * 8 - 1 downto 0);
    m_last_o  : out   std_logic;
    m_bytes_o : out   natural range 0 to G_DATA_BYTES;

    h_ready_i : in    std_logic;
    h_valid_o : out   std_logic;
    h_data_o  : out   std_logic_vector(G_HEADER_BYTES * 8 - 1 downto 0)
  );
end entity axip_remove_fixed_header;

architecture synthesis of axip_remove_fixed_header is

  type     state_type is (IDLE_ST, BUSY_ST, LAST_ST);
  signal   state   : state_type                                          := IDLE_ST;
  signal   s_data  : std_logic_vector(G_DATA_BYTES * 8 - 1 downto 0);
  signal   s_bytes : natural range 0 to G_DATA_BYTES;

  constant C_PADDING : std_logic_vector(G_HEADER_BYTES * 8 - 1 downto 0) := (others => '0');

begin

  assert G_DATA_BYTES >= G_HEADER_BYTES;

  s_ready_o <= (m_ready_i or not m_valid_o) and (h_ready_i or not h_valid_o) when state = IDLE_ST or state = BUSY_ST else
               '0';

  state_proc : process (clk_i)
  begin
    if rising_edge(clk_i) then
      if m_ready_i = '1' then
        m_last_o  <= '0';
        m_valid_o <= '0';
        m_bytes_o <= 0;
      end if;

      if h_ready_i = '1' then
        h_valid_o <= '0';
      end if;

      case state is

        when IDLE_ST =>
          if s_valid_i = '1' and s_ready_o = '1' then
            f_bytes : assert s_bytes_i >= G_HEADER_BYTES or s_last_i = '0' or rst_i = '1';
            s_data    <= s_data_i;
            s_bytes   <= s_bytes_i;

            h_data_o  <= s_data_i(G_DATA_BYTES * 8 - 1 downto (G_DATA_BYTES - G_HEADER_BYTES) * 8);
            h_valid_o <= '1';
            if s_last_i = '1' then
              m_data_o  <= s_data_i((G_DATA_BYTES - G_HEADER_BYTES) * 8 - 1 downto 0) & C_PADDING;
              m_bytes_o <= s_bytes_i - G_HEADER_BYTES;
              m_last_o  <= '1';
              m_valid_o <= '1';
            else
              state <= BUSY_ST;
            end if;
          end if;

        when BUSY_ST =>
          if s_valid_i = '1' and s_ready_o = '1' then
            s_data    <= s_data_i;
            s_bytes   <= s_bytes_i;
            m_data_o  <= s_data((G_DATA_BYTES - G_HEADER_BYTES) * 8 - 1 downto 0) &
                         s_data_i(G_DATA_BYTES * 8 - 1 downto (G_DATA_BYTES - G_HEADER_BYTES) * 8);
            m_bytes_o <= G_DATA_BYTES;
            m_valid_o <= '1';
            if s_last_i = '1' then
              state <= LAST_ST;
              if s_bytes_i < G_HEADER_BYTES then
                m_bytes_o <= (G_DATA_BYTES - G_HEADER_BYTES) + s_bytes_i;
                m_last_o  <= '1';
                state     <= IDLE_ST;
              end if;
            end if;
          end if;

        when LAST_ST =>
          if m_ready_i or not m_valid_o then
            m_data_o  <= s_data((G_DATA_BYTES - G_HEADER_BYTES) * 8 - 1 downto 0) & C_PADDING;
            m_bytes_o <= s_bytes - G_HEADER_BYTES;
            m_valid_o <= '1';
            m_last_o  <= '1';
            state     <= IDLE_ST;
          end if;

      end case;

      if rst_i = '1' then
        m_valid_o <= '0';
        h_valid_o <= '0';
        m_last_o  <= '0';
        m_bytes_o <= 0;
        state     <= IDLE_ST;
      end if;
    end if;
  end process state_proc;

end architecture synthesis;

