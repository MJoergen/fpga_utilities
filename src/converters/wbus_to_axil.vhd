-- ---------------------------------------------------------------------------------------
-- Description: This allows an AXI Lite Slave to be connected to a Wishbone Master
-- ---------------------------------------------------------------------------------------

library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std.all;

library work;
  use work.wbus_pkg.all;
  use work.axil_pkg.all;

entity wbus_to_axil is
  port (
    clk_i  : in    std_logic;
    rst_i  : in    std_logic;
    s_wbus : view  wbus_slave_view;
    m_axil : view  axil_master_view
  );
end entity wbus_to_axil;

architecture synthesis of wbus_to_axil is

  type   state_type is (IDLE_ST, WRITING_ST, READING_ST, ABORTING_ST);
  signal state : state_type := IDLE_ST;

begin

  m_axil.bready <= '1';
  m_axil.rready <= '1';

  s_wbus.stall  <= '0' when state = IDLE_ST else
                   '1';

  fsm_proc : process (clk_i)
  begin
    if rising_edge(clk_i) then
      s_wbus.ack <= '0';
      if m_axil.awready = '1' then
        m_axil.awvalid <= '0';
      end if;
      if m_axil.arready = '1' then
        m_axil.arvalid <= '0';
      end if;
      if m_axil.wready = '1' then
        m_axil.wvalid <= '0';
      end if;

      case state is

        when IDLE_ST =>
          if s_wbus.cyc = '1' and s_wbus.stb = '1' then
            if s_wbus.we = '1' then
              m_axil.awvalid <= '1';
              m_axil.awaddr  <= s_wbus.addr;

              m_axil.wvalid  <= '1';
              m_axil.wdata   <= s_wbus.wrdat;
              m_axil.wstrb   <= (m_axil.wstrb'range => '1');
              state          <= WRITING_ST;
            else
              m_axil.arvalid <= '1';
              m_axil.araddr  <= s_wbus.addr;
              state          <= READING_ST;
            end if;
          end if;

        when WRITING_ST =>
          if m_axil.bvalid = '1' and m_axil.bready = '1' then
            s_wbus.ack <= s_wbus.cyc;
            state      <= IDLE_ST;
          elsif s_wbus.cyc = '0' then
            state <= ABORTING_ST;
          end if;

        when READING_ST =>
          if m_axil.rvalid = '1' and m_axil.rready = '1' then
            s_wbus.ack   <= s_wbus.cyc;
            s_wbus.rddat <= m_axil.rdata;
            state        <= IDLE_ST;
          elsif s_wbus.cyc = '0' then
            state <= ABORTING_ST;
          end if;

        when ABORTING_ST =>
          if m_axil.bvalid = '1' and m_axil.bready = '1' then
            state <= IDLE_ST;
          end if;
          if m_axil.rvalid = '1' and m_axil.rready = '1' then
            state <= IDLE_ST;
          end if;

      end case;

      if rst_i = '1' then
        s_wbus.ack     <= '0';
        m_axil.awvalid <= '0';
        m_axil.wvalid  <= '0';
        m_axil.arvalid <= '0';
        state          <= IDLE_ST;
      end if;
    end if;
  end process fsm_proc;

end architecture synthesis;

