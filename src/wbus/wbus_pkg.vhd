-- ---------------------------------------------------------------------------------------
-- Description:
--
-- SPDX-License-Identifier: MIT
-- ---------------------------------------------------------------------------------------

library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std.all;

package wbus_pkg is

  type slv32_array_type is array (natural range <>) of std_logic_vector(31 downto 0);
  type slv4_array_type  is array (natural range <>) of std_logic_vector(3 downto 0);

end package wbus_pkg;

