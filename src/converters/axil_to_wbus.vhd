-- ---------------------------------------------------------------------------------------
-- Description: This allows a Wishbone Slave to be connected to an AXI Lite Master
--
-- SPDX-License-Identifier: MIT
-- ---------------------------------------------------------------------------------------

library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std.all;

entity axil_to_wbus is
  generic (
    G_ADDR_BITS : positive;
    G_DATA_BITS : positive;
    G_TIMEOUT   : positive := 100
  );
  port (
    clk_i       : in    std_logic;
    rst_i       : in    std_logic;

    -- AXI Lite input
    s_awready_o : out   std_logic;
    s_awvalid_i : in    std_logic;
    s_awaddr_i  : in    std_logic_vector(G_ADDR_BITS - 1 downto 0);
    s_wready_o  : out   std_logic;
    s_wvalid_i  : in    std_logic;
    s_wdata_i   : in    std_logic_vector(G_DATA_BITS - 1 downto 0);
    s_wstrb_i   : in    std_logic_vector(G_DATA_BITS / 8 - 1 downto 0);
    s_bready_i  : in    std_logic;
    s_bvalid_o  : out   std_logic;
    s_bresp_o   : out   std_logic_vector(1 downto 0);
    s_arready_o : out   std_logic;
    s_arvalid_i : in    std_logic;
    s_araddr_i  : in    std_logic_vector(G_ADDR_BITS - 1 downto 0);
    s_rready_i  : in    std_logic;
    s_rvalid_o  : out   std_logic;
    s_rdata_o   : out   std_logic_vector(G_DATA_BITS - 1 downto 0);
    s_rresp_o   : out   std_logic_vector(1 downto 0);

    -- Wishbone output
    m_cyc_o     : out   std_logic;
    m_stall_i   : in    std_logic;
    m_stb_o     : out   std_logic;
    m_addr_o    : out   std_logic_vector(G_ADDR_BITS - 1 downto 0);
    m_we_o      : out   std_logic;
    m_wrdat_o   : out   std_logic_vector(G_DATA_BITS - 1 downto 0);
    m_sel_o     : out   std_logic_vector(G_DATA_BITS / 8 - 1 downto 0);
    m_ack_i     : in    std_logic;
    m_rddat_i   : in    std_logic_vector(G_DATA_BITS - 1 downto 0)
  );
end entity axil_to_wbus;

architecture rtl of axil_to_wbus is

  type     state_type is (IDLE_ST, WRITING_ST, READING_ST);
  signal   state : state_type                           := IDLE_ST;

  signal   time_cnt : natural range 0 to G_TIMEOUT;

  constant C_RESP_OKAY   : std_logic_vector(1 downto 0) := "00";
  constant C_RESP_SLVERR : std_logic_vector(1 downto 0) := "10";

begin

  -- AW and W streams wait for each other. Data only propagated when both streams are
  -- available.
  s_awready_o <= ((not m_stb_o) or (not m_stall_i)) and
                 (s_wvalid_i) and
                 (s_bready_i or not s_bvalid_o) and
                 not (s_arvalid_i)
                 when state = IDLE_ST else
                 '0';
  s_wready_o  <= ((not m_stb_o) or (not m_stall_i)) and
                 (s_awvalid_i) and
                 (s_bready_i or not s_bvalid_o) and
                 not (s_arvalid_i)
                 when state = IDLE_ST else
                 '0';

  s_arready_o <= ((not m_stb_o) or (not m_stall_i)) and
                 (s_rready_i or not s_rvalid_o)
                 when state = IDLE_ST else
                 '0';

  fsm_proc : process (clk_i)
  begin
    if rising_edge(clk_i) then
      s_bresp_o <= C_RESP_OKAY;
      s_rresp_o <= C_RESP_OKAY;

      if m_stall_i = '0' then
        m_stb_o <= '0';
      end if;
      if m_ack_i = '1' then
        m_cyc_o <= '0';
        m_stb_o <= '0';
      end if;

      if s_bready_i = '1' then
        s_bvalid_o <= '0';
      end if;
      if s_rready_i = '1' then
        s_rvalid_o <= '0';
      end if;

      case state is

        when IDLE_ST =>
          time_cnt <= 0;
          if s_awvalid_i = '1' and s_awready_o = '1' and
             s_wvalid_i = '1' and s_wready_o = '1' then
            -- Both AW and W streams are valid.
            m_cyc_o   <= '1';
            m_stb_o   <= '1';
            m_addr_o  <= s_awaddr_i;
            m_we_o    <= '1';
            m_wrdat_o <= s_wdata_i;
            m_sel_o   <= s_wstrb_i;
            state     <= WRITING_ST;
          elsif s_arvalid_i = '1' and s_arready_o = '1' then
            -- AR stream valid
            m_cyc_o  <= '1';
            m_stb_o  <= '1';
            m_addr_o <= s_araddr_i;
            m_we_o   <= '0';
            m_sel_o  <= (others => '1');
            state    <= READING_ST;
          end if;

        when WRITING_ST =>
          time_cnt <= time_cnt + 1;
          if time_cnt = G_TIMEOUT - 1 then
            -- Send back B response
            s_bresp_o  <= C_RESP_SLVERR;
            m_cyc_o    <= '0';
            m_stb_o    <= '0';
            s_bvalid_o <= '1';
            state      <= IDLE_ST;
          end if;
          if m_ack_i = '1' then
            -- Send back B response
            m_cyc_o    <= '0';
            m_stb_o    <= '0';
            s_bvalid_o <= '1';
            state      <= IDLE_ST;
          end if;

        when READING_ST =>
          time_cnt <= time_cnt + 1;
          if time_cnt = G_TIMEOUT - 1 then
            -- Send back R response
            s_rresp_o  <= C_RESP_SLVERR;
            m_cyc_o    <= '0';
            m_stb_o    <= '0';
            s_rvalid_o <= '1';
            -- s_rdata_o is don't-care when s_rresp_o /= OKAY
            state      <= IDLE_ST;
          end if;
          if m_ack_i = '1' then
            -- Send back R response
            m_cyc_o    <= '0';
            m_stb_o    <= '0';
            s_rdata_o  <= m_rddat_i;
            s_rvalid_o <= '1';
            state      <= IDLE_ST;
          end if;

      end case;

      if rst_i = '1' then
        time_cnt   <= 0;
        -- data/address/we/sel/resp are don't-care while valid signals are low; not reset to save area
        m_cyc_o    <= '0';
        m_stb_o    <= '0';
        s_bvalid_o <= '0';
        s_rvalid_o <= '0';
        state      <= IDLE_ST;
      end if;
    end if;
  end process fsm_proc;

end architecture rtl;

