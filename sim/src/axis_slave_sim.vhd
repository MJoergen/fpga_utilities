-- ---------------------------------------------------------------------------------------
-- Description: This provides stimulus to and verifies response from an AXI streaming interface.
-- ---------------------------------------------------------------------------------------

library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std_unsigned.all;

library std;
  use std.env.stop;

library work;
  use work.axis_pkg.all;

entity axis_slave_sim is
  generic (
    G_SEED     : std_logic_vector(63 downto 0) := X"DEADBEAFC007BABE";
    G_RANDOM   : boolean;
    G_FIRST    : std_logic := 'U';
    G_CNT_SIZE : natural
  );
  port (
    clk_i     : in    std_logic;
    rst_i     : in    std_logic;

    -- Response
    s_axis : view  axis_slave_view
  );
end entity axis_slave_sim;

architecture simulation of axis_slave_sim is

  constant C_DATA_BYTES : positive := s_axis.data'length/8;

  -- State machine for controlling reception and verification of packets.
  signal  verf_cnt : std_logic_vector(G_CNT_SIZE - 1 downto 0);

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

  s_axis.ready <= or(rand(R_RAND_DO_READY)) when G_RANDOM else
               '1';

  verify_proc : process (clk_i)
    variable cmp_v : std_logic_vector(7 downto 0);
  begin
    if rising_edge(clk_i) then
      if s_axis.valid = '1' and s_axis.ready = '1' then

        for i in 0 to C_DATA_BYTES - 1 loop

          cmp_v := verf_cnt(7 downto 0);
          if i = 0 and G_FIRST /= 'U' then
            cmp_v(cmp_v'left) := G_FIRST;
          end if;

          assert s_axis.data((C_DATA_BYTES - 1 - i) * 8 + 7 downto (C_DATA_BYTES - 1 - i) * 8) = cmp_v + i
            report "Verify byte " & to_string(i) &
                   ". Received " & to_hstring(s_axis.data(i * 8 + 7 downto i * 8)) &
                   ", expected " & to_hstring(verf_cnt(7 downto 0) + i);
        end loop;

        verf_cnt <= verf_cnt + C_DATA_BYTES;

        -- Check for wrap-around
        if verf_cnt > verf_cnt + C_DATA_BYTES then
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

