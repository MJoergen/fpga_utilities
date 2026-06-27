-- ---------------------------------------------------------------------------------------
-- Description: This allows an Avalon MM Slave to be connected to a Wishbone Master
--
-- SPDX-License-Identifier: MIT
-- ---------------------------------------------------------------------------------------

library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std.all;

entity wbus_to_avm is
  generic (
    G_BURST_BITS : positive := 8;
    G_ADDR_BITS  : positive := 16;
    G_DATA_BITS  : positive := 16
  );
  port (
    clk_i             : in    std_logic;
    rst_i             : in    std_logic;

    -- Wishbone input
    s_cyc_i           : in    std_logic;
    s_stall_o         : out   std_logic;
    s_stb_i           : in    std_logic;
    s_addr_i          : in    std_logic_vector(G_ADDR_BITS - 1 downto 0);
    s_we_i            : in    std_logic;
    s_wrdat_i         : in    std_logic_vector(G_DATA_BITS - 1 downto 0);
    s_sel_i           : in    std_logic_vector(G_DATA_BITS / 8 - 1 downto 0);
    s_ack_o           : out   std_logic;
    s_rddat_o         : out   std_logic_vector(G_DATA_BITS - 1 downto 0);

    -- Avalon MM ouput
    m_waitrequest_i   : in    std_logic;
    m_write_o         : out   std_logic;
    m_read_o          : out   std_logic;
    m_address_o       : out   std_logic_vector(G_ADDR_BITS - 1 downto 0);
    m_writedata_o     : out   std_logic_vector(G_DATA_BITS - 1 downto 0);
    m_byteenable_o    : out   std_logic_vector(G_DATA_BITS / 8 - 1 downto 0);
    m_burstcount_o    : out   std_logic_vector(G_BURST_BITS - 1 downto 0);
    m_readdata_i      : in    std_logic_vector(G_DATA_BITS - 1 downto 0);
    m_readdatavalid_i : in    std_logic
  );
end entity wbus_to_avm;

architecture rtl of wbus_to_avm is

  type state_type is (
    IDLE_ST,
    WRITING_ST,
    READING_ST
  );

  signal state : state_type := IDLE_ST;

begin

  assert (G_DATA_BITS mod 8) = 0
    report "ERROR"
    severity failure;

  s_stall_o <= '0' when state = IDLE_ST
               else '1';

  fsm_proc : process (clk_i)
  begin
    if rising_edge(clk_i) then
      s_ack_o <= '0';
      if m_waitrequest_i = '0' then
        m_write_o <= '0';
        m_read_o  <= '0';
      end if;

      case state is
        when IDLE_ST =>
          if s_cyc_i = '1' and s_stb_i = '1' then
            if s_we_i = '1' then
              m_write_o         <= '1';
              m_read_o          <= '0';
              m_address_o       <= s_addr_i;
              m_writedata_o     <= s_wrdat_i;
              m_byteenable_o    <= s_sel_i;
              m_burstcount_o    <= std_logic_vector(to_unsigned(1, G_BURST_BITS));
              state             <= WRITING_ST;
            else
              m_write_o         <= '0';
              m_read_o          <= '1';
              m_address_o       <= s_addr_i;
              m_byteenable_o    <= (others => '1');
              m_burstcount_o    <= std_logic_vector(to_unsigned(1, G_BURST_BITS));
              state             <= READING_ST;
            end if;
          end if;

        when WRITING_ST =>
          s_ack_o   <= '1';
          state     <= IDLE_ST;

        when READING_ST =>
          if m_readdatavalid_i = '1' then
            s_rddat_o <= m_readdata_i;
            s_ack_o   <= '1';
            state     <= IDLE_ST;
          end if;

      end case;

      if rst_i = '1' then
        s_ack_o   <= '0';
        m_write_o <= '0';
        m_read_o  <= '0';
        state     <= IDLE_ST;
      end if;
    end if;
  end process fsm_proc;

end architecture rtl;

