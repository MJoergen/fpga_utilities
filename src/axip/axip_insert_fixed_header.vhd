-- ---------------------------------------------------------------------------------------
-- Description: This takes an AXI packet stream as input, and inserts a fixed-size header
-- to the start of the packet.  First byte is in the left-most (MSB) position.
-- s_bytes_i is only valid when s_last_i is 1.
-- m_bytes_o is only valid when m_last_o is 1.
-- ---------------------------------------------------------------------------------------

library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std.all;

library work;
  use work.axis_pkg.all;
  use work.axip_pkg.all;

entity axip_insert_fixed_header is
  port (
    clk_i  : in    std_logic;
    rst_i  : in    std_logic;
    h_axis : view  axis_slave_view;
    s_axip : view  axip_slave_view;
    m_axip : view  axip_master_view
  );
end entity axip_insert_fixed_header;

architecture synthesis of axip_insert_fixed_header is

  constant C_HEADER_BYTES : positive := h_axis.data'length/8;
  constant C_DATA_BYTES : positive := s_axip.data'length/8;

  type    state_type is (IDLE_ST, WAIT_HEADER_ST, WAIT_DATA_ST, BUSY_ST, LAST_ST);
  signal  state : state_type := IDLE_ST;

  signal  h_data  : std_logic_vector(h_axis.data'range);
  signal  s_data  : std_logic_vector(s_axip.data'range);
  signal  s_last  : std_logic;
  signal  s_bytes : natural range 0 to C_DATA_BYTES;

  subtype R_DATA is natural range C_DATA_BYTES * 8 - 1 downto C_HEADER_BYTES * 8;

  subtype R_HEADER is natural range C_HEADER_BYTES * 8 - 1 downto 0;

begin

  s_axip.ready <= (m_axip.ready or not m_axip.valid) when state = IDLE_ST or state = WAIT_DATA_ST or state = BUSY_ST else
                  '0';
  h_axis.ready <= (m_axip.ready or not m_axip.valid) when state = IDLE_ST or state = WAIT_HEADER_ST else
                  '0';

  state_proc : process (clk_i)
  begin
    if rising_edge(clk_i) then
      if m_axip.ready = '1' then
        m_axip.valid <= '0';
      end if;

      case state is

        when IDLE_ST =>
          if s_axip.valid = '1' and s_axip.ready = '1' and h_axis.valid = '1' and h_axis.ready = '1' then
            -- Both data and header received.
            -- Store data for next clock cycle
            s_data       <= s_axip.data;
            s_last       <= s_axip.last;
            s_bytes      <= s_axip.bytes;

            -- Prepare output
            m_axip.valid <= '1';
            m_axip.data  <= h_axis.data & s_axip.data(R_DATA);
            m_axip.last  <= '0';
            m_axip.bytes <= C_DATA_BYTES;
            state        <= BUSY_ST;
            if s_axip.last = '1' then
              -- Do we need an extra clock cycle?
              if s_axip.bytes > C_DATA_BYTES - C_HEADER_BYTES then
                state <= LAST_ST;
              else
                -- We're done now.
                m_axip.last  <= '1';
                m_axip.bytes <= s_axip.bytes + C_HEADER_BYTES;
                state        <= IDLE_ST;
              end if;
            end if;
          elsif s_axip.valid = '1' and s_axip.ready = '1' then
            -- Only data, no header
            s_data  <= s_axip.data;
            s_last  <= s_axip.last;
            s_bytes <= s_axip.bytes;
            state   <= WAIT_HEADER_ST;
          elsif h_axis.valid = '1' and h_axis.ready = '1' then
            -- Only header, no data
            h_data <= h_axis.data;
            state  <= WAIT_DATA_ST;
          end if;

        when WAIT_HEADER_ST =>
          if h_axis.valid = '1' and h_axis.ready = '1' then
            -- Header received
            -- Prepare output
            m_axip.valid <= '1';
            m_axip.data  <= h_axis.data & s_data(R_DATA);
            m_axip.last  <= '0';
            m_axip.bytes <= C_DATA_BYTES;
            state        <= BUSY_ST;
            if s_last = '1' then
              -- Do we need an extra clock cycle?
              if s_bytes > C_DATA_BYTES - C_HEADER_BYTES then
                state <= LAST_ST;
              else
                -- We're done now.
                m_axip.last  <= '1';
                m_axip.bytes <= s_bytes + C_HEADER_BYTES;
                state        <= IDLE_ST;
              end if;
            end if;
          end if;

        when WAIT_DATA_ST =>
          if s_axip.valid = '1' and s_axip.ready = '1' then
            -- Data received
            s_data       <= s_axip.data;
            s_last       <= s_axip.last;
            s_bytes      <= s_axip.bytes;
            -- Prepare output
            m_axip.valid <= '1';
            m_axip.data  <= h_data & s_axip.data(R_DATA);
            m_axip.last  <= '0';
            m_axip.bytes <= C_DATA_BYTES;
            state        <= BUSY_ST;
            if s_axip.last = '1' then
              -- Do we need an extra clock cycle?
              if s_axip.bytes > C_DATA_BYTES - C_HEADER_BYTES then
                state <= LAST_ST;
              else
                -- We're done now.
                m_axip.last  <= '1';
                m_axip.bytes <= s_axip.bytes + C_HEADER_BYTES;
                state        <= IDLE_ST;
              end if;
            end if;
          end if;

        when BUSY_ST =>
          if s_axip.valid = '1' and s_axip.ready = '1' then
            -- Data received
            s_data       <= s_axip.data;
            s_last       <= s_axip.last;
            s_bytes      <= s_axip.bytes;
            -- Prepare output
            m_axip.valid <= '1';
            m_axip.data  <= s_data(R_HEADER) & s_axip.data(R_DATA);
            m_axip.last  <= '0';
            m_axip.bytes <= C_DATA_BYTES;
            if s_axip.last = '1' then
              -- Do we need an extra clock cycle?
              if s_axip.bytes > C_DATA_BYTES - C_HEADER_BYTES then
                state <= LAST_ST;
              else
                -- We're done now.
                m_axip.last  <= '1';
                m_axip.bytes <= s_axip.bytes + C_HEADER_BYTES;
                state        <= IDLE_ST;
              end if;
            end if;
          end if;

        when LAST_ST =>
          if m_axip.ready or not m_axip.valid then
            m_axip.valid <= '1';
            m_axip.data  <= s_data(R_HEADER) & s_axip.data(R_DATA);
            m_axip.last  <= '1';
            m_axip.bytes <= s_bytes - (C_DATA_BYTES - C_HEADER_BYTES);
            state        <= IDLE_ST;
          end if;

      end case;

      if rst_i = '1' then
        m_axip.valid <= '0';
        state        <= IDLE_ST;
      end if;
    end if;
  end process state_proc;

end architecture synthesis;

