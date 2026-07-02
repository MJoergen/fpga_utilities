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

  constant C_BYTES_FIELD_BITS : natural := 16;

  subtype bytes_type is natural range 0 to 2**C_BYTES_FIELD_BITS - 1;

  type bytes_array_type is array (natural range <>) of bytes_type;

  pure function bytes_to_slv(bytes : bytes_type) return std_logic_vector;
  pure function slv_to_bytes(slv : std_logic_vector) return bytes_type;

end package axip_pkg;

package body axip_pkg is

  pure function bytes_to_slv(bytes : bytes_type) return std_logic_vector is
  begin
    return std_logic_vector(to_unsigned(bytes, C_BYTES_FIELD_BITS));
  end function bytes_to_slv;

  pure function slv_to_bytes(slv : std_logic_vector) return bytes_type is
  begin
    return to_integer(unsigned(slv));
  end function slv_to_bytes;

end package body axip_pkg;

