-- ---------------------------------------------------------------------------------------
-- Description: Wishbone address decoder. Routes transactions from one upstream Wishbone
-- master to one of G_NUM_SLAVES downstream slaves, selected by the high bits of the
-- address. Unknown addresses return C_BAD_SLAVE (low bits of x"BAD51A73"); timeouts
-- return C_TIMEOUT (low bits of x"DEADBEEF").
--
-- SPDX-License-Identifier: MIT
-- ---------------------------------------------------------------------------------------

library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std.all;

library work;
  use work.wbus_pkg.all;

entity wbus_mapper is
  generic (
    G_ASYNC_RESET      : boolean := false;
    G_TIMEOUT_MAX      : positive := 100;
    G_NUM_SLAVES       : positive := 2;
    G_MASTER_ADDR_BITS : positive := 16;
    G_SLAVE_ADDR_BITS  : positive := 12;
    G_DATA_BITS        : positive := 32
  );
  port (
    clk_i     : in    std_logic;
    rst_i     : in    std_logic;

    -- Wishbone bus Slave interface (single upstream Wishbone master)
    s_cyc_i   : in    std_logic;
    s_stall_o : out   std_logic;
    s_stb_i   : in    std_logic;
    s_addr_i  : in    std_logic_vector(G_MASTER_ADDR_BITS - 1 downto 0);
    s_we_i    : in    std_logic;
    s_wrdat_i : in    std_logic_vector(G_DATA_BITS - 1 downto 0);
    s_sel_i   : in    std_logic_vector(G_DATA_BITS / 8 - 1 downto 0);
    s_ack_o   : out   std_logic;
    s_rddat_o : out   std_logic_vector(G_DATA_BITS - 1 downto 0);

    -- Wishbone bus Master interface (G_NUM_SLAVES downstream Wishbone slaves)
    m_rst_o   : out   std_logic_vector(G_NUM_SLAVES - 1 downto 0);
    m_cyc_o   : out   std_logic;
    m_stall_i : in    std_logic_vector(G_NUM_SLAVES - 1 downto 0);
    m_stb_o   : out   std_logic_vector(G_NUM_SLAVES - 1 downto 0);
    m_addr_o  : out   std_logic_vector(G_SLAVE_ADDR_BITS - 1 downto 0);
    m_we_o    : out   std_logic;
    m_wrdat_o : out   std_logic_vector(G_DATA_BITS - 1 downto 0);
    m_sel_o   : out   std_logic_vector(G_DATA_BITS / 8 - 1 downto 0);
    m_ack_i   : in    std_logic_vector(G_NUM_SLAVES - 1 downto 0);
    m_rddat_i : in    slv_array_type(G_NUM_SLAVES - 1 downto 0)(G_DATA_BITS - 1 downto 0)
  );
end entity wbus_mapper;

architecture rtl of wbus_mapper is

  -- Diagnostic responses, sized to G_DATA_BITS. Low bits of well-known constants are
  -- preserved; wider buses zero-extend, narrower buses truncate to the low bits.
  constant C_BAD_SLAVE_RAW : std_logic_vector(31 downto 0)               := x"BAD51A73";
  constant C_TIMEOUT_RAW   : std_logic_vector(31 downto 0)               := x"DEADBEEF";

  constant C_BAD_SLAVE     : std_logic_vector(G_DATA_BITS - 1 downto 0)  :=
    std_logic_vector(resize(unsigned(C_BAD_SLAVE_RAW), G_DATA_BITS));
  constant C_TIMEOUT       : std_logic_vector(G_DATA_BITS - 1 downto 0)  :=
    std_logic_vector(resize(unsigned(C_TIMEOUT_RAW), G_DATA_BITS));

  type   state_type is (IDLE_ST, BUSY_ST);
  signal state : state_type                                  := IDLE_ST;

  signal timeout_cnt : natural range 0 to G_TIMEOUT_MAX      := 0;
  signal slave_num   : natural range 0 to G_NUM_SLAVES - 1;

  signal m_rst : std_logic_vector(G_NUM_SLAVES - 1 downto 0) := (others => '1');  -- Synchronous reset

  -- Reduce fan-out on reset signal
  attribute keep : string;
  attribute keep of m_rst : signal is "true";

begin

  -- Elaboration-time constraints
  assert (G_DATA_BITS mod 8) = 0
    report "wbus_mapper: G_DATA_BITS must be a multiple of 8"
    severity failure;

  assert G_MASTER_ADDR_BITS > G_SLAVE_ADDR_BITS
    report "wbus_mapper: G_MASTER_ADDR_BITS must be greater than G_SLAVE_ADDR_BITS"
    severity failure;

  s_stall_o <= '0' when state = IDLE_ST and (or(m_rst)) = '0' else
               '1';

  m_rst_o   <= m_rst;

  rst_proc : process (clk_i, rst_i)
  begin
    if rising_edge(clk_i) then
      m_rst <= (others => rst_i);
    end if;

    -- Optional asynchronous reset
    if G_ASYNC_RESET and rst_i = '1' then
      m_rst <= (others => '1');
    end if;
  end process rst_proc;


  fsm_proc : process (clk_i)
    variable slave_num_v : std_logic_vector(G_MASTER_ADDR_BITS - G_SLAVE_ADDR_BITS - 1 downto 0);
    variable idx_v       : natural range 0 to G_NUM_SLAVES - 1;
  begin
    if rising_edge(clk_i) then
      -- Clear stb to a slave when it has accepted the request (stall low and stb high)
      if or(m_stall_i and m_stb_o) = '0' then
        m_stb_o <= (others => '0');
      end if;
      s_ack_o <= '0';

      case state is

        when IDLE_ST =>
          if s_cyc_i = '1' and s_stb_i = '1' then
            slave_num_v := s_addr_i(G_MASTER_ADDR_BITS - 1 downto G_SLAVE_ADDR_BITS);
            if to_integer(unsigned(slave_num_v)) < G_NUM_SLAVES then
              idx_v          := to_integer(unsigned(slave_num_v));
              slave_num      <= idx_v;
              m_addr_o       <= s_addr_i(G_SLAVE_ADDR_BITS - 1 downto 0);
              m_wrdat_o      <= s_wrdat_i;
              m_sel_o        <= s_sel_i;
              m_we_o         <= s_we_i;
              m_cyc_o        <= '1';
              m_stb_o        <= (others => '0');
              m_stb_o(idx_v) <= '1';
              timeout_cnt    <= 0;
              state          <= BUSY_ST;
            else
              s_rddat_o <= C_BAD_SLAVE;
              s_ack_o   <= '1';
              state     <= IDLE_ST;
            end if;
          end if;

        when BUSY_ST =>
          if m_ack_i(slave_num) = '1' then
            s_rddat_o <= m_rddat_i(slave_num);
            s_ack_o   <= '1';
            m_cyc_o   <= '0';
            state     <= IDLE_ST;
          elsif timeout_cnt < G_TIMEOUT_MAX then
            timeout_cnt <= timeout_cnt + 1;
          else
            s_rddat_o <= C_TIMEOUT;
            s_ack_o   <= '1';
            m_cyc_o   <= '0';
            state     <= IDLE_ST;
          end if;

      end case;

      -- synchronous reset, per clause 7, and functional reset on bus idle
      if rst_i = '1' or s_cyc_i = '0' then
        s_ack_o     <= '0';
        m_stb_o     <= (others => '0');
        m_cyc_o     <= '0';
        timeout_cnt <= 0;
        state       <= IDLE_ST;
      end if;
    end if;
  end process fsm_proc;

end architecture rtl;

