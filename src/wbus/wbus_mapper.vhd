-- ---------------------------------------------------------------------------------------
-- Description: Wishbone mapper. Connect multiple Wishbone Slaves to a single Wishbone
-- Master.
-- ---------------------------------------------------------------------------------------

library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std.all;

library work;
  use work.wbus_pkg.all;

entity wbus_mapper is
  generic (
    G_TIMEOUT : positive := 100
  );
  port (
    clk_i  : in    std_logic;
    rst_i  : in    std_logic;
    s_wbus : view  wbus_slave_view;
    m_wbus : view  wbus_map_master_view
  );
end entity wbus_mapper;

architecture synthesis of wbus_mapper is

  constant C_NUM_SLAVES       : positive                       := m_wbus.cyc'length;
  constant C_SLAVE_ADDR_SIZE  : positive                       := m_wbus.addr'length;
  constant C_MASTER_ADDR_SIZE : positive                       := s_wbus.addr'length;

  type     state_type is (IDLE_ST, BUSY_ST);
  signal   state : state_type                                  := IDLE_ST;

  signal   timeout_cnt : natural range 0 to G_TIMEOUT          := 0;
  signal   slave_num   : natural range 0 to C_NUM_SLAVES - 1;

  signal   m_rst : std_logic_vector(C_NUM_SLAVES - 1 downto 0) := (others => '1');  -- Synchronous reset

  -- Reduce fan-out on reset signal
  attribute keep : string;
  attribute keep of m_rst : signal is "true";

begin

  s_wbus.stall <= '0' when state = IDLE_ST else
                  '1';

  m_wbus.rst   <= m_rst;

  rst_proc : process (clk_i, rst_i)
  begin
    if rising_edge(clk_i) then
      m_rst <= (others => rst_i);
    end if;

    -- Asynchronuous reset
    if rst_i = '1' then
      m_rst <= (others => '1');
    end if;
  end process rst_proc;


  state_proc : process (clk_i)
    variable slave_num_v : std_logic_vector(C_MASTER_ADDR_SIZE - C_SLAVE_ADDR_SIZE - 1 downto 0);
    variable idx_v       : natural range 0 to C_NUM_SLAVES - 1;
  begin
    if rising_edge(clk_i) then
      if or(m_wbus.stall and m_wbus.stb) = '0' then
        m_wbus.stb <= (m_wbus.stb'range => '0');
      end if;
      s_wbus.ack <= '0';

      case state is

        when IDLE_ST =>
          if s_wbus.cyc = '1' and s_wbus.stb = '1' then
            slave_num_v := s_wbus.addr(C_MASTER_ADDR_SIZE - 1 downto C_SLAVE_ADDR_SIZE);
            if to_integer(unsigned(slave_num_v)) < C_NUM_SLAVES then
              idx_v             := to_integer(unsigned(slave_num_v));
              slave_num         <= idx_v;
              m_wbus.addr       <= s_wbus.addr(C_SLAVE_ADDR_SIZE - 1 downto 0);
              m_wbus.wrdat      <= s_wbus.wrdat;
              m_wbus.we         <= s_wbus.we;
              m_wbus.cyc        <= '1';
              m_wbus.stb        <= (m_wbus.stb'range => '0');
              m_wbus.stb(idx_v) <= '1';
              timeout_cnt       <= 0;
              state             <= BUSY_ST;
            else
              s_wbus.rddat <= x"BAD51A73"; -- "Bad Slave"
              s_wbus.ack   <= '1';
              state        <= IDLE_ST;
            end if;
          end if;

        when BUSY_ST =>
          if m_wbus.ack(idx_v) = '1' then
            s_wbus.rddat <= m_wbus.rddat(idx_v);
            s_wbus.ack   <= '1';
            m_wbus.cyc   <= '0';
            state        <= IDLE_ST;
          end if;
          if timeout_cnt < G_TIMEOUT then
            timeout_cnt <= timeout_cnt + 1;
          else
            s_wbus.rddat <= x"DEADBEEF";
            s_wbus.ack   <= '1';
            m_wbus.cyc   <= '0';
            state        <= IDLE_ST;
          end if;

      end case;

      if rst_i = '1' or s_wbus.cyc = '0' then
        s_wbus.ack  <= '0';
        m_wbus.stb  <= (m_wbus.stb'range => '0');
        m_wbus.cyc  <= '0';
        timeout_cnt <= 0;
        state       <= IDLE_ST;
      end if;
    end if;
  end process state_proc;

end architecture synthesis;

