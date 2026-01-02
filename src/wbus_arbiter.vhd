-- ----------------------------------------------------------------------------
-- Author     : Michael Jørgensen
-- Platform   : AMD Artix 7
-- ----------------------------------------------------------------------------
-- Description: Arbitrate between two different Wishbone masters
-- ----------------------------------------------------------------------------

library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std.all;

entity wbus_arbiter is
  generic (
    G_ADDR_SIZE : natural := 10;
    G_DATA_SIZE : natural := 32
  );
  port (
    clk_i           : in    std_logic;
    rst_i           : in    std_logic;

    -- Wishbone bus Slave interface
    s0_wbus_cyc_i   : in    std_logic;                                  -- Valid bus cycle
    s0_wbus_stall_o : out   std_logic;
    s0_wbus_stb_i   : in    std_logic;                                  -- Strobe signals / core select signal
    s0_wbus_addr_i  : in    std_logic_vector(G_ADDR_SIZE - 1 downto 0); -- lower address bits
    s0_wbus_we_i    : in    std_logic;                                  -- Write enable
    s0_wbus_wrdat_i : in    std_logic_vector(G_DATA_SIZE - 1 downto 0); -- Write Databus
    s0_wbus_ack_o   : out   std_logic;                                  -- Bus cycle acknowledge
    s0_wbus_rddat_o : out   std_logic_vector(G_DATA_SIZE - 1 downto 0); -- Read Databus

    s1_wbus_cyc_i   : in    std_logic;                                  -- Valid bus cycle
    s1_wbus_stall_o : out   std_logic;
    s1_wbus_stb_i   : in    std_logic;                                  -- Strobe signals / core select signal
    s1_wbus_addr_i  : in    std_logic_vector(G_ADDR_SIZE - 1 downto 0); -- lower address bits
    s1_wbus_we_i    : in    std_logic;                                  -- Write enable
    s1_wbus_wrdat_i : in    std_logic_vector(G_DATA_SIZE - 1 downto 0); -- Write Databus
    s1_wbus_ack_o   : out   std_logic;                                  -- Bus cycle acknowledge
    s1_wbus_rddat_o : out   std_logic_vector(G_DATA_SIZE - 1 downto 0); -- Read Databus

    -- Wishbone bus Master interface
    m_wbus_cyc_o    : out   std_logic;                                  -- Valid bus cycle
    m_wbus_stall_i  : in    std_logic;
    m_wbus_stb_o    : out   std_logic;                                  -- Strobe signals / core select signal
    m_wbus_addr_o   : out   std_logic_vector(G_ADDR_SIZE - 1 downto 0); -- lower address bits
    m_wbus_we_o     : out   std_logic;                                  -- Write enable
    m_wbus_wrdat_o  : out   std_logic_vector(G_DATA_SIZE - 1 downto 0); -- Write Databus
    m_wbus_ack_i    : in    std_logic;                                  -- Bus cycle acknowledge
    m_wbus_rddat_i  : in    std_logic_vector(G_DATA_SIZE - 1 downto 0)  -- Read Databus
  );
end entity wbus_arbiter;

architecture synthesis of wbus_arbiter is

  type   state_type is (SLAVE_0_IDLE_ST, SLAVE_1_IDLE_ST, SLAVE_0_BUSY_ST, SLAVE_1_BUSY_ST);
  signal state : state_type := SLAVE_0_IDLE_ST;

begin

  s0_wbus_stall_o <= (m_wbus_stall_i or m_wbus_stb_o) when state = SLAVE_0_IDLE_ST else
                     '1';
  s1_wbus_stall_o <= (m_wbus_stall_i or m_wbus_stb_o) when state = SLAVE_1_IDLE_ST else
                     '1';

  fsm_proc : process (clk_i)
  begin
    if rising_edge(clk_i) then
      if m_wbus_ack_i = '1' then
        m_wbus_cyc_o <= '0';
      end if;
      if m_wbus_stall_i = '0' then
        m_wbus_stb_o <= '0';
      end if;

      s0_wbus_rddat_o <= (others => '0');
      s0_wbus_ack_o   <= '0';
      s1_wbus_rddat_o <= (others => '0');
      s1_wbus_ack_o   <= '0';

      case state is

        when SLAVE_0_IDLE_ST =>
          if s0_wbus_cyc_i = '0' and s1_wbus_cyc_i = '1' then
            state <= SLAVE_1_IDLE_ST;
          elsif s0_wbus_cyc_i = '1' and s0_wbus_stall_o = '0' and s0_wbus_stb_i = '1' and s0_wbus_ack_o = '0' then
            assert m_wbus_cyc_o = '0';
            m_wbus_addr_o  <= s0_wbus_addr_i;
            m_wbus_wrdat_o <= s0_wbus_wrdat_i;
            m_wbus_we_o    <= s0_wbus_we_i;
            m_wbus_cyc_o   <= s0_wbus_cyc_i;
            m_wbus_stb_o   <= s0_wbus_stb_i;
            state          <= SLAVE_0_BUSY_ST;
          end if;

        when SLAVE_1_IDLE_ST =>
          if s0_wbus_cyc_i = '1' and s1_wbus_cyc_i = '0' then
            state <= SLAVE_0_IDLE_ST;
          elsif s1_wbus_cyc_i = '1' and s1_wbus_stall_o = '0' and s1_wbus_stb_i = '1' and s1_wbus_ack_o = '0' then
            assert m_wbus_cyc_o = '0';
            m_wbus_addr_o  <= s1_wbus_addr_i;
            m_wbus_wrdat_o <= s1_wbus_wrdat_i;
            m_wbus_we_o    <= s1_wbus_we_i;
            m_wbus_cyc_o   <= s1_wbus_cyc_i;
            m_wbus_stb_o   <= s1_wbus_stb_i;
            state          <= SLAVE_1_BUSY_ST;
          end if;

        when SLAVE_0_BUSY_ST =>
          if m_wbus_ack_i = '1' then
            if m_wbus_we_o = '0' then
              s0_wbus_rddat_o <= m_wbus_rddat_i;
            end if;
            s0_wbus_ack_o   <= '1';
            state           <= SLAVE_1_IDLE_ST;
          end if;

        when SLAVE_1_BUSY_ST =>
          if m_wbus_ack_i = '1' then
            if m_wbus_we_o = '0' then
              s1_wbus_rddat_o <= m_wbus_rddat_i;
            end if;
            s1_wbus_ack_o   <= '1';
            state           <= SLAVE_0_IDLE_ST;
          end if;

      end case;

      if rst_i = '1' then
        m_wbus_cyc_o <= '0';
        m_wbus_stb_o <= '0';
        m_wbus_we_o  <= '0';
        state        <= SLAVE_0_IDLE_ST;
      end if;
    end if;
  end process fsm_proc;

end architecture synthesis;

