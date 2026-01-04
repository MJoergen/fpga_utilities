-- ----------------------------------------------------------------------------
-- Author     : Michael Jørgensen
-- Platform   : AMD Artix 7
-- ----------------------------------------------------------------------------
-- Description: Arbitrate between two different pairs of AXI masters.
-- If only half of AXI Master is transferred, then the other AXI Master is blocked until
-- the second half is transferred.
-- In other words, one word from each pair must be transferred, before grant can be
-- switched.
-- The main use of this block is for arbitrating between two AW/W pairs in the AXI Lite
-- interface.
--
-- The complexity in this module is to determine when it's safe to switch grant from one
-- Master to another. This is the case when all data has been accepted by the slave AND
-- the current Master is not sending new data.
-- ----------------------------------------------------------------------------

library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std.all;

entity axis_arbiter_pair is
  generic (
    G_A_DATA_SIZE : natural;
    G_B_DATA_SIZE : natural
  );
  port (
    clk_i        : in    std_logic;
    rst_i        : in    std_logic;

    -- First pair of AXI Masters
    s0_a_ready_o : out   std_logic;
    s0_a_valid_i : in    std_logic;
    s0_a_data_i  : in    std_logic_vector(G_A_DATA_SIZE - 1 downto 0);
    s0_b_ready_o : out   std_logic;
    s0_b_valid_i : in    std_logic;
    s0_b_data_i  : in    std_logic_vector(G_B_DATA_SIZE - 1 downto 0);

    -- Second pair of AXI Masters
    s1_a_ready_o : out   std_logic;
    s1_a_valid_i : in    std_logic;
    s1_a_data_i  : in    std_logic_vector(G_A_DATA_SIZE - 1 downto 0);
    s1_b_ready_o : out   std_logic;
    s1_b_valid_i : in    std_logic;
    s1_b_data_i  : in    std_logic_vector(G_B_DATA_SIZE - 1 downto 0);

    m_a_ready_i  : in    std_logic;
    m_a_valid_o  : out   std_logic;
    m_a_data_o   : out   std_logic_vector(G_A_DATA_SIZE - 1 downto 0);
    m_b_ready_i  : in    std_logic;
    m_b_valid_o  : out   std_logic;
    m_b_data_o   : out   std_logic_vector(G_B_DATA_SIZE - 1 downto 0)
  );
end entity axis_arbiter_pair;

architecture synthesis of axis_arbiter_pair is

  -- The state determines which Master is granted access.
  -- Note: Only one Master may be granted access at a time.
  -- If both Masters need to deliver data simultaneously then
  -- additional FIFOs can be inserted before this arbiter.

  type   state_type is (INPUT_0_ST, INPUT_1_ST);
  signal state : state_type      := INPUT_0_ST;

  type   busy_type is (IDLE_ST, BUSY_A_ST, BUSY_B_ST);
  signal s0_state    : busy_type := IDLE_ST;
  signal s0_accept_a : std_logic;
  signal s0_accept_b : std_logic;
  signal s1_state    : busy_type := IDLE_ST;
  signal s1_accept_a : std_logic;
  signal s1_accept_b : std_logic;

begin

  -- Data is accepted only when we can process it, i.e. when m_valid_o is 0 or will be set
  -- to zero in this clock cycle.
  s0_a_ready_o <= (m_a_ready_i or not m_a_valid_o) when state = INPUT_0_ST else
                  '0';
  s0_b_ready_o <= (m_b_ready_i or not m_b_valid_o) when state = INPUT_0_ST else
                  '0';
  s1_a_ready_o <= (m_a_ready_i or not m_a_valid_o) when state = INPUT_1_ST else
                  '0';
  s1_b_ready_o <= (m_b_ready_i or not m_b_valid_o) when state = INPUT_1_ST else
                  '0';

  s0_accept_a  <= s0_a_valid_i and s0_a_ready_o;
  s0_accept_b  <= s0_b_valid_i and s0_b_ready_o;

  s0_busy_proc : process (clk_i)
  begin
    if rising_edge(clk_i) then

      case s0_state is

        when IDLE_ST =>
          if s0_accept_a and not s0_accept_b then
            s0_state <= BUSY_A_ST;
          end if;
          if not s0_accept_a and s0_accept_b then
            s0_state <= BUSY_B_ST;
          end if;

        when BUSY_A_ST =>
          if not s0_accept_a and s0_accept_b then
            s0_state <= IDLE_ST;
          end if;

        when BUSY_B_ST =>
          if s0_accept_a and not s0_accept_b then
            s0_state <= IDLE_ST;
          end if;

      end case;

      if rst_i = '1' then
        s0_state <= IDLE_ST;
      end if;
    end if;
  end process s0_busy_proc;

  busy_assert : assert s0_state = IDLE_ST or s1_state = IDLE_ST or rst_i = '1';

  s1_accept_a  <= s1_a_valid_i and s1_a_ready_o;
  s1_accept_b  <= s1_b_valid_i and s1_b_ready_o;

  s1_busy_proc : process (clk_i)
  begin
    if rising_edge(clk_i) then

      case s1_state is

        when IDLE_ST =>
          if s1_accept_a and not s1_accept_b then
            s1_state <= BUSY_A_ST;
          end if;
          if not s1_accept_a and s1_accept_b then
            s1_state <= BUSY_B_ST;
          end if;

        when BUSY_A_ST =>
          if not s1_accept_a and s1_accept_b then
            s1_state <= IDLE_ST;
          end if;

        when BUSY_B_ST =>
          if s1_accept_a and not s1_accept_b then
            s1_state <= IDLE_ST;
          end if;

      end case;

      if rst_i = '1' then
        s1_state <= IDLE_ST;
      end if;
    end if;
  end process s1_busy_proc;


  fsm_proc : process (clk_i)
  begin
    if rising_edge(clk_i) then
      -- The slave has accepted our data.
      if m_a_ready_i = '1' then
        m_a_valid_o <= '0';
      end if;
      if m_b_ready_i = '1' then
        m_b_valid_o <= '0';
      end if;

      case state is

        when INPUT_0_ST =>
          -- Accept data from Master 0 first half
          if s0_a_valid_i = '1' and s0_a_ready_o = '1' then
            m_a_data_o  <= s0_a_data_i;
            m_a_valid_o <= '1';
          end if;
          -- Accept data from Master 0 second half
          if s0_b_valid_i = '1' and s0_b_ready_o = '1' then
            m_b_data_o  <= s0_b_data_i;
            m_b_valid_o <= '1';
          end if;

          -- Can we switch?
          if (s0_state = IDLE_ST) and
             (s0_a_valid_i = '0' and s0_b_valid_i = '0') and
             (s1_a_valid_i = '1' or s1_b_valid_i = '1') then
            state <= INPUT_1_ST;
          end if;

        when INPUT_1_ST =>
          -- Accept data from Master 1 first half
          if s1_a_valid_i = '1' and s1_a_ready_o = '1' then
            m_a_data_o  <= s1_a_data_i;
            m_a_valid_o <= '1';
          end if;
          -- Accept data from Master 1 second half
          if s1_b_valid_i = '1' and s1_b_ready_o = '1' then
            m_b_data_o  <= s1_b_data_i;
            m_b_valid_o <= '1';
          end if;

          -- Can we switch?
          if (s1_state = IDLE_ST) and
             (s1_a_valid_i = '0' and s1_b_valid_i = '0') and
             (s0_a_valid_i = '1' or s0_b_valid_i = '1') then
            state <= INPUT_0_ST;
          end if;

      end case;

      if rst_i = '1' then
        m_a_valid_o <= '0';
        m_b_valid_o <= '0';
        state       <= INPUT_0_ST;
      end if;
    end if;
  end process fsm_proc;

end architecture synthesis;

