-- ---------------------------------------------------------------------------------------
-- Description: Distribute AXI stream to two different AXI masters
-- ---------------------------------------------------------------------------------------

library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std.all;

library work;
  use work.axis_pkg.all;

entity axis_distributor is
  port (
    clk_i   : in    std_logic;
    rst_i   : in    std_logic;
    s_dst_i : in    std_logic;
    s_axis  : view  axis_slave_view;
    m0_axis : view  axis_master_view;
    m1_axis : view  axis_master_view
  );
end entity axis_distributor;

architecture synthesis of axis_distributor is

begin

  m0_axis.valid <= s_axis.valid when s_dst_i = '0' else
                   '0';
  m1_axis.valid <= s_axis.valid when s_dst_i = '1' else
                   '0';
  s_axis.ready  <= m0_axis.ready when s_dst_i = '0' else
                   m1_axis.ready;

  m0_axis.data  <= s_axis.data;
  m1_axis.data  <= s_axis.data;

end architecture synthesis;

