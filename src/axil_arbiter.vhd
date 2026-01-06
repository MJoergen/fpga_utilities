-- ----------------------------------------------------------------------------
-- Author     : Michael Jørgensen
-- Platform   : AMD Artix 7
-- ----------------------------------------------------------------------------
-- Description: Arbitrate between two different AXI Lite masters
-- If both Masters request simultaneously, then they are granted access alternately.
--
-- This is similar to the 2-1 AXI crossbar, see:
-- https://www.xilinx.com/support/documents/ip_documentation/axi_interconnect/v2_1/pg059-axi-interconnect.pdf
-- ----------------------------------------------------------------------------

library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std.all;

entity axil_arbiter is
  generic (
    G_ADDR_SIZE : natural;
    G_DATA_SIZE : natural
  );
  port (
    clk_i        : in    std_logic;
    rst_i        : in    std_logic;

    -- Input
    s0_awready_o : out   std_logic;
    s0_awvalid_i : in    std_logic;
    s0_awaddr_i  : in    std_logic_vector(G_ADDR_SIZE - 1 downto 0);
    s0_wready_o  : out   std_logic;
    s0_wvalid_i  : in    std_logic;
    s0_wdata_i   : in    std_logic_vector(G_DATA_SIZE - 1 downto 0);
    s0_wstrb_i   : in    std_logic_vector(G_DATA_SIZE / 8 - 1 downto 0);
    s0_bready_i  : in    std_logic;
    s0_bvalid_o  : out   std_logic;
    s0_bresp_o   : out   std_logic_vector(1 downto 0);
    s0_arready_o : out   std_logic;
    s0_arvalid_i : in    std_logic;
    s0_araddr_i  : in    std_logic_vector(G_ADDR_SIZE - 1 downto 0);
    s0_rready_i  : in    std_logic;
    s0_rvalid_o  : out   std_logic;
    s0_rdata_o   : out   std_logic_vector(G_DATA_SIZE - 1 downto 0);
    s0_rresp_o   : out   std_logic_vector(1 downto 0);

    s1_awready_o : out   std_logic;
    s1_awvalid_i : in    std_logic;
    s1_awaddr_i  : in    std_logic_vector(G_ADDR_SIZE - 1 downto 0);
    s1_wready_o  : out   std_logic;
    s1_wvalid_i  : in    std_logic;
    s1_wdata_i   : in    std_logic_vector(G_DATA_SIZE - 1 downto 0);
    s1_wstrb_i   : in    std_logic_vector(G_DATA_SIZE / 8 - 1 downto 0);
    s1_bready_i  : in    std_logic;
    s1_bvalid_o  : out   std_logic;
    s1_bresp_o   : out   std_logic_vector(1 downto 0);
    s1_arready_o : out   std_logic;
    s1_arvalid_i : in    std_logic;
    s1_araddr_i  : in    std_logic_vector(G_ADDR_SIZE - 1 downto 0);
    s1_rready_i  : in    std_logic;
    s1_rvalid_o  : out   std_logic;
    s1_rdata_o   : out   std_logic_vector(G_DATA_SIZE - 1 downto 0);
    s1_rresp_o   : out   std_logic_vector(1 downto 0);

    -- Output
    m_awready_i  : in    std_logic;
    m_awvalid_o  : out   std_logic;
    m_awaddr_o   : out   std_logic_vector(G_ADDR_SIZE - 1 downto 0);
    m_wready_i   : in    std_logic;
    m_wvalid_o   : out   std_logic;
    m_wdata_o    : out   std_logic_vector(G_DATA_SIZE - 1 downto 0);
    m_wstrb_o    : out   std_logic_vector(G_DATA_SIZE / 8 - 1 downto 0);
    m_bready_o   : out   std_logic;
    m_bvalid_i   : in    std_logic;
    m_bresp_i    : in    std_logic_vector(1 downto 0);
    m_arready_i  : in    std_logic;
    m_arvalid_o  : out   std_logic;
    m_araddr_o   : out   std_logic_vector(G_ADDR_SIZE - 1 downto 0);
    m_rready_o   : out   std_logic;
    m_rvalid_i   : in    std_logic;
    m_rdata_i    : in    std_logic_vector(G_DATA_SIZE - 1 downto 0);
    m_rresp_i    : in    std_logic_vector(1 downto 0)
  );
end entity axil_arbiter;

architecture synthesis of axil_arbiter is

  -- Pipeline for writing
  type   tx_state_type is (
    TX_INPUT_0_IDLE_ST, TX_INPUT_0_AW_BUSY_ST, TX_INPUT_0_W_BUSY_ST, TX_INPUT_0_WRITING_ST,
    TX_INPUT_1_IDLE_ST, TX_INPUT_1_AW_BUSY_ST, TX_INPUT_1_W_BUSY_ST, TX_INPUT_1_WRITING_ST
  );
  signal tx_state : tx_state_type := TX_INPUT_0_IDLE_ST;

  signal s0_awactive : std_logic;
  signal s0_wactive  : std_logic;
  signal s1_awactive : std_logic;
  signal s1_wactive  : std_logic;
  signal m_bactive   : std_logic;
  signal tx_select_0 : std_logic;
  signal accept_aw_0 : std_logic;
  signal accept_w_0  : std_logic;
  signal accept_aw_1 : std_logic;
  signal accept_w_1  : std_logic;

  -- Pipeline for reading
  type   rx_state_type is (
    RX_INPUT_0_IDLE_ST, RX_INPUT_0_READING_ST,
    RX_INPUT_1_IDLE_ST, RX_INPUT_1_READING_ST
  );
  signal rx_state : rx_state_type := RX_INPUT_0_IDLE_ST;

  signal s0_aractive : std_logic;
  signal s1_aractive : std_logic;
  signal m_ractive   : std_logic;
  signal accept_ar_0 : std_logic;
  signal accept_ar_1 : std_logic;
  signal rx_select_0 : std_logic;

begin

  -----------------------------------------------------------
  -- Pipeline for writing
  -----------------------------------------------------------

  s0_awactive  <= s0_awvalid_i and s0_awready_o;
  s0_wactive   <= s0_wvalid_i and s0_wready_o;

  s1_awactive  <= s1_awvalid_i and s1_awready_o;
  s1_wactive   <= s1_wvalid_i and s1_wready_o;

  m_bactive    <= m_bvalid_i and m_bready_o;

  tx_select_0  <= '1' when tx_state = TX_INPUT_0_IDLE_ST or
                           tx_state = TX_INPUT_0_AW_BUSY_ST or
                           tx_state = TX_INPUT_0_W_BUSY_ST or
                           tx_state = TX_INPUT_0_WRITING_ST else
                  '0';

  accept_aw_0  <= '1' when tx_state = TX_INPUT_0_IDLE_ST or
                           tx_state = TX_INPUT_0_W_BUSY_ST else
                  '0';

  accept_w_0   <= '1' when tx_state = TX_INPUT_0_IDLE_ST or
                           tx_state = TX_INPUT_0_AW_BUSY_ST else
                  '0';

  accept_aw_1  <= '1' when tx_state = TX_INPUT_1_IDLE_ST or
                           tx_state = TX_INPUT_1_W_BUSY_ST else
                  '0';

  accept_w_1   <= '1' when tx_state = TX_INPUT_1_IDLE_ST or
                           tx_state = TX_INPUT_1_AW_BUSY_ST else
                  '0';

  tx_state_proc : process (clk_i)
  begin
    if rising_edge(clk_i) then

      case tx_state is

        when TX_INPUT_0_IDLE_ST =>
          if (s1_awvalid_i = '1' or s1_wvalid_i = '1') and
             (s0_awvalid_i = '0' and s0_wvalid_i = '0') then
            tx_state <= TX_INPUT_1_IDLE_ST;
          end if;

          if s0_awactive = '1' and s0_wactive = '0' then
            tx_state <= TX_INPUT_0_AW_BUSY_ST;
          end if;

          if s0_awactive = '0' and s0_wactive = '1' then
            tx_state <= TX_INPUT_0_W_BUSY_ST;
          end if;

          if s0_awactive = '1' and s0_wactive = '1' then
            tx_state <= TX_INPUT_0_WRITING_ST;
          end if;

        when TX_INPUT_0_AW_BUSY_ST =>
          if s0_wactive = '1' then
            tx_state <= TX_INPUT_0_WRITING_ST;
          end if;

        when TX_INPUT_0_W_BUSY_ST =>
          if s0_awactive = '1' then
            tx_state <= TX_INPUT_0_WRITING_ST;
          end if;

        when TX_INPUT_0_WRITING_ST =>
          if m_bactive = '1' then
            tx_state <= TX_INPUT_1_IDLE_ST;
          end if;

        when TX_INPUT_1_IDLE_ST =>
          if (s0_awvalid_i = '1' or s0_wvalid_i = '1') and
             (s1_awvalid_i = '0' and s1_wvalid_i = '0') then
            tx_state <= TX_INPUT_0_IDLE_ST;
          end if;

          if s1_awactive = '1' and s1_wactive = '0' then
            tx_state <= TX_INPUT_1_AW_BUSY_ST;
          end if;

          if s1_awactive = '0' and s1_wactive = '1' then
            tx_state <= TX_INPUT_1_W_BUSY_ST;
          end if;

          if s1_awactive = '1' and s1_wactive = '1' then
            tx_state <= TX_INPUT_1_WRITING_ST;
          end if;

        when TX_INPUT_1_AW_BUSY_ST =>
          if s1_wactive = '1' then
            tx_state <= TX_INPUT_1_WRITING_ST;
          end if;

        when TX_INPUT_1_W_BUSY_ST =>
          if s1_awactive = '1' then
            tx_state <= TX_INPUT_1_WRITING_ST;
          end if;

        when TX_INPUT_1_WRITING_ST =>
          if m_bactive = '1' then
            tx_state <= TX_INPUT_0_IDLE_ST;
          end if;

      end case;

      if rst_i = '1' then
        tx_state <= TX_INPUT_0_IDLE_ST;
      end if;
    end if;
  end process tx_state_proc;


  m_awvalid_o  <= (s0_awvalid_i and accept_aw_0) or (s1_awvalid_i and accept_aw_1);
  m_awaddr_o   <= s0_awaddr_i when tx_select_0 = '1' else
                  s1_awaddr_i;
  m_wvalid_o   <= (s0_wvalid_i and accept_w_0) or (s1_wvalid_i and accept_w_1);
  m_wdata_o    <= s0_wdata_i when tx_select_0 = '1' else
                  s1_wdata_i;
  m_wstrb_o    <= s0_wstrb_i when tx_select_0 = '1' else
                  s1_wstrb_i;
  m_bready_o   <= s0_bready_i when tx_select_0 = '1' else
                  s1_bready_i;

  s0_awready_o <= m_awready_i and accept_aw_0;
  s1_awready_o <= m_awready_i and accept_aw_1;
  s0_wready_o  <= m_wready_i and accept_w_0;
  s1_wready_o  <= m_wready_i and accept_w_1;
  s0_bvalid_o  <= m_bvalid_i and tx_select_0;
  s1_bvalid_o  <= m_bvalid_i and not tx_select_0;
  s0_bresp_o   <= m_bresp_i;
  s1_bresp_o   <= m_bresp_i;


  -----------------------------------------------------------
  -- Pipeline for reading
  -----------------------------------------------------------

  s0_aractive  <= s0_arvalid_i and s0_arready_o;
  s1_aractive  <= s1_arvalid_i and s1_arready_o;

  m_ractive    <= m_rvalid_i and m_rready_o;

  accept_ar_0  <= '1' when rx_state = RX_INPUT_0_IDLE_ST else
                  '0';

  accept_ar_1  <= '1' when rx_state = RX_INPUT_1_IDLE_ST else
                  '0';

  rx_select_0  <= '1' when rx_state = RX_INPUT_0_IDLE_ST or
                           rx_state = RX_INPUT_0_READING_ST else
                  '0';

  rx_state_proc : process (clk_i)
  begin
    if rising_edge(clk_i) then

      case rx_state is

        when RX_INPUT_0_IDLE_ST =>
          if (s1_awvalid_i = '1' or s1_arvalid_i = '1' or s1_wvalid_i = '1') and
             (s0_awvalid_i = '0' and s0_arvalid_i = '0' and s0_wvalid_i = '0') then
            rx_state <= RX_INPUT_1_IDLE_ST;
          end if;

          if s0_aractive = '1' then
            rx_state <= RX_INPUT_0_READING_ST;
          end if;

        when RX_INPUT_0_READING_ST =>
          if m_ractive = '1' then
            rx_state <= RX_INPUT_1_IDLE_ST;
          end if;

        when RX_INPUT_1_IDLE_ST =>
          if (s0_awvalid_i = '1' or s0_arvalid_i = '1' or s0_wvalid_i = '1') and
             (s1_awvalid_i = '0' and s1_arvalid_i = '0' and s1_wvalid_i = '0') then
            rx_state <= RX_INPUT_0_IDLE_ST;
          end if;

          if s1_aractive = '1' then
            rx_state <= RX_INPUT_1_READING_ST;
          end if;

        when RX_INPUT_1_READING_ST =>
          if m_ractive = '1' then
            rx_state <= RX_INPUT_0_IDLE_ST;
          end if;

      end case;

      if rst_i = '1' then
        rx_state <= RX_INPUT_0_IDLE_ST;
      end if;
    end if;
  end process rx_state_proc;

  m_arvalid_o  <= (s0_arvalid_i and accept_ar_0) or (s1_arvalid_i and accept_ar_1);
  m_araddr_o   <= s0_araddr_i when rx_select_0 = '1' else
                  s1_araddr_i;
  m_rready_o   <= s0_rready_i when rx_select_0 = '1' else
                  s1_rready_i;

  s0_arready_o <= m_arready_i and accept_ar_0;
  s1_arready_o <= m_arready_i and accept_ar_1;
  s0_rvalid_o  <= m_rvalid_i and rx_select_0;
  s1_rvalid_o  <= m_rvalid_i and not rx_select_0;
  s0_rdata_o   <= m_rdata_i;
  s1_rdata_o   <= m_rdata_i;
  s0_rresp_o   <= m_rresp_i;
  s1_rresp_o   <= m_rresp_i;

end architecture synthesis;

