-- ----------------------------------------------------------------------------
-- Title      : Main FPGA
-- Project    : XENTA, RCU, PCB1036 Board
-- ----------------------------------------------------------------------------
-- File       : wbus_mapper.vhd
-- Author     : Michael Jørgensen
-- Company    : Weibel Scientific
-- Created    : 2025-06-10
-- Platform   : AMD Artix 7
-- ----------------------------------------------------------------------------
-- Description: Wishbone mapper
-- ----------------------------------------------------------------------------

library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std_unsigned.all;

library work;
  use work.wbus_pkg.slv32_array_type;

entity wbus_mapper is
  generic (
    G_TIMEOUT          : natural := 100;
    G_NUM_SLAVES       : natural;
    G_MASTER_ADDR_SIZE : natural;
    G_SLAVE_ADDR_SIZE  : natural
  );
  port (
    clk_i          : in    std_logic;
    rst_i          : in    std_logic;

    -- Wishbone bus Slave interface
    s_wbus_cyc_i   : in    std_logic;                                         -- Valid bus cycle
    s_wbus_stall_o : out   std_logic;
    s_wbus_stb_i   : in    std_logic;                                         -- Strobe signals / core select signal
    s_wbus_addr_i  : in    std_logic_vector(G_MASTER_ADDR_SIZE - 1 downto 0); -- lower address bits
    s_wbus_we_i    : in    std_logic;                                         -- Write enable
    s_wbus_wrdat_i : in    std_logic_vector(31 downto 0);                     -- Write Databus
    s_wbus_ack_o   : out   std_logic;                                         -- Bus cycle acknowledge
    s_wbus_rddat_o : out   std_logic_vector(31 downto 0);                     -- Read Databus

    -- Wishbone bus Master interface
    m_wbus_rst_o   : out   std_logic_vector(G_NUM_SLAVES - 1 downto 0);       -- Synchronous reset
    m_wbus_cyc_o   : out   std_logic;                                         -- Valid bus cycle
    m_wbus_stall_i : in    std_logic_vector(G_NUM_SLAVES - 1 downto 0);       -- Strobe signals / core select signal
    m_wbus_stb_o   : out   std_logic_vector(G_NUM_SLAVES - 1 downto 0);       -- Strobe signals / core select signal
    m_wbus_addr_o  : out   std_logic_vector(G_SLAVE_ADDR_SIZE - 1 downto 0);  -- lower address bits
    m_wbus_we_o    : out   std_logic;                                         -- Write enable
    m_wbus_wrdat_o : out   std_logic_vector(31 downto 0);                     -- Write Databus
    m_wbus_ack_i   : in    std_logic_vector(G_NUM_SLAVES - 1 downto 0);       -- Bus cycle acknowledge
    m_wbus_rddat_i : in    slv32_array_type(G_NUM_SLAVES - 1 downto 0)        -- Read Databus
  );
end entity wbus_mapper;

architecture synthesis of wbus_mapper is

  type   state_type is (IDLE_ST, BUSY_ST);
  signal state : state_type                                       := IDLE_ST;

  signal timeout_cnt : natural range 0 to G_TIMEOUT               := 0;
  signal slave_num   : natural range 0 to G_NUM_SLAVES - 1;

  signal m_wbus_rst : std_logic_vector(G_NUM_SLAVES - 1 downto 0) := (others => '1');  -- Synchronous reset

  -- Reduce fan-out on reset signal
  attribute keep : string;
  attribute keep of m_wbus_rst : signal is "true";

begin

  s_wbus_stall_o <= '0' when state = IDLE_ST else
                    '1';

  m_wbus_rst_o   <= m_wbus_rst;

  rst_proc : process (clk_i, rst_i)
  begin
    if rising_edge(clk_i) then
      m_wbus_rst <= (others => rst_i);
    end if;

    -- Asynchronuous reset
    if rst_i = '1' then
      m_wbus_rst <= (others => '1');
    end if;
  end process rst_proc;


  stb_proc : process (clk_i)
    variable slave_num_v : std_logic_vector(G_MASTER_ADDR_SIZE - G_SLAVE_ADDR_SIZE - 1 downto 0);
    variable idx_v       : natural range 0 to G_NUM_SLAVES - 1;
  begin
    if rising_edge(clk_i) then
      if (m_wbus_stall_i and m_wbus_stb_o) = 0 then
        m_wbus_stb_o <= (others => '0');
        m_wbus_we_o  <= '0';
      end if;
      s_wbus_ack_o <= '0';

      case state is

        when IDLE_ST =>
          if s_wbus_cyc_i = '1' and s_wbus_stb_i = '1' then
            slave_num_v := s_wbus_addr_i(G_MASTER_ADDR_SIZE - 1 downto G_SLAVE_ADDR_SIZE);
            if to_integer(slave_num_v) < G_NUM_SLAVES then
              idx_v               := to_integer(slave_num_v);
              slave_num           <= idx_v;
              m_wbus_addr_o       <= s_wbus_addr_i(G_SLAVE_ADDR_SIZE - 1 downto 0);
              m_wbus_wrdat_o      <= s_wbus_wrdat_i;
              m_wbus_we_o         <= s_wbus_we_i;
              m_wbus_cyc_o        <= '1';
              m_wbus_stb_o        <= (others => '0');
              m_wbus_stb_o(idx_v) <= '1';
              timeout_cnt         <= 0;
              state               <= BUSY_ST;
            else
              s_wbus_rddat_o <= X"BAD51A73"; -- "Bad Slave"
              s_wbus_ack_o   <= '1';
              state          <= IDLE_ST;
            end if;
          end if;

        when BUSY_ST =>
          if m_wbus_ack_i(idx_v) = '1' then
            s_wbus_rddat_o <= m_wbus_rddat_i(idx_v);
            s_wbus_ack_o   <= '1';
            m_wbus_cyc_o   <= '0';
            state          <= IDLE_ST;
          end if;
          if timeout_cnt < G_TIMEOUT then
            timeout_cnt <= timeout_cnt + 1;
          else
            s_wbus_rddat_o <= X"DEADBEEF";
            s_wbus_ack_o   <= '1';
            m_wbus_cyc_o   <= '0';
            state          <= IDLE_ST;
          end if;

      end case;

      if rst_i = '1' or s_wbus_cyc_i = '0' then
        s_wbus_ack_o <= '0';
        m_wbus_stb_o <= (others => '0');
        m_wbus_cyc_o <= '0';
        timeout_cnt  <= 0;
        state        <= IDLE_ST;
      end if;
    end if;
  end process stb_proc;

end architecture synthesis;

