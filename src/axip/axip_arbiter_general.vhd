-- Author     : Michael Jørgensen
-- Platform   : AMD Artix 7
-- ----------------------------------------------------------------------------
-- Description: Arbitrate between several different AXI masters
-- ----------------------------------------------------------------------------

library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std.all;

entity axip_arbiter_general is
  generic (
    G_NUM_MASTERS : natural;
    G_DATA_SIZE   : natural
  );
  port (
    clk_i     : in    std_logic;
    rst_i     : in    std_logic;

    s_ready_o : out   std_logic_vector(G_NUM_MASTERS - 1 downto 0);
    s_valid_i : in    std_logic_vector(G_NUM_MASTERS - 1 downto 0);
    s_data_i  : in    std_logic_vector(G_NUM_MASTERS * G_DATA_SIZE - 1 downto 0);
    s_last_i  : in    std_logic_vector(G_NUM_MASTERS - 1 downto 0);

    m_ready_i : in    std_logic;
    m_valid_o : out   std_logic;
    m_data_o  : out   std_logic_vector(G_DATA_SIZE - 1 downto 0);
    m_last_o  : out   std_logic
  );
end entity axip_arbiter_general;

architecture synthesis of axip_arbiter_general is

  subtype  R_LEFT is natural range G_NUM_MASTERS - 1 downto G_NUM_MASTERS / 2;

  subtype  R_LEFT_DATA is natural range G_DATA_SIZE * G_NUM_MASTERS - 1 downto G_DATA_SIZE * (G_NUM_MASTERS / 2);

  subtype  R_RIGHT is natural range G_NUM_MASTERS / 2 - 1 downto 0;

  subtype  R_RIGHT_DATA is natural range G_DATA_SIZE * (G_NUM_MASTERS / 2) - 1 downto G_DATA_SIZE * 0;

  constant C_NUM_LEFT  : natural := R_LEFT'high - R_LEFT'low + 1;
  constant C_NUM_RIGHT : natural := R_RIGHT'high - R_RIGHT'low + 1;

  signal   left_ready : std_logic;
  signal   left_valid : std_logic;
  signal   left_data  : std_logic_vector(G_DATA_SIZE - 1 downto 0);
  signal   left_last  : std_logic;

  signal   right_ready : std_logic;
  signal   right_valid : std_logic;
  signal   right_data  : std_logic_vector(G_DATA_SIZE - 1 downto 0);
  signal   right_last  : std_logic;

begin

  iterate_gen : if G_NUM_MASTERS = 1 generate

    -- Only one master
    m_data_o     <= s_data_i;
    m_valid_o    <= s_valid_i(0);
    m_last_o     <= s_last_i(0);
    s_ready_o(0) <= m_ready_i;

  elsif G_NUM_MASTERS = 2 generate

    -- Just two masters
    axip_arbiter_inst : entity work.axip_arbiter
      generic map (
        G_DATA_SIZE => G_DATA_SIZE
      )
      port map (
        clk_i      => clk_i,
        rst_i      => rst_i,
        s0_ready_o => s_ready_o(0),
        s0_valid_i => s_valid_i(0),
        s0_data_i  => s_data_i(G_DATA_SIZE - 1 downto 0),
        s0_last_i  => s_last_i(0),
        s1_ready_o => s_ready_o(1),
        s1_valid_i => s_valid_i(1),
        s1_data_i  => s_data_i(2 * G_DATA_SIZE - 1 downto G_DATA_SIZE),
        s1_last_i  => s_last_i(1),
        m_ready_i  => m_ready_i,
        m_valid_o  => m_valid_o,
        m_data_o   => m_data_o,
        m_last_o   => m_last_o
      ); -- axip_arbiter_inst : entity work.axip_arbiter

  else generate

    assert G_NUM_MASTERS > 2;

    axip_arbiter_general_left_inst : entity work.axip_arbiter_general
      generic map (
        G_NUM_MASTERS => C_NUM_LEFT,
        G_DATA_SIZE   => G_DATA_SIZE
      )
      port map (
        clk_i     => clk_i,
        rst_i     => rst_i,
        s_ready_o => s_ready_o(R_LEFT),
        s_valid_i => s_valid_i(R_LEFT),
        s_data_i  => s_data_i(R_LEFT_DATA),
        s_last_i  => s_last_i(R_LEFT),
        m_ready_i => left_ready,
        m_valid_o => left_valid,
        m_data_o  => left_data,
        m_last_o  => left_last
      ); -- axip_arbiter_general_left_inst : entity work.axip_arbiter_general

    axip_arbiter_general_right_inst : entity work.axip_arbiter_general
      generic map (
        G_NUM_MASTERS => C_NUM_RIGHT,
        G_DATA_SIZE   => G_DATA_SIZE
      )
      port map (
        clk_i     => clk_i,
        rst_i     => rst_i,
        s_ready_o => s_ready_o(R_RIGHT),
        s_valid_i => s_valid_i(R_RIGHT),
        s_data_i  => s_data_i(R_RIGHT_DATA),
        s_last_i  => s_last_i(R_RIGHT),
        m_ready_i => right_ready,
        m_valid_o => right_valid,
        m_data_o  => right_data,
        m_last_o  => right_last
      ); -- axip_arbiter_general_right_inst : entity work.axip_arbiter_general

    axip_arbiter_inst : entity work.axip_arbiter
      generic map (
        G_DATA_SIZE => G_DATA_SIZE
      )
      port map (
        clk_i      => clk_i,
        rst_i      => rst_i,
        s0_ready_o => left_ready,
        s0_valid_i => left_valid,
        s0_data_i  => left_data,
        s0_last_i  => left_last,
        s1_ready_o => right_ready,
        s1_valid_i => right_valid,
        s1_data_i  => right_data,
        s1_last_i  => right_last,
        m_ready_i  => m_ready_i,
        m_valid_o  => m_valid_o,
        m_data_o   => m_data_o,
        m_last_o   => m_last_o
      ); -- axip_arbiter_inst : entity work.axip_arbiter

  end generate iterate_gen;

end architecture synthesis;

