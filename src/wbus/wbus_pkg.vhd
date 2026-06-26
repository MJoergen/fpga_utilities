-- ---------------------------------------------------------------------------------------
-- Description: Shared types for the wbus_* family.
--
--   slv_array_type   : canonical, fully generic. Unconstrained on both the array range
--                      and the element width. Constrain at the use site, e.g.:
--                        signal x : slv_array_type(0 to N - 1)(W - 1 downto 0);
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

end package wbus_pkg;

