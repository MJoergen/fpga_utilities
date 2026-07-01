-- ---------------------------------------------------------------------------------------
-- Description: This allows a Avalon MM Slave to be connected to an AXI Lite Master
--
-- SPDX-License-Identifier: MIT
-- ---------------------------------------------------------------------------------------

library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std.all;

entity axil_to_avm is
  generic (
    G_ADDR_BITS  : positive;
    G_DATA_BITS  : positive;
    G_BURST_BITS : positive := 8
  );
  port (
    clk_i             : in    std_logic;
    rst_i             : in    std_logic;

    -- AXI Lite interface (slave)
    s_awready_o       : out   std_logic;
    s_awvalid_i       : in    std_logic;
    s_awaddr_i        : in    std_logic_vector(G_ADDR_BITS - 1 downto 0);
    s_wready_o        : out   std_logic;
    s_wvalid_i        : in    std_logic;
    s_wdata_i         : in    std_logic_vector(G_DATA_BITS - 1 downto 0);
    s_wstrb_i         : in    std_logic_vector(G_DATA_BITS / 8 - 1 downto 0);
    s_bready_i        : in    std_logic;
    s_bvalid_o        : out   std_logic;
    s_bresp_o         : out   std_logic_vector(1 downto 0);
    s_arready_o       : out   std_logic;
    s_arvalid_i       : in    std_logic;
    s_araddr_i        : in    std_logic_vector(G_ADDR_BITS - 1 downto 0);
    s_rready_i        : in    std_logic;
    s_rvalid_o        : out   std_logic;
    s_rdata_o         : out   std_logic_vector(G_DATA_BITS - 1 downto 0);
    s_rresp_o         : out   std_logic_vector(1 downto 0);

    -- Avalon Memory Map interface (master)
    m_waitrequest_i   : in    std_logic;
    m_write_o         : out   std_logic;
    m_read_o          : out   std_logic;
    m_address_o       : out   std_logic_vector(G_ADDR_BITS - 1 downto 0);
    m_writedata_o     : out   std_logic_vector(G_DATA_BITS - 1 downto 0);
    m_byteenable_o    : out   std_logic_vector(G_DATA_BITS / 8 - 1 downto 0);
    m_burstcount_o    : out   std_logic_vector(G_BURST_BITS - 1 downto 0);
    m_readdatavalid_i : in    std_logic;
    m_readdata_i      : in    std_logic_vector(G_DATA_BITS - 1 downto 0)
  );
end entity axil_to_avm;

architecture rtl of axil_to_avm is

  type   state_type is (IDLE_ST, READING_ST);
  signal state : state_type := IDLE_ST;

  signal aw_active : std_logic;
  signal w_active  : std_logic;
  signal ar_active : std_logic;

  signal s_araddr : std_logic_vector(G_ADDR_BITS - 1 downto 0);

begin

  aw_active   <= s_awvalid_i and s_awready_o;
  w_active    <= s_wvalid_i  and s_wready_o;
  ar_active   <= s_arvalid_i and s_arready_o;

  -- Main state machine

  s_awready_o <= not m_waitrequest_i when state = IDLE_ST else
                 '0';
  s_wready_o  <= not m_waitrequest_i when state = IDLE_ST else
                 '0';
  s_arready_o <= not m_waitrequest_i when state = IDLE_ST else
                 '0';

  fsm_proc : process (clk_i)
  begin
    if rising_edge(clk_i) then
      if s_bready_i = '1' then
        s_bvalid_o <= '0';
      end if;
      if s_rready_i = '1' then
        s_rvalid_o <= '0';
      end if;
      if m_waitrequest_i = '0' then
        m_write_o <= '0';
        m_read_o  <= '0';
        if m_write_o = '1' then
          s_bvalid_o <= '1';
          s_bresp_o  <= (others => '0');
        end if;
      end if;
      if m_readdatavalid_i = '1' then
        s_rvalid_o <= '1';
        s_rdata_o  <= m_readdata_i;
        s_rresp_o  <= (others => '0');
      end if;

      case state is

        when IDLE_ST =>
          if aw_active = '1' and w_active = '1' then
            m_write_o      <= '1';
            m_read_o       <= '0';
            m_address_o    <= s_awaddr_i;
            m_writedata_o  <= s_wdata_i;
            m_byteenable_o <= s_wstrb_i;
            m_burstcount_o <= (0 => '1', others => '0');
            -- Stay in IDLE_ST, unless a read is simultaneous
            if ar_active = '1' then
              s_araddr <= s_araddr_i;
              state    <= READING_ST;
            end if;
          elsif ar_active = '1' then
            m_write_o      <= '0';
            m_read_o       <= '1';
            m_address_o    <= s_araddr_i;
            m_byteenable_o <= (others => '1');
            m_burstcount_o <= (0 => '1', others => '0');
          end if;

        when READING_ST =>
          if m_waitrequest_i = '0' then
            m_write_o      <= '0';
            m_read_o       <= '1';
            m_address_o    <= s_araddr;
            m_byteenable_o <= (others => '1');
            m_burstcount_o <= (0 => '1', others => '0');
            state          <= IDLE_ST;
          end if;

      end case;

      if rst_i = '1' then
        s_bvalid_o <= '0';
        s_rvalid_o <= '0';
        m_write_o  <= '0';
        m_read_o   <= '0';
        state      <= IDLE_ST;
      end if;
    end if;
  end process fsm_proc;

end architecture rtl;

