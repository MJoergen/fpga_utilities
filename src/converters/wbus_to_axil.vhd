library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std.all;

-- This allows an AXI Slave to be connected to a Wishbone Master

entity wbus_to_axil is
  generic (
    G_ADDR_SIZE : natural;
    G_DATA_SIZE : natural
  );
  port (
    clk_i            : in    std_logic;
    rst_i            : in    std_logic;

    -- Wishbone Bus interface (slave)
    s_wbus_cyc_i     : in    std_logic;
    s_wbus_stall_o   : out   std_logic;
    s_wbus_stb_i     : in    std_logic;
    s_wbus_addr_i    : in    std_logic_vector(G_ADDR_SIZE - 1 downto 0);
    s_wbus_we_i      : in    std_logic;
    s_wbus_wrdat_i   : in    std_logic_vector(G_DATA_SIZE - 1 downto 0);
    s_wbus_ack_o     : out   std_logic;
    s_wbus_rddat_o   : out   std_logic_vector(G_DATA_SIZE - 1 downto 0);

    -- AXI Lite interface (master)
    m_axil_awready_i : in    std_logic;
    m_axil_awvalid_o : out   std_logic;
    m_axil_awaddr_o  : out   std_logic_vector(G_ADDR_SIZE - 1 downto 0);
    m_axil_wready_i  : in    std_logic;
    m_axil_wvalid_o  : out   std_logic;
    m_axil_wdata_o   : out   std_logic_vector(G_DATA_SIZE - 1 downto 0);
    m_axil_wstrb_o   : out   std_logic_vector(G_DATA_SIZE / 8 - 1 downto 0);
    m_axil_bready_o  : out   std_logic;
    m_axil_bvalid_i  : in    std_logic;
    m_axil_bresp_i   : in    std_logic_vector(1 downto 0);
    m_axil_arready_i : in    std_logic;
    m_axil_arvalid_o : out   std_logic;
    m_axil_araddr_o  : out   std_logic_vector(G_ADDR_SIZE - 1 downto 0);
    m_axil_rready_o  : out   std_logic;
    m_axil_rvalid_i  : in    std_logic;
    m_axil_rdata_i   : in    std_logic_vector(G_DATA_SIZE - 1 downto 0);
    m_axil_rresp_i   : in    std_logic_vector(1 downto 0)
  );
end entity wbus_to_axil;

architecture synthesis of wbus_to_axil is

  type   state_type is (IDLE_ST, WRITING_ST, READING_ST, ABORTING_ST);
  signal state : state_type := IDLE_ST;

begin

  m_axil_bready_o <= '1';
  m_axil_rready_o <= '1';

  s_wbus_stall_o  <= '0' when state = IDLE_ST else
                     '1';

  fsm_proc : process (clk_i)
  begin
    if rising_edge(clk_i) then
      s_wbus_ack_o <= '0';
      if m_axil_awready_i = '1' then
        m_axil_awvalid_o <= '0';
      end if;
      if m_axil_arready_i = '1' then
        m_axil_arvalid_o <= '0';
      end if;
      if m_axil_wready_i = '1' then
        m_axil_wvalid_o <= '0';
      end if;

      case state is

        when IDLE_ST =>
          if s_wbus_cyc_i = '1' and s_wbus_stb_i = '1' then
            if s_wbus_we_i = '1' then
              m_axil_awaddr_o  <= s_wbus_addr_i;
              m_axil_awvalid_o <= '1';

              m_axil_wdata_o   <= s_wbus_wrdat_i;
              m_axil_wvalid_o  <= '1';
              m_axil_wstrb_o   <= (others => '1');
              state            <= WRITING_ST;
            else
              m_axil_araddr_o  <= s_wbus_addr_i;
              m_axil_arvalid_o <= '1';
              state            <= READING_ST;
            end if;
          end if;

        when WRITING_ST =>
          if m_axil_bvalid_i = '1' and m_axil_bready_o = '1' then
            s_wbus_ack_o <= s_wbus_cyc_i;
            state        <= IDLE_ST;
          elsif s_wbus_cyc_i = '0' then
            state <= ABORTING_ST;
          end if;

        when READING_ST =>
          if m_axil_rvalid_i = '1' and m_axil_rready_o = '1' then
            s_wbus_rddat_o <= m_axil_rdata_i;
            s_wbus_ack_o   <= s_wbus_cyc_i;
            state          <= IDLE_ST;
          elsif s_wbus_cyc_i = '0' then
            state <= ABORTING_ST;
          end if;

        when ABORTING_ST =>
          if m_axil_bvalid_i = '1' and m_axil_bready_o = '1' then
            state <= IDLE_ST;
          end if;
          if m_axil_rvalid_i = '1' and m_axil_rready_o = '1' then
            state <= IDLE_ST;
          end if;

      end case;

      if rst_i = '1' then
        state            <= IDLE_ST;
        s_wbus_ack_o     <= '0';
        m_axil_awvalid_o <= '0';
        m_axil_arvalid_o <= '0';
        m_axil_wvalid_o  <= '0';
      end if;
    end if;
  end process fsm_proc;

end architecture synthesis;

