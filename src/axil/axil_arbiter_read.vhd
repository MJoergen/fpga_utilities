-- ---------------------------------------------------------------------------------------
-- ---------------------------------------------------------------------------------------

library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std.all;

entity axil_arbiter_read is
  generic (
    G_ADDR_SIZE : positive;
    G_DATA_SIZE : positive
  );
  port (
    clk_i        : in    std_logic;
    rst_i        : in    std_logic;

    -- Input
    s0_arready_o : out   std_logic;
    s0_arvalid_i : in    std_logic;
    s0_araddr_i  : in    std_logic_vector(G_ADDR_SIZE - 1 downto 0);
    s0_rready_i  : in    std_logic;
    s0_rvalid_o  : out   std_logic;
    s0_rdata_o   : out   std_logic_vector(G_DATA_SIZE - 1 downto 0);
    s0_rresp_o   : out   std_logic_vector(1 downto 0);
    s0_writing_i : in    std_logic;

    s1_arready_o : out   std_logic;
    s1_arvalid_i : in    std_logic;
    s1_araddr_i  : in    std_logic_vector(G_ADDR_SIZE - 1 downto 0);
    s1_rready_i  : in    std_logic;
    s1_rvalid_o  : out   std_logic;
    s1_rdata_o   : out   std_logic_vector(G_DATA_SIZE - 1 downto 0);
    s1_rresp_o   : out   std_logic_vector(1 downto 0);
    s1_writing_i : in    std_logic;

    -- Output
    m_arready_i  : in    std_logic;
    m_arvalid_o  : out   std_logic;
    m_araddr_o   : out   std_logic_vector(G_ADDR_SIZE - 1 downto 0);
    m_rready_o   : out   std_logic;
    m_rvalid_i   : in    std_logic;
    m_rdata_i    : in    std_logic_vector(G_DATA_SIZE - 1 downto 0);
    m_rresp_i    : in    std_logic_vector(1 downto 0)
  );
end entity axil_arbiter_read;

architecture synthesis of axil_arbiter_read is

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
          if (s1_writing_i = '1' or s1_arvalid_i = '1') and
             (s0_writing_i = '0' and s0_arvalid_i = '0') then
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
          if (s0_writing_i = '1' or s0_arvalid_i = '1') and
             (s1_writing_i = '0' and s1_arvalid_i = '0') then
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

