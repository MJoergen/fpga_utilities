-- ---------------------------------------------------------------------------------------
-- Description: This takes an AXI packet stream as input, and extracts a fixed-size header
-- from the start of the packet.  First byte is in the left-most (MSB) position.
-- s_bytes_i is only valid when s_last_i is 1.
-- m_bytes_o is only valid when m_last_o is 1.
-- If the input packet is less than the header size, then m_bytes_o is set to 0.
-- ---------------------------------------------------------------------------------------

library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std.all;

library work;
  use work.axis_pkg.all;
  use work.axip_pkg.all;

entity axip_remove_fixed_header is
  port (
    clk_i  : in    std_logic;
    rst_i  : in    std_logic;
    s_axip : view  axip_slave_view;
    m_axip : view  axip_master_view;
    h_axis : view  axis_master_view
  );
end entity axip_remove_fixed_header;

architecture synthesis of axip_remove_fixed_header is

  constant C_DATA_BYTES : positive := s_axip.data'length/8;
  constant C_HEADER_BYTES : positive := h_axis.data'length/8;

  type     state_type is (IDLE_ST, BUSY_ST, LAST_ST);
  signal   state   : state_type                                          := IDLE_ST;
  signal   s_data  : std_logic_vector(C_DATA_BYTES * 8 - 1 downto 0);
  signal   s_bytes : natural range 0 to C_DATA_BYTES;

  constant C_PADDING : std_logic_vector(C_HEADER_BYTES * 8 - 1 downto 0) := (others => '0');

  subtype  R_HEADER is natural range C_DATA_BYTES * 8 - 1 downto (C_DATA_BYTES - C_HEADER_BYTES) * 8;

  subtype  R_DATA is natural range (C_DATA_BYTES - C_HEADER_BYTES) * 8 - 1 downto 0;

begin

  assert C_DATA_BYTES >= C_HEADER_BYTES;

  s_axip.ready <= (m_axip.ready or not m_axip.valid) and (h_axis.ready or not h_axis.valid) when state = IDLE_ST or
                                                                                                 state = BUSY_ST else
                  '0';

  state_proc : process (clk_i)
  begin
    if rising_edge(clk_i) then
      if m_axip.ready = '1' then
        m_axip.valid <= '0';
      end if;

      if h_axis.ready = '1' then
        h_axis.valid <= '0';
      end if;

      case state is

        when IDLE_ST =>
          if s_axip.valid = '1' and s_axip.ready = '1' then
            -- Store data for next clock cycle
            s_data       <= s_axip.data;
            s_bytes      <= s_axip.bytes;

            -- Prepare Header output
            h_axis.valid <= '1';
            h_axis.data  <= s_axip.data(R_HEADER);
            m_axip.last  <= '0';
            if s_axip.last = '1' then
              -- Prepare AXI Packet output
              m_axip.valid <= '1';
              m_axip.data  <= s_axip.data(R_DATA) & C_PADDING;
              m_axip.last  <= '1';
              m_axip.bytes <= s_axip.bytes - C_HEADER_BYTES;

              -- Special case: If packet input is less than the header size.
              if s_axip.bytes < C_HEADER_BYTES then
                m_axip.bytes <= 0;
              end if;
            else
              state <= BUSY_ST;
            end if;
          end if;

        when BUSY_ST =>
          if s_axip.valid = '1' and s_axip.ready = '1' then
            -- Store data for next clock cycle
            s_data       <= s_axip.data;
            s_bytes      <= s_axip.bytes;

            -- Prepare AXI Packet output
            m_axip.valid <= '1';
            m_axip.data  <= s_data(R_DATA) & s_axip.data(R_HEADER);
            m_axip.bytes <= C_DATA_BYTES;
            if s_axip.last = '1' then
              -- Do we need an extra clock cycle?
              state <= LAST_ST;
              if s_axip.bytes < C_HEADER_BYTES then
                -- Packet is finished
                m_axip.last  <= '1';
                m_axip.bytes <= (C_DATA_BYTES - C_HEADER_BYTES) + s_axip.bytes;
                state        <= IDLE_ST;
              end if;
            end if;
          end if;

        when LAST_ST =>
          if m_axip.ready or not m_axip.valid then
            m_axip.valid <= '1';
            m_axip.data  <= s_data(R_DATA) & C_PADDING;
            m_axip.last  <= '1';
            m_axip.bytes <= s_bytes - C_HEADER_BYTES;
            state        <= IDLE_ST;
          end if;

      end case;

      if rst_i = '1' then
        m_axip.valid <= '0';
        h_axis.valid <= '0';
        state        <= IDLE_ST;
      end if;
    end if;
  end process state_proc;

end architecture synthesis;

