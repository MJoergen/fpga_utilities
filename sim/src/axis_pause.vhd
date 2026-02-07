-- ---------------------------------------------------------------------------------------
-- Description: This module generates empty cycles in an AXI stream by deasserting
-- s_ready_o and m_valid_o at random intervals. The period between the empty cycles can be
-- controlled by the generic G_PAUSE_SIZE:
-- * Setting it to 0 disables the empty cycles.
-- * Setting it to 10 inserts empty cycles approximately every tenth cycle, i.e. 90 % throughput.
-- * Setting it to -10 inserts empty cycles except approximately every tenth cycle, i.e. 10 % throughput.
-- * Etc.
-- ---------------------------------------------------------------------------------------

library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std_unsigned.all;

library work;
  use work.axis_pkg.all;

entity axis_pause is
  generic (
    G_SEED       : std_logic_vector(63 downto 0);
    G_PAUSE_SIZE : integer
  );
  port (
    clk_i  : in    std_logic;
    rst_i  : in    std_logic;
    s_axis : view  axis_slave_view;
    m_axis : view  axis_master_view
  );
end entity axis_pause;

architecture simulation of axis_pause is

  signal random_val : std_logic_vector(63 downto 0);
  signal cnt        : natural range 0 to abs(G_PAUSE_SIZE) := 0;
  signal forward    : std_logic;
  signal update     : std_logic;

begin

  random_inst : entity work.random
    generic map (
      G_SEED => G_SEED
    )
    port map (
      clk_i    => clk_i,
      rst_i    => rst_i,
      update_i => update,
      output_o => random_val
    ); -- random_inst : entity work.random

  cnt    <= 0 when G_PAUSE_SIZE = 0 else
            to_integer(random_val(27 downto 0)) mod abs(G_PAUSE_SIZE);
  update <= '0' when forward = '1' and m_axis.valid = '1' and m_axis.ready = '0' else
            '1';

  no_pause_gen : if G_PAUSE_SIZE = 0 generate
    forward <= '1';
  end generate no_pause_gen;

  pause_positive_gen : if G_PAUSE_SIZE > 0 generate
    -- Insert empty cycle when cnt reaches zero.
    forward <= '0' when cnt = 0 else
               '1';
  end generate pause_positive_gen;

  pause_negative_gen : if G_PAUSE_SIZE < 0 generate
    -- Insert empty cycle except when cnt reaches zero.
    forward <= '1' when cnt = 0 else
               '0';
  end generate pause_negative_gen;

  s_axis.ready <= m_axis.ready and forward;
  m_axis.valid <= s_axis.valid and forward;
  m_axis.data  <= s_axis.data;

end architecture simulation;

