-- ---------------------------------------------------------------------------------------
-- Description:
-- ---------------------------------------------------------------------------------------

library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std.all;

package wbus_pkg is

  type wbus_data_array_type is array (natural range <>) of std_logic_vector;

  type wbus_rec_type is record
    cyc   : std_logic;
    stall : std_logic;
    stb   : std_logic;
    addr  : std_logic_vector;
    we    : std_logic;
    wrdat : std_logic_vector;
    ack   : std_logic;
    rddat : std_logic_vector;
  end record wbus_rec_type;

  type wbus_map_rec_type is record
    rst   : std_logic_vector;
    cyc   : std_logic;
    stall : std_logic_vector;
    stb   : std_logic_vector;
    addr  : std_logic_vector;
    we    : std_logic;
    wrdat : std_logic_vector;
    ack   : std_logic_vector;
    rddat : wbus_data_array_type;
  end record wbus_map_rec_type;

  view wbus_master_view of wbus_rec_type is
    cyc   : out;
    stall : in;
    stb   : out;
    addr  : out;
    we    : out;
    wrdat : out;
    ack   : in;
    rddat : in;
  end view wbus_master_view;

  view wbus_map_master_view of wbus_map_rec_type is
    rst   : out;
    cyc   : out;
    stall : in;
    stb   : out;
    addr  : out;
    we    : out;
    wrdat : out;
    ack   : in;
    rddat : in;
  end view wbus_map_master_view;

  alias wbus_slave_view is wbus_master_view'converse;

  alias wbus_map_slave_view is wbus_map_master_view'converse;

end package wbus_pkg;


package body wbus_pkg is

end package body wbus_pkg;

