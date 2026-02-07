-- ---------------------------------------------------------------------------------------
-- Description: This module generates empty cycles in an AXI packet interface by
-- deasserting m_ready_o and s_valid_o at random intervals. The period between the empty
-- cycles can be controlled by the generic G_PAUSE_SIZE:
-- * Setting it to 0 disables the empty cycles.
-- * Setting it to 10 inserts empty cycles approximately every tenth cycle, i.e. 90 % throughput.
-- * Setting it to -10 inserts empty cycles except approximately every tenth cycle, i.e. 10 % throughput.
-- * Etc.
-- ---------------------------------------------------------------------------------------

library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std.all;

library work;
  use work.axis_pkg.all;
  use work.axip_pkg.all;

entity axip_pause is
  generic (
    G_SEED       : std_logic_vector(63 downto 0) := x"01234567FEDCBA98";
    G_PAUSE_SIZE : integer
  );
  port (
    clk_i  : in    std_logic;
    rst_i  : in    std_logic;
    s_axip : view axip_slave_view;
    m_axip : view axip_master_view
  );
end entity axip_pause;

architecture simulation of axip_pause is

  constant C_DATA_BYTES : positive := s_axip.data'length / 8;

  signal   s_data_in  : std_logic_vector(C_DATA_BYTES * 8 + 15 downto 0);
  signal   m_data_out : std_logic_vector(C_DATA_BYTES * 8 + 15 downto 0);

  subtype  R_DATA is natural range C_DATA_BYTES * 8 - 1 downto 0;

  subtype  R_BYTES is natural range C_DATA_BYTES * 8 + 14 downto C_DATA_BYTES * 8;

  constant C_LAST : natural := C_DATA_BYTES * 8 + 15;

  signal s_axis : axis_rec_type (
    data(C_DATA_BYTES * 8 + 15 downto 0)
  );

  signal m_axis : axis_rec_type (
    data(C_DATA_BYTES * 8 + 15 downto 0)
  );

begin

  s_axis.valid         <= s_axip.valid;
  s_axis.data(R_DATA)  <= s_axip.data;
  s_axis.data(R_BYTES) <= std_logic_vector(to_unsigned(s_axip.bytes, 15));
  s_axis.data(C_LAST)  <= s_axip.last;
  s_axip.ready         <= s_axis.ready;

  m_axip.valid         <= m_axis.valid;
  m_axip.data          <= m_axis.data(R_DATA);
  m_axip.bytes         <= to_integer(unsigned(m_axis.data(R_BYTES)));
  m_axip.last          <= m_axis.data(C_LAST);
  m_axis.ready         <= m_axip.ready;

  axis_pause_inst : entity work.axis_pause
    generic map (
      G_SEED       => G_SEED,
      G_PAUSE_SIZE => G_PAUSE_SIZE
    )
    port map (
      clk_i  => clk_i,
      rst_i  => rst_i,
      s_axis => s_axis,
      m_axis => m_axis
    ); -- axis_pause_inst : entity work.axis_pause

end architecture simulation;

