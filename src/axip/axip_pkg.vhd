-- ---------------------------------------------------------------------------------------
-- Description:
-- ---------------------------------------------------------------------------------------

library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std.all;

package axip_pkg is

  subtype nat16_type is natural range 0 to 65535;

  type nat16_array_type is array (natural range <>) of nat16_type;

  type axip_rec_type is record
    ready : std_logic;
    valid : std_logic;
    data  : std_logic_vector;
    last  : std_logic;
    bytes : natural;
  end record axip_rec_type;

  view axip_master_view of axip_rec_type is
    ready : in;
    valid : out;
    data  : out;
    last  : out;
    bytes : out;
  end view axip_master_view;

  alias axip_slave_view is axip_master_view'converse;

end package axip_pkg;


package body axip_pkg is

end package body axip_pkg;

