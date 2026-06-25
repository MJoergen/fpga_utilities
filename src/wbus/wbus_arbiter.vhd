-- ---------------------------------------------------------------------------------------
-- Description: Arbitrate between two different Wishbone masters
--
-- SPDX-License-Identifier: MIT
-- ---------------------------------------------------------------------------------------

library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std.all;

entity wbus_arbiter is
  generic (
    G_ADDR_BITS : positive;
    G_DATA_BITS : positive
  );
  port (
    clk_i      : in    std_logic;
    rst_i      : in    std_logic;

    -- Wishbone bus Slave interfaces
    s0_cyc_i   : in    std_logic;
    s0_stall_o : out   std_logic;
    s0_stb_i   : in    std_logic;
    s0_addr_i  : in    std_logic_vector(G_ADDR_BITS - 1 downto 0);
    s0_we_i    : in    std_logic;
    s0_wrdat_i : in    std_logic_vector(G_DATA_BITS - 1 downto 0);
    s0_sel_i   : in    std_logic_vector(G_DATA_BITS / 8 - 1 downto 0);
    s0_ack_o   : out   std_logic;
    s0_rddat_o : out   std_logic_vector(G_DATA_BITS - 1 downto 0);

    s1_cyc_i   : in    std_logic;
    s1_stall_o : out   std_logic;
    s1_stb_i   : in    std_logic;
    s1_addr_i  : in    std_logic_vector(G_ADDR_BITS - 1 downto 0);
    s1_we_i    : in    std_logic;
    s1_wrdat_i : in    std_logic_vector(G_DATA_BITS - 1 downto 0);
    s1_sel_i   : in    std_logic_vector(G_DATA_BITS / 8 - 1 downto 0);
    s1_ack_o   : out   std_logic;
    s1_rddat_o : out   std_logic_vector(G_DATA_BITS - 1 downto 0);

    -- Wishbone bus Master interface
    m_cyc_o    : out   std_logic;
    m_stall_i  : in    std_logic;
    m_stb_o    : out   std_logic;
    m_addr_o   : out   std_logic_vector(G_ADDR_BITS - 1 downto 0);
    m_we_o     : out   std_logic;
    m_wrdat_o  : out   std_logic_vector(G_DATA_BITS - 1 downto 0);
    m_sel_o    : out   std_logic_vector(G_DATA_BITS / 8 - 1 downto 0);
    m_ack_i    : in    std_logic;
    m_rddat_i  : in    std_logic_vector(G_DATA_BITS - 1 downto 0)
  );
end entity wbus_arbiter;

architecture rtl of wbus_arbiter is

  type   state_type is (S0_IDLE_ST, S1_IDLE_ST, S0_BUSY_ST, S1_BUSY_ST);
  signal state : state_type := S0_IDLE_ST;

begin

  assert s0_ack_o /= '1' or s1_ack_o /= '1' or rst_i = '1'
    report "wbus_arbiter: Invariant error where both slaves are ACK'ed"
    severity failure;

  assert s0_ack_o /= '1' or state /= S0_BUSY_ST or rst_i = '1'
    report "wbus_arbiter: Invariant error in state S0_BUSY_ST"
    severity failure;

  assert s1_ack_o /= '1' or state /= S1_BUSY_ST or rst_i = '1'
    report "wbus_arbiter: Invariant error in state S1_BUSY_ST"
    severity failure;

  s0_stall_o <= '0' when state = S0_IDLE_ST else
                '1';
  s1_stall_o <= '0' when state = S1_IDLE_ST else
                '1';

  fsm_proc : process (clk_i)
  begin
    if rising_edge(clk_i) then
      -- Single outstanding request only (see interfaces.md#wishbone).
      -- Bursts (multiple stb under one cyc) are NOT supported by this arbiter.
      if m_ack_i = '1' then
        m_cyc_o <= '0';
      end if;
      if m_stall_i = '0' then
        m_stb_o <= '0';
      end if;

      s0_ack_o <= '0';
      s1_ack_o <= '0';

      case state is

        when S0_IDLE_ST =>
          -- Validate invariant
          assert (m_cyc_o = '0' and m_stb_o = '0') or rst_i = '1'
            report "wbus_arbiter: Invariant error in state S0_IDLE_ST"
            severity failure;

          if s0_cyc_i = '0' and s1_cyc_i = '1' then
            state <= S1_IDLE_ST;
          elsif s0_cyc_i = '1' and s0_stb_i = '1' then
            m_cyc_o   <= s0_cyc_i;
            m_stb_o   <= s0_stb_i;
            m_addr_o  <= s0_addr_i;
            m_we_o    <= s0_we_i;
            m_wrdat_o <= s0_wrdat_i;
            m_sel_o   <= s0_sel_i;
            state     <= S0_BUSY_ST;
          end if;

        when S1_IDLE_ST =>
          -- Validate invariant
          assert (m_cyc_o = '0' and m_stb_o = '0') or rst_i = '1'
            report "wbus_arbiter: Invariant error in state S1_IDLE_ST"
            severity failure;

          if s0_cyc_i = '1' and s1_cyc_i = '0' then
            state <= S0_IDLE_ST;
          elsif s1_cyc_i = '1' and s1_stb_i = '1' then
            m_cyc_o   <= s1_cyc_i;
            m_stb_o   <= s1_stb_i;
            m_addr_o  <= s1_addr_i;
            m_we_o    <= s1_we_i;
            m_wrdat_o <= s1_wrdat_i;
            m_sel_o   <= s1_sel_i;
            state     <= S1_BUSY_ST;
          end if;

        when S0_BUSY_ST =>
          if m_ack_i = '1' then
            s0_ack_o   <= '1';
            s0_rddat_o <= m_rddat_i;
            state      <= S1_IDLE_ST;
          end if;
          if s0_cyc_i = '0' then
            m_cyc_o  <= '0';
            m_stb_o  <= '0';
            s0_ack_o <= '0';
            state    <= S1_IDLE_ST;
          end if;

        when S1_BUSY_ST =>
          if m_ack_i = '1' then
            s1_ack_o   <= '1';
            s1_rddat_o <= m_rddat_i;
            state      <= S0_IDLE_ST;
          end if;
          if s1_cyc_i = '0' then
            m_cyc_o  <= '0';
            m_stb_o  <= '0';
            s1_ack_o <= '0';
            state    <= S0_IDLE_ST;
          end if;

      end case;

      if rst_i = '1' then
        -- Reset clears only handshake/control signals; data is don't-care while cyc/stb is low
        m_cyc_o  <= '0';
        m_stb_o  <= '0';
        s0_ack_o <= '0';
        s1_ack_o <= '0';
        state    <= S0_IDLE_ST;
      end if;
    end if;
  end process fsm_proc;

end architecture rtl;

