-- ---------------------------------------------------------------------------------------
-- Description: This provides stimulus to and verifies response from an AXI streaming interface.
-- ---------------------------------------------------------------------------------------

library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std_unsigned.all;

library work;
  use work.axis_pkg.all;

entity axis_master_sim is
  generic (
    G_SEED     : std_logic_vector(63 downto 0) := x"DEADBEAFC007BABE";
    G_RANDOM   : boolean;
    G_FAST     : boolean;
    G_FIRST    : std_logic := 'U';
    G_CNT_SIZE : natural
  );
  port (
    clk_i  : in    std_logic;
    rst_i  : in    std_logic;

    -- Stimulus
    m_axis : view  axis_master_view
  );
end entity axis_master_sim;

architecture simulation of axis_master_sim is

  constant C_DATA_BYTES : positive := m_axis.data'length / 8;

  -- Randomness
  signal   rand : std_logic_vector(63 downto 0);

  -- This controls how often data is transmitted.

  subtype  R_RAND_DO_VALID is natural range 42 downto 40;

  signal   stim_do_valid : std_logic;

  -- State machine for controlling generation and transmission of packets.
  signal   stim_cnt : std_logic_vector(G_CNT_SIZE - 1 downto 0);

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
  -- Instantiate stimulation and verification
  ----------------------------------------------------------

  stim_do_valid <= or(rand(R_RAND_DO_VALID)) when G_RANDOM else
                   '1';

  stimuli_proc : process (clk_i)
    variable first_v : boolean := true;
  begin
    if rising_edge(clk_i) then
      if rst_i = '0' and first_v then
        report "Test started";
        first_v := false;
      end if;

      if m_axis.ready = '1' then
        m_axis.valid <= '0';
        m_axis.data  <= (C_DATA_BYTES * 8 - 1 downto 0 => '0');
      end if;

      if m_axis.valid = '0' or (G_FAST and m_axis.ready = '1') then
        if stim_do_valid = '1' then
          stim_cnt <= stim_cnt + C_DATA_BYTES;

          for i in 0 to C_DATA_BYTES - 1 loop
            m_axis.data((C_DATA_BYTES - 1 - i) * 8 + 7 downto (C_DATA_BYTES - 1 - i) * 8) <= stim_cnt(7 downto 0) + i;
          end loop;

          if G_FIRST /= 'U' then
            m_axis.data(m_axis.data'left) <= G_FIRST;
          end if;

          m_axis.valid <= '1';
        end if;
      end if;

      if rst_i = '1' then
        stim_cnt     <= (others => '0');
        m_axis.valid <= '0';
        m_axis.data  <= (C_DATA_BYTES * 8 - 1 downto 0 => '0');
      end if;
    end if;
  end process stimuli_proc;

end architecture simulation;

