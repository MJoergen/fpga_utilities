-- ---------------------------------------------------------------------------------------
-- Description: Arbitrate between two different Wishbone masters
-- ---------------------------------------------------------------------------------------

library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std.all;

entity wbus_arbiter is
  generic (
    G_ADDR_SIZE : positive;
    G_DATA_SIZE : positive
  );
  port (
    clk_i      : in    std_logic;
    rst_i      : in    std_logic;

    -- Wishbone bus Slave interfaces
    s0_cyc_i   : in    std_logic;
    s0_stall_o : out   std_logic;
    s0_stb_i   : in    std_logic;
    s0_addr_i  : in    std_logic_vector(G_ADDR_SIZE - 1 downto 0);
    s0_we_i    : in    std_logic;
    s0_wrdat_i : in    std_logic_vector(G_DATA_SIZE - 1 downto 0);
    s0_ack_o   : out   std_logic;
    s0_rddat_o : out   std_logic_vector(G_DATA_SIZE - 1 downto 0);

    s1_cyc_i   : in    std_logic;
    s1_stall_o : out   std_logic;
    s1_stb_i   : in    std_logic;
    s1_addr_i  : in    std_logic_vector(G_ADDR_SIZE - 1 downto 0);
    s1_we_i    : in    std_logic;
    s1_wrdat_i : in    std_logic_vector(G_DATA_SIZE - 1 downto 0);
    s1_ack_o   : out   std_logic;
    s1_rddat_o : out   std_logic_vector(G_DATA_SIZE - 1 downto 0);

    -- Wishbone bus Master interface
    m_cyc_o    : out   std_logic;
    m_stall_i  : in    std_logic;
    m_stb_o    : out   std_logic;
    m_addr_o   : out   std_logic_vector(G_ADDR_SIZE - 1 downto 0);
    m_we_o     : out   std_logic;
    m_wrdat_o  : out   std_logic_vector(G_DATA_SIZE - 1 downto 0);
    m_ack_i    : in    std_logic;
    m_rddat_i  : in    std_logic_vector(G_DATA_SIZE - 1 downto 0)
  );
end entity wbus_arbiter;

architecture synthesis of wbus_arbiter is

  type   state_type is (INPUT_0_IDLE_ST, INPUT_1_IDLE_ST, INPUT_0_BUSY_ST, INPUT_1_BUSY_ST);
  signal state : state_type := INPUT_0_IDLE_ST;

begin

  s0_stall_o <= '0' when state = INPUT_0_IDLE_ST else
                '1';
  s1_stall_o <= '0' when state = INPUT_1_IDLE_ST else
                '1';

  fsm_proc : process (clk_i)
  begin
    if rising_edge(clk_i) then
      if m_ack_i = '1' then
        m_cyc_o <= '0';
      end if;
      if m_stall_i = '0' then
        m_stb_o <= '0';
      end if;

      s0_ack_o <= '0';
      s1_ack_o <= '0';

      case state is

        when INPUT_0_IDLE_ST =>
          -- Validate invariant
          f_slave0 : assert (m_cyc_o = '0' and m_stb_o = '0') or rst_i = '1';

          if s0_cyc_i = '0' and s1_cyc_i = '1' then
            state <= INPUT_1_IDLE_ST;
          elsif s0_cyc_i = '1' and s0_stb_i = '1' then
            m_cyc_o   <= s0_cyc_i;
            m_stb_o   <= s0_stb_i;
            m_addr_o  <= s0_addr_i;
            m_we_o    <= s0_we_i;
            m_wrdat_o <= s0_wrdat_i;
            state     <= INPUT_0_BUSY_ST;
          end if;

        when INPUT_1_IDLE_ST =>
          -- Validate invariant
          f_slave1 : assert (m_cyc_o = '0' and m_stb_o = '0') or rst_i = '1';

          if s0_cyc_i = '1' and s1_cyc_i = '0' then
            state <= INPUT_0_IDLE_ST;
          elsif s1_cyc_i = '1' and s1_stb_i = '1' then
            m_cyc_o   <= s1_cyc_i;
            m_stb_o   <= s1_stb_i;
            m_addr_o  <= s1_addr_i;
            m_we_o    <= s1_we_i;
            m_wrdat_o <= s1_wrdat_i;
            state     <= INPUT_1_BUSY_ST;
          end if;

        when INPUT_0_BUSY_ST =>
          if m_ack_i = '1' then
            s0_ack_o   <= '1';
            s0_rddat_o <= m_rddat_i;
            state      <= INPUT_1_IDLE_ST;
          end if;
          if s0_cyc_i = '0' then
            m_cyc_o  <= '0';
            m_stb_o  <= '0';
            s0_ack_o <= '0';
            state    <= INPUT_1_IDLE_ST;
          end if;

        when INPUT_1_BUSY_ST =>
          if m_ack_i = '1' then
            s1_ack_o   <= '1';
            s1_rddat_o <= m_rddat_i;
            state      <= INPUT_0_IDLE_ST;
          end if;
          if s1_cyc_i = '0' then
            m_cyc_o  <= '0';
            m_stb_o  <= '0';
            s1_ack_o <= '0';
            state    <= INPUT_0_IDLE_ST;
          end if;

      end case;

      if rst_i = '1' then
        m_cyc_o  <= '0';
        m_stb_o  <= '0';
        s0_ack_o <= '0';
        s1_ack_o <= '0';
        state    <= INPUT_0_IDLE_ST;
      end if;
    end if;
  end process fsm_proc;

end architecture synthesis;

