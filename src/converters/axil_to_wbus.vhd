-- ---------------------------------------------------------------------------------------
-- Description: This allows a Wishbone Slave to be connected to an AXI Lite Master
-- ---------------------------------------------------------------------------------------

library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std.all;

library work;
  use work.axil_pkg.all;
  use work.wbus_pkg.all;

entity axil_to_wbus is
  generic (
    G_TIMEOUT : positive := 100
  );
  port (
    clk_i  : in    std_logic;
    rst_i  : in    std_logic;
    s_axil : view  axil_slave_view;
    m_wbus : view  wbus_master_view
  );
end entity axil_to_wbus;

architecture synthesis of axil_to_wbus is

  type   state_type is (IDLE_ST, WRITING_ST, READING_ST);
  signal state : state_type := IDLE_ST;

  signal time_cnt : natural range 0 to G_TIMEOUT;

begin

  -- AW and W streams wait for each other. Data only propagated when both streams are
  -- available.
  s_axil.awready <= ((not m_wbus.stb) or (not m_wbus.stall)) and
                    (s_axil.wvalid) and
                    (s_axil.bready or not s_axil.bvalid) and
                    not (s_axil.arvalid)
                    when state = IDLE_ST else
                    '0';
  s_axil.wready  <= ((not m_wbus.stb) or (not m_wbus.stall)) and
                    (s_axil.awvalid) and
                    (s_axil.bready or not s_axil.bvalid) and
                    not (s_axil.arvalid)
                    when state = IDLE_ST else
                    '0';

  s_axil.arready <= ((not m_wbus.stb) or (not m_wbus.stall)) and
                    (s_axil.rready or not s_axil.rvalid)
                    when state = IDLE_ST else
                    '0';

  fsm_proc : process (clk_i)
  begin
    if rising_edge(clk_i) then
      s_axil.bresp <= C_AXIL_RESP_OKAY;
      s_axil.rresp <= C_AXIL_RESP_OKAY;

      if m_wbus.stall = '0' then
        m_wbus.stb <= '0';
      end if;
      if m_wbus.ack = '1' then
        m_wbus.cyc <= '0';
        m_wbus.stb <= '0';
      end if;

      if s_axil.bready = '1' then
        s_axil.bvalid <= '0';
      end if;
      if s_axil.rready = '1' then
        s_axil.rvalid <= '0';
      end if;

      case state is

        when IDLE_ST =>
          time_cnt <= 0;
          if s_axil.awvalid = '1' and s_axil.awready = '1' and
             s_axil.wvalid = '1' and s_axil.wready = '1' then
            -- Both AW and W streams are valid.
            m_wbus.cyc   <= '1';
            m_wbus.stb   <= '1';
            m_wbus.addr  <= s_axil.awaddr(m_wbus.addr'range);
            m_wbus.we    <= '1';
            m_wbus.wrdat <= s_axil.wdata;
            state        <= WRITING_ST;
          end if;
          if s_axil.arvalid = '1' and s_axil.arready = '1' then
            -- AR stream valid
            m_wbus.cyc  <= '1';
            m_wbus.stb  <= '1';
            m_wbus.addr <= s_axil.araddr(m_wbus.addr'range);
            m_wbus.we   <= '0';
            state       <= READING_ST;
          end if;

        when WRITING_ST =>
          time_cnt <= time_cnt + 1;
          if time_cnt = G_TIMEOUT - 1 then
            -- Send back B response
            s_axil.bresp  <= C_RESP_SLVERR;
            m_wbus.cyc    <= '0';
            m_wbus.stb    <= '0';
            s_axil.bvalid <= '1';
            state         <= IDLE_ST;
          end if;
          if m_wbus.ack = '1' then
            -- Send back B response
            m_wbus.cyc    <= '0';
            m_wbus.stb    <= '0';
            s_axil.bvalid <= '1';
            state         <= IDLE_ST;
          end if;

        when READING_ST =>
          time_cnt <= time_cnt + 1;
          if time_cnt = G_TIMEOUT - 1 then
            -- Send back R response
            s_axil.rresp  <= C_RESP_SLVERR;
            m_wbus.cyc    <= '0';
            m_wbus.stb    <= '0';
            s_axil.rdata  <= (s_axil.rdata'range => '1');
            s_axil.rvalid <= '1';
            state         <= IDLE_ST;
          end if;
          if m_wbus.ack = '1' then
            -- Send back R response
            m_wbus.cyc    <= '0';
            m_wbus.stb    <= '0';
            s_axil.rdata  <= m_wbus.rddat;
            s_axil.rvalid <= '1';
            state         <= IDLE_ST;
          end if;

      end case;

      if rst_i = '1' then
        time_cnt      <= 0;
        m_wbus.cyc    <= '0';
        m_wbus.stb    <= '0';
        s_axil.bvalid <= '0';
        s_axil.rvalid <= '0';
        state         <= IDLE_ST;
      end if;
    end if;
  end process fsm_proc;

end architecture synthesis;

