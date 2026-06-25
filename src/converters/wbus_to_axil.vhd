-- ---------------------------------------------------------------------------------------
-- Description: This allows an AXI Lite Slave to be connected to a Wishbone Master
--
-- SPDX-License-Identifier: MIT
-- ---------------------------------------------------------------------------------------

library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std.all;

entity wbus_to_axil is
  generic (
    G_ADDR_BITS : positive;
    G_DATA_BITS : positive
  );
  port (
    clk_i       : in    std_logic;
    rst_i       : in    std_logic;

    -- Wishbone input
    s_cyc_i     : in    std_logic;
    s_stall_o   : out   std_logic;
    s_stb_i     : in    std_logic;
    s_addr_i    : in    std_logic_vector(G_ADDR_BITS - 1 downto 0);
    s_we_i      : in    std_logic;
    s_wrdat_i   : in    std_logic_vector(G_DATA_BITS - 1 downto 0);
    s_sel_i     : in    std_logic_vector(G_DATA_BITS / 8 - 1 downto 0);
    s_ack_o     : out   std_logic;
    s_rddat_o   : out   std_logic_vector(G_DATA_BITS - 1 downto 0);

    -- AXI Lite output
    m_awready_i : in    std_logic;
    m_awvalid_o : out   std_logic;
    m_awaddr_o  : out   std_logic_vector(G_ADDR_BITS - 1 downto 0);
    m_wready_i  : in    std_logic;
    m_wvalid_o  : out   std_logic;
    m_wdata_o   : out   std_logic_vector(G_DATA_BITS - 1 downto 0);
    m_wstrb_o   : out   std_logic_vector(G_DATA_BITS / 8 - 1 downto 0);
    m_bready_o  : out   std_logic;
    m_bvalid_i  : in    std_logic;
    m_bresp_i   : in    std_logic_vector(1 downto 0);
    m_arready_i : in    std_logic;
    m_arvalid_o : out   std_logic;
    m_araddr_o  : out   std_logic_vector(G_ADDR_BITS - 1 downto 0);
    m_rready_o  : out   std_logic;
    m_rvalid_i  : in    std_logic;
    m_rdata_i   : in    std_logic_vector(G_DATA_BITS - 1 downto 0);
    m_rresp_i   : in    std_logic_vector(1 downto 0)
  );
end entity wbus_to_axil;

architecture rtl of wbus_to_axil is

  type   state_type is (IDLE_ST, WRITING_ST, READING_ST, ABORTING_ST);
  signal state : state_type := IDLE_ST;

begin

  m_bready_o <= '1';
  m_rready_o <= '1';

  s_stall_o  <= '0' when state = IDLE_ST else
                '1';

  fsm_proc : process (clk_i)
  begin
    if rising_edge(clk_i) then
      s_ack_o <= '0';
      if m_awready_i = '1' then
        m_awvalid_o <= '0';
      end if;
      if m_arready_i = '1' then
        m_arvalid_o <= '0';
      end if;
      if m_wready_i = '1' then
        m_wvalid_o <= '0';
      end if;

      case state is

        when IDLE_ST =>
          if s_cyc_i = '1' and s_stb_i = '1' then
            if s_we_i = '1' then
              m_awvalid_o <= '1';
              m_awaddr_o  <= s_addr_i;

              m_wvalid_o  <= '1';
              m_wdata_o   <= s_wrdat_i;
              m_wstrb_o   <= s_sel_i;
              state       <= WRITING_ST;
            else
              m_arvalid_o <= '1';
              m_araddr_o  <= s_addr_i;
              state       <= READING_ST;
            end if;
          end if;

        when WRITING_ST =>
          if m_bvalid_i = '1' and m_bready_o = '1' then
            s_ack_o <= s_cyc_i;
            state   <= IDLE_ST;
          elsif s_cyc_i = '0' then
            state <= ABORTING_ST;
          end if;

        when READING_ST =>
          if m_rvalid_i = '1' and m_rready_o = '1' then
            s_ack_o   <= s_cyc_i;
            s_rddat_o <= m_rdata_i;
            state     <= IDLE_ST;
          elsif s_cyc_i = '0' then
            state <= ABORTING_ST;
          end if;

        when ABORTING_ST =>
          if m_bvalid_i = '1' and m_bready_o = '1' then
            state <= IDLE_ST;
          end if;
          if m_rvalid_i = '1' and m_rready_o = '1' then
            state <= IDLE_ST;
          end if;

      end case;

      if rst_i = '1' then
        s_ack_o     <= '0';
        -- s_rddat_o is don't care when s_ack_o is 0.
        m_awvalid_o <= '0';
        m_wvalid_o  <= '0';
        m_arvalid_o <= '0';
        state       <= IDLE_ST;
      end if;
    end if;
  end process fsm_proc;

end architecture rtl;

