-- ---------------------------------------------------------------------------------------
-- Description:
-- ---------------------------------------------------------------------------------------

library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std.all;

package avm_pkg is

  type avm_rec_type is record
    waitrequest   : std_logic;
    write         : std_logic;
    read          : std_logic;
    address       : std_logic_vector;
    writedata     : std_logic_vector;
    byteenable    : std_logic_vector;
    burstcount    : std_logic_vector(7 downto 0);
    readdata      : std_logic_vector;
    readdatavalid : std_logic;
  end record avm_rec_type;

  view avm_master_view of avm_rec_type is
    waitrequest   : in;
    write         : out;
    read          : out;
    address       : out;
    writedata     : out;
    byteenable    : out;
    burstcount    : out;
    readdata      : in;
    readdatavalid : in;
  end view avm_master_view;

  alias avm_slave_view is avm_master_view'converse;

end package avm_pkg;

package body avm_pkg is

end package body;

