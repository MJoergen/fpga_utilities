library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std.all;

-- This allows a Wishbone Slave to be connected to an AXI Master

entity axil_to_wbus is
  generic (
    G_TIMEOUT   : natural := 1000;
    G_ADDR_SIZE : natural;
    G_DATA_SIZE : natural
  );
  port (
    clk_i            : in    std_logic;
    rst_i            : in    std_logic;

    -- AXI Lite interface (slave)
    s_axil_awready_o : out   std_logic;
    s_axil_awvalid_i : in    std_logic;
    s_axil_awaddr_i  : in    std_logic_vector(G_ADDR_SIZE - 1 downto 0);
    --
    s_axil_wready_o  : out   std_logic;
    s_axil_wvalid_i  : in    std_logic;
    s_axil_wdata_i   : in    std_logic_vector(G_DATA_SIZE - 1 downto 0);
    s_axil_wstrb_i   : in    std_logic_vector(G_DATA_SIZE / 8 - 1 downto 0);
    --
    s_axil_bready_i  : in    std_logic;
    s_axil_bvalid_o  : out   std_logic;
    s_axil_bresp_o   : out   std_logic_vector(1 downto 0);
    --
    s_axil_arready_o : out   std_logic;
    s_axil_arvalid_i : in    std_logic;
    s_axil_araddr_i  : in    std_logic_vector(G_ADDR_SIZE - 1 downto 0);
    --
    s_axil_rready_i  : in    std_logic;
    s_axil_rvalid_o  : out   std_logic;
    s_axil_rdata_o   : out   std_logic_vector(G_DATA_SIZE - 1 downto 0);
    s_axil_rresp_o   : out   std_logic_vector(1 downto 0);

    -- Wishbone Bus interface (master)
    m_wbus_cyc_o     : out   std_logic;
    m_wbus_stall_i   : in    std_logic;
    m_wbus_stb_o     : out   std_logic;
    m_wbus_addr_o    : out   std_logic_vector(G_ADDR_SIZE - 1 downto 0);
    m_wbus_we_o      : out   std_logic;
    m_wbus_wrdat_o   : out   std_logic_vector(G_DATA_SIZE - 1 downto 0);
    m_wbus_ack_i     : in    std_logic;
    m_wbus_rddat_i   : in    std_logic_vector(G_DATA_SIZE - 1 downto 0)
  );
end entity axil_to_wbus;

architecture synthesis of axil_to_wbus is

  type     state_type is (IDLE_ST, WRITING_ST, READING_ST);
  signal   state : state_type                           := IDLE_ST;

  signal   time_cnt : natural range 0 to G_TIMEOUT;

  constant C_RESP_OKAY   : std_logic_vector(1 downto 0) := "00";
  constant C_RESP_SLVERR : std_logic_vector(1 downto 0) := "10";
  constant C_RESP_DECERR : std_logic_vector(1 downto 0) := "11";

begin

  -- AW and W streams wait for each other. Data only propagated when both streams are
  -- available.
  s_axil_awready_o <= ((not m_wbus_stb_o) or (not m_wbus_stall_i)) and
                      (s_axil_wvalid_i) and
                      (s_axil_bready_i or not s_axil_bvalid_o) and
                      not (s_axil_arvalid_i)
                      when state = IDLE_ST else
                      '0';
  s_axil_wready_o  <= ((not m_wbus_stb_o) or (not m_wbus_stall_i)) and
                      (s_axil_awvalid_i) and
                      (s_axil_bready_i or not s_axil_bvalid_o) and
                      not (s_axil_arvalid_i)
                      when state = IDLE_ST else
                      '0';

  s_axil_arready_o <= ((not m_wbus_stb_o) or (not m_wbus_stall_i)) and
                      (s_axil_rready_i or not s_axil_rvalid_o)
                      when state = IDLE_ST else
                      '0';

  fsm_proc : process (clk_i)
  begin
    if rising_edge(clk_i) then
      s_axil_bresp_o <= C_RESP_OKAY;
      s_axil_rresp_o <= C_RESP_OKAY;

      if m_wbus_stall_i = '0' then
        m_wbus_stb_o <= '0';
      end if;
      if m_wbus_ack_i = '1' then
        m_wbus_cyc_o <= '0';
        m_wbus_stb_o <= '0';
      end if;

      if s_axil_bready_i = '1' then
        s_axil_bvalid_o <= '0';
      end if;
      if s_axil_rready_i = '1' then
        s_axil_rvalid_o <= '0';
      end if;

      case state is

        when IDLE_ST =>
          time_cnt <= 0;
          if s_axil_awvalid_i = '1' and s_axil_awready_o = '1' and
             s_axil_wvalid_i = '1' and s_axil_wready_o = '1' then
            -- Both AW and W streams are valid.
            m_wbus_cyc_o   <= '1';
            m_wbus_stb_o   <= '1';
            m_wbus_we_o    <= '1';
            m_wbus_addr_o  <= s_axil_awaddr_i(G_ADDR_SIZE - 1 downto 0);
            m_wbus_wrdat_o <= s_axil_wdata_i;
            state          <= WRITING_ST;
          end if;
          if s_axil_arvalid_i = '1' and s_axil_arready_o = '1' then
            -- AR stream valid
            m_wbus_cyc_o  <= '1';
            m_wbus_stb_o  <= '1';
            m_wbus_we_o   <= '0';
            m_wbus_addr_o <= s_axil_araddr_i(G_ADDR_SIZE - 1 downto 0);
            state         <= READING_ST;
          end if;

        when WRITING_ST =>
          time_cnt <= time_cnt + 1;
          if time_cnt = G_TIMEOUT - 1 then
            -- Send back B response
            s_axil_bresp_o  <= C_RESP_SLVERR;
            m_wbus_cyc_o    <= '0';
            m_wbus_stb_o    <= '0';
            s_axil_bvalid_o <= '1';
            state           <= IDLE_ST;
          end if;
          if m_wbus_ack_i = '1' then
            -- Send back B response
            m_wbus_cyc_o    <= '0';
            m_wbus_stb_o    <= '0';
            s_axil_bvalid_o <= '1';
            state           <= IDLE_ST;
          end if;

        when READING_ST =>
          time_cnt <= time_cnt + 1;
          if time_cnt = G_TIMEOUT - 1 then
            -- Send back R response
            s_axil_rresp_o  <= C_RESP_SLVERR;
            m_wbus_cyc_o    <= '0';
            m_wbus_stb_o    <= '0';
            s_axil_rdata_o  <= (others => '1');
            s_axil_rvalid_o <= '1';
            state           <= IDLE_ST;
          end if;
          if m_wbus_ack_i = '1' then
            -- Send back R response
            m_wbus_cyc_o    <= '0';
            m_wbus_stb_o    <= '0';
            s_axil_rdata_o  <= m_wbus_rddat_i;
            s_axil_rvalid_o <= '1';
            state           <= IDLE_ST;
          end if;

      end case;

      if rst_i = '1' then
        time_cnt        <= 0;
        m_wbus_cyc_o    <= '0';
        m_wbus_stb_o    <= '0';
        s_axil_bvalid_o <= '0';
        s_axil_rvalid_o <= '0';
        state           <= IDLE_ST;
      end if;
    end if;
  end process fsm_proc;

end architecture synthesis;

