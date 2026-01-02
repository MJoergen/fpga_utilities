-- ----------------------------------------------------------------------------
-- Author     : Michael Jørgensen
-- Platform   : simulation
-------------------------------------------------------------------------------
-- Description:
-- This module generates empty cycles in an AXI packet interface by deasserting
-- m_ready_o and s_valid_o at random intervals. The period between the empty
-- cycles can be controlled by the generic G_PAUSE_SIZE:
-- * Setting it to 0 disables the empty cycles.
-- * Setting it to 10 inserts empty cycles approximately every tenth cycle, i.e. 90 % throughput.
-- * Setting it to -10 inserts empty cycles except approximately every tenth cycle, i.e. 10 % throughput.
-- * Etc.
-------------------------------------------------------------------------------

library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std_unsigned.all;

entity axip_pause is
  generic (
    G_SEED       : std_logic_vector(63 downto 0) := x"01234567FEDCBA98";
    G_DATA_BYTES : integer;
    G_PAUSE_SIZE : integer
  );
  port (
    clk_i     : in    std_logic;
    rst_i     : in    std_logic;

    -- AXI packet Input
    s_valid_i : in    std_logic;
    s_ready_o : out   std_logic;
    s_data_i  : in    std_logic_vector(G_DATA_BYTES * 8 - 1 downto 0);
    s_last_i  : in    std_logic;
    s_bytes_i : in    natural range 0 to G_DATA_BYTES;

    -- AXI packet Output
    m_valid_o : out   std_logic;
    m_ready_i : in    std_logic;
    m_data_o  : out   std_logic_vector(G_DATA_BYTES * 8 - 1 downto 0);
    m_last_o  : out   std_logic;
    m_bytes_o : out   natural range 0 to G_DATA_BYTES
  );
end entity axip_pause;

architecture simulation of axip_pause is

  signal   s_data_in  : std_logic_vector(G_DATA_BYTES * 8 + 15 downto 0);
  signal   m_data_out : std_logic_vector(G_DATA_BYTES * 8 + 15 downto 0);

  subtype  R_DATA is natural range G_DATA_BYTES * 8 - 1 downto 0;

  subtype  R_BYTES is natural range G_DATA_BYTES * 8 + 14 downto G_DATA_BYTES * 8;

  constant C_LAST : natural := G_DATA_BYTES * 8 + 15;

begin

  s_data_in(R_DATA)  <= s_data_i;
  s_data_in(R_BYTES) <= to_stdlogicvector(s_bytes_i, 15);
  s_data_in(C_LAST)  <= s_last_i;

  m_data_o           <= m_data_out(R_DATA);
  m_bytes_o          <= to_integer(m_data_out(R_BYTES));
  m_last_o           <= m_data_out(C_LAST);

  axis_pause_inst : entity work.axis_pause
    generic map (
      G_SEED       => G_SEED,
      G_DATA_SIZE  => G_DATA_BYTES * 8 + 16,
      G_PAUSE_SIZE => G_PAUSE_SIZE
    )
    port map (
      clk_i     => clk_i,
      rst_i     => rst_i,
      s_ready_o => s_ready_o,
      s_valid_i => s_valid_i,
      s_data_i  => s_data_in,
      m_ready_i => m_ready_i,
      m_valid_o => m_valid_o,
      m_data_o  => m_data_out
    ); -- axis_pause_inst : entity work.axis_pause

end architecture simulation;

