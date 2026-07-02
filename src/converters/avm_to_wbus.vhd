-- ---------------------------------------------------------------------------------------
-- Description: This allows a Wishbone Slave to be connected to an Avalon MM Master
--
-- SPDX-License-Identifier: MIT
-- ---------------------------------------------------------------------------------------

library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std.all;

entity avm_to_wbus is
  generic (
    G_ADDR_BITS  : positive;
    G_DATA_BITS  : positive;
    G_BURST_BITS : positive := 8
  );
  port (
    clk_i             : in    std_logic;
    rst_i             : in    std_logic;

    -- Avalon MM input
    s_waitrequest_o   : out   std_logic;
    s_write_i         : in    std_logic;
    s_read_i          : in    std_logic;
    s_address_i       : in    std_logic_vector(G_ADDR_BITS - 1 downto 0);
    s_writedata_i     : in    std_logic_vector(G_DATA_BITS - 1 downto 0);
    s_byteenable_i    : in    std_logic_vector(G_DATA_BITS / 8 - 1 downto 0);
    s_burstcount_i    : in    std_logic_vector(G_BURST_BITS - 1 downto 0);
    s_readdata_o      : out   std_logic_vector(G_DATA_BITS - 1 downto 0);
    s_readdatavalid_o : out   std_logic;

    -- Wishbone output
    m_cyc_o           : out   std_logic;
    m_stall_i         : in    std_logic;
    m_stb_o           : out   std_logic;
    m_addr_o          : out   std_logic_vector(G_ADDR_BITS - 1 downto 0);
    m_we_o            : out   std_logic;
    m_wrdat_o         : out   std_logic_vector(G_DATA_BITS - 1 downto 0);
    m_sel_o           : out   std_logic_vector(G_DATA_BITS / 8 - 1 downto 0);
    m_ack_i           : in    std_logic;
    m_rddat_i         : in    std_logic_vector(G_DATA_BITS - 1 downto 0)
  );
end entity avm_to_wbus;

architecture rtl of avm_to_wbus is

  type     state_type is (IDLE_ST, WRITING_ST, READING_ST);
  signal   state : state_type                           := IDLE_ST;

begin

  s_waitrequest_o <= '0' when state = IDLE_ST
                     else '1';

  assert s_write_i /= '1' or s_read_i /= '1'
    report "ERROR: Both write and read"
    severity failure;

  fsm_proc : process (clk_i)
  begin
    if rising_edge(clk_i) then
      s_readdatavalid_o <= '0';

      if m_stall_i = '0' then
        m_stb_o <= '0';
      end if;
      if m_ack_i = '1' then
        m_cyc_o <= '0';
        m_stb_o <= '0';
      end if;

      case state is

        when IDLE_ST =>
          if s_write_i = '1' then
            assert unsigned(s_burstcount_i) = 1
              report "burst not supported"
              severity failure;

            m_cyc_o   <= '1';
            m_stb_o   <= '1';
            m_addr_o  <= s_address_i;
            m_we_o    <= '1';
            m_wrdat_o <= s_writedata_i;
            m_sel_o   <= s_byteenable_i;
            state     <= WRITING_ST;
          end if;

          if s_read_i = '1' then
            m_cyc_o   <= '1';
            m_stb_o   <= '1';
            m_addr_o  <= s_address_i;
            m_we_o    <= '0';
            m_sel_o   <= (others => '1');
            state     <= READING_ST;
          end if;

        when WRITING_ST =>
          if m_ack_i = '1' then
            state <= IDLE_ST;
          end if;

        when READING_ST =>
          if m_ack_i = '1' then
            s_readdata_o      <= m_rddat_i;
            s_readdatavalid_o <= '1';
            state             <= IDLE_ST;
          end if;

      end case;

      if rst_i = '1' then
        s_readdatavalid_o <= '0';
        m_cyc_o           <= '0';
        m_stb_o           <= '0';
        state             <= IDLE_ST;
      end if;
    end if;
  end process fsm_proc;

end architecture rtl;

