-- ---------------------------------------------------------------------------------------
-- Description: Shared types and helpers for the axip_* family.
--   bytes_type       — natural-range encoding of an AXIP BYTES port.
--   bytes_array_type — unconstrained array of bytes_type, used by axip_arbiter_general.
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

