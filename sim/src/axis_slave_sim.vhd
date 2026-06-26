-- ---------------------------------------------------------------------------------------
-- Description: This provides stimulus to and verifies response from an AXI streaming interface.
--
-- SPDX-License-Identifier: MIT
-- ---------------------------------------------------------------------------------------

library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std_unsigned.all;

library std;
  use std.env.stop;

entity axis_slave_sim is
  generic (
    G_SEED       : std_logic_vector(63 downto 0) := X"DEADBEAFC007BABE";
    G_RANDOM     : boolean;
    G_DATA_BITS  : natural
  );
  port (
    clk_i     : in    std_logic;
    rst_i     : in    std_logic;

    -- Response
    s_ready_o : out   std_logic;
    s_valid_i : in    std_logic;
    s_data_i  : in    std_logic_vector(G_DATA_BITS - 1 downto 0)
  );
end entity axis_slave_sim;

architecture simulation of axis_slave_sim is

  -- State machine for controlling reception and verification of packets.
  signal  verf_cnt : std_logic_vector(G_DATA_BITS - 1 downto 0);

  -- Randomness
  signal  rand : std_logic_vector(63 downto 0);

  -- This controls how often data is received.

  subtype R_RAND_DO_READY is natural range 32 downto 30;

begin

  ----------------------------------------------------------
  -- Generate randomness
  ----------------------------------------------------------

  random_inst : entity work.random
    generic map (
      G_SEED => G_SEED
    )
    port map (
      clk_i    => clk_i,
      rst_i    => rst_i,
      update_i => '1',
      output_o => rand
    ); -- random_inst : entity work.random


  ----------------------------------------------------------
  -- Verify output
  ----------------------------------------------------------

  s_ready_o <= or(rand(R_RAND_DO_READY)) when G_RANDOM else
               '1';

  verify_proc : process (clk_i)
  begin
    if rising_edge(clk_i) then
      if s_valid_i = '1' and s_ready_o = '1' then

          assert s_data_i = verf_cnt
            report "axis_slave_sim ERROR: " &
                   "Received " & to_hstring(s_data_i) &
                   ", expected " & to_hstring(verf_cnt);

        verf_cnt <= verf_cnt + 1;

        -- Check for wrap-around
        if verf_cnt > verf_cnt + 1 then
          report "Test finished";
          stop;
        end if;
      end if;

      if rst_i = '1' then
        verf_cnt <= (others => '0');
      end if;
    end if;
  end process verify_proc;

end architecture simulation;

