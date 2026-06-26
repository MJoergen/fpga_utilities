-- ---------------------------------------------------------------------------------------
-- Description: Shared types for the wbus_* family.
--
--   slv_array_type   : canonical, fully generic. Unconstrained on both the array range
--                      and the element width. Constrain at the use site, e.g.:
--                        signal x : slv_array_type(0 to N - 1)(W - 1 downto 0);
--
--   slv32_array_type : legacy, fixed-width (32-bit). Used by wbus_arbiter_general until
--                      it is migrated to slv_array_type.
--   slv4_array_type  : legacy, fixed-width (4-bit). Same.
--
-- SPDX-License-Identifier: MIT
-- ---------------------------------------------------------------------------------------

library ieee;
  use ieee.std_logic_1164.all;

package wbus_pkg is

  -- Canonical: array of unconstrained std_logic_vector. Both the array range and the
  -- element width must be constrained at the use site. Example:
  --   signal m_rddat : slv_array_type(0 to G_NUM_SLAVES - 1)(G_DATA_BITS - 1 downto 0);
  type slv_array_type is array (natural range <>) of std_logic_vector;

  -- Legacy fixed-width arrays. Retained for backward compatibility with
  -- wbus_arbiter_general; do not use in new modules. To be removed once
  -- wbus_arbiter_general is migrated to slv_array_type.
  type slv32_array_type is array (natural range <>) of std_logic_vector(31 downto 0);
  type slv4_array_type  is array (natural range <>) of std_logic_vector(3 downto 0);

end package wbus_pkg;

