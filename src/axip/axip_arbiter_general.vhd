-- ---------------------------------------------------------------------------------------
-- Description: Arbitrate between several different AXI packet masters
-- ---------------------------------------------------------------------------------------

library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std.all;

library work;
  use work.axip_pkg.nat16_type;
  use work.axip_pkg.nat16_array_type;

entity axip_arbiter_general is
  generic (
    G_NUM_MASTERS : natural;
    G_DATA_BYTES  : natural
  );
  port (
    clk_i     : in    std_logic;
    rst_i     : in    std_logic;

    s_ready_o : out   std_logic_vector(G_NUM_MASTERS - 1 downto 0);
    s_valid_i : in    std_logic_vector(G_NUM_MASTERS - 1 downto 0);
    s_data_i  : in    std_logic_vector(G_NUM_MASTERS * G_DATA_BYTES * 8 - 1 downto 0);
    s_last_i  : in    std_logic_vector(G_NUM_MASTERS - 1 downto 0);
    s_bytes_i : in    nat16_array_type(G_NUM_MASTERS - 1 downto 0);

    m_ready_i : in    std_logic;
    m_valid_o : out   std_logic;
    m_data_o  : out   std_logic_vector(G_DATA_BYTES * 8 - 1 downto 0);
    m_last_o  : out   std_logic;
    m_bytes_o : out   nat16_type
  );
end entity axip_arbiter_general;

architecture synthesis of axip_arbiter_general is

  constant C_NUM_RIGHT : natural := G_NUM_MASTERS / 2;
  constant C_NUM_LEFT  : natural := G_NUM_MASTERS - C_NUM_RIGHT;

  subtype  R_RIGHT is natural range C_NUM_RIGHT - 1 downto 0;
  subtype  R_LEFT is natural range G_NUM_MASTERS - 1 downto C_NUM_RIGHT;

  subtype  R_RIGHT_DATA is natural range C_NUM_RIGHT * G_DATA_BYTES * 8 - 1 downto 0;
  subtype  R_LEFT_DATA is natural range G_NUM_MASTERS * G_DATA_BYTES * 8 - 1 downto C_NUM_RIGHT * G_DATA_BYTES * 8;

  signal   left_ready : std_logic;
  signal   left_valid : std_logic;
  signal   left_data  : std_logic_vector(G_DATA_BYTES * 8 - 1 downto 0);
  signal   left_last  : std_logic;
  signal   left_bytes : nat16_type;

  signal   right_ready : std_logic;
  signal   right_valid : std_logic;
  signal   right_data  : std_logic_vector(G_DATA_BYTES * 8 - 1 downto 0);
  signal   right_last  : std_logic;
  signal   right_bytes : nat16_type;

  subtype  BYTES_TYPE is natural range 0 to G_DATA_BYTES;

begin

  iterate_gen : if G_NUM_MASTERS = 1 generate

    -- Only one master
    m_valid_o    <= s_valid_i(0);
    m_data_o     <= s_data_i;
    m_last_o     <= s_last_i(0);
    m_bytes_o    <= s_bytes_i(0);
    s_ready_o(0) <= m_ready_i;

  elsif G_NUM_MASTERS = 2 generate

    -- Just two masters
    axip_arbiter_inst : entity work.axip_arbiter
      generic map (
        G_DATA_BYTES => G_DATA_BYTES
      )
      port map (
        clk_i                 => clk_i,
        rst_i                 => rst_i,
        s0_ready_o            => s_ready_o(0),
        s0_valid_i            => s_valid_i(0),
        s0_data_i             => s_data_i(R_RIGHT_DATA),
        s0_last_i             => s_last_i(0),
        s0_bytes_i            => nat16_type(s_bytes_i(0)),
        s1_ready_o            => s_ready_o(1),
        s1_valid_i            => s_valid_i(1),
        s1_data_i             => s_data_i(R_LEFT_DATA),
        s1_last_i             => s_last_i(1),
        s1_bytes_i            => nat16_type(s_bytes_i(1)),
        m_ready_i             => m_ready_i,
        m_valid_o             => m_valid_o,
        m_data_o              => m_data_o,
        m_last_o              => m_last_o,
        nat16_type(m_bytes_o) => m_bytes_o
      ); -- axip_arbiter_inst : entity work.axip_arbiter

  else generate

    assert G_NUM_MASTERS > 2;

    axip_arbiter_general_left_inst : entity work.axip_arbiter_general
      generic map (
        G_NUM_MASTERS => C_NUM_LEFT,
        G_DATA_BYTES  => G_DATA_BYTES
      )
      port map (
        clk_i     => clk_i,
        rst_i     => rst_i,
        s_ready_o => s_ready_o(R_LEFT),
        s_valid_i => s_valid_i(R_LEFT),
        s_data_i  => s_data_i(R_LEFT_DATA),
        s_last_i  => s_last_i(R_LEFT),
        s_bytes_i => s_bytes_i(R_LEFT),
        m_ready_i => left_ready,
        m_valid_o => left_valid,
        m_data_o  => left_data,
        m_last_o  => left_last,
        m_bytes_o => left_bytes
      ); -- axip_arbiter_general_left_inst : entity work.axip_arbiter_general

    axip_arbiter_general_right_inst : entity work.axip_arbiter_general
      generic map (
        G_NUM_MASTERS => C_NUM_RIGHT,
        G_DATA_BYTES  => G_DATA_BYTES
      )
      port map (
        clk_i     => clk_i,
        rst_i     => rst_i,
        s_ready_o => s_ready_o(R_RIGHT),
        s_valid_i => s_valid_i(R_RIGHT),
        s_data_i  => s_data_i(R_RIGHT_DATA),
        s_last_i  => s_last_i(R_RIGHT),
        s_bytes_i => s_bytes_i(R_RIGHT),
        m_ready_i => right_ready,
        m_valid_o => right_valid,
        m_data_o  => right_data,
        m_last_o  => right_last,
        m_bytes_o => right_bytes
      ); -- axip_arbiter_general_right_inst : entity work.axip_arbiter_general

    axip_arbiter_inst : entity work.axip_arbiter
      generic map (
        G_DATA_BYTES => G_DATA_BYTES
      )
      port map (
        clk_i                 => clk_i,
        rst_i                 => rst_i,
        s0_ready_o            => left_ready,
        s0_valid_i            => left_valid,
        s0_data_i             => left_data,
        s0_last_i             => left_last,
        s0_bytes_i            => bytes_type(left_bytes),
        s1_ready_o            => right_ready,
        s1_valid_i            => right_valid,
        s1_data_i             => right_data,
        s1_last_i             => right_last,
        s1_bytes_i            => bytes_type(right_bytes),
        m_ready_i             => m_ready_i,
        m_valid_o             => m_valid_o,
        m_data_o              => m_data_o,
        m_last_o              => m_last_o,
        nat16_type(m_bytes_o) => m_bytes_o
      ); -- axip_arbiter_inst : entity work.axip_arbiter

  end generate iterate_gen;

end architecture synthesis;

