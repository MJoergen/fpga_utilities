-- ---------------------------------------------------------------------------------------
-- Description:
--
-- SPDX-License-Identifier: MIT
-- ---------------------------------------------------------------------------------------

library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std.all;

package axip_pkg is

  subtype bytes_type is natural range 0 to 65535;

  type bytes_array_type is array (natural range <>) of bytes_type;

end package axip_pkg;

