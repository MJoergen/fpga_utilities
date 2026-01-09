-- ---------------------------------------------------------------------------------------
-- Description: This provides stimulus to and verifies response from an AXI streaming interface.
-- ---------------------------------------------------------------------------------------

library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std_unsigned.all;

library std;
  use std.env.stop;

entity axis_sim is
  generic (
    G_SEED       : std_logic_vector(63 downto 0) := X"DEADBEAFC007BABE";
    G_RANDOM     : boolean;
    G_FAST       : boolean;
    G_CNT_SIZE   : natural;
    G_DATA_BYTES : natural
  );
  port (
    clk_i     : in    std_logic;
    rst_i     : in    std_logic;

    -- Stimulus
    m_ready_i : in    std_logic;
    m_valid_o : out   std_logic;
    m_data_o  : out   std_logic_vector(G_DATA_BYTES * 8 - 1 downto 0);

    -- Response
    s_ready_o : out   std_logic;
    s_valid_i : in    std_logic;
    s_data_i  : in    std_logic_vector(G_DATA_BYTES * 8 - 1 downto 0)
  );
end entity axis_sim;

architecture simulation of axis_sim is

  -- State machine for controlling generation and transmission of packets.
  signal  stim_cnt      : std_logic_vector(G_CNT_SIZE - 1 downto 0);
  signal  stim_do_valid : std_logic;

  -- State machine for controlling reception and verification of packets.
  signal  verf_cnt : std_logic_vector(G_CNT_SIZE - 1 downto 0);

  -- Randomness
  signal  rand : std_logic_vector(63 downto 0);

  -- This controls how often data is transmitted.

  subtype R_RAND_DO_VALID is natural range 42 downto 40;

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

      if m_ready_i = '1' then
        m_valid_o <= '0';
        m_data_o  <= (others => '0');
      end if;

      if m_valid_o = '0' or (G_FAST and m_ready_i = '1') then
        if stim_do_valid = '1' then
          stim_cnt <= stim_cnt + G_DATA_BYTES;

          for i in 0 to G_DATA_BYTES - 1 loop
            m_data_o((G_DATA_BYTES - 1 - i) * 8 + 7 downto (G_DATA_BYTES - 1 - i) * 8) <= stim_cnt(7 downto 0) + i;
          end loop;

          m_valid_o <= '1';
        end if;
      end if;

      if rst_i = '1' then
        stim_cnt  <= (others => '0');
        m_valid_o <= '0';
        m_data_o  <= (others => '0');
      end if;
    end if;
  end process stimuli_proc;


  ----------------------------------------------------------
  -- Verify output
  ----------------------------------------------------------

  s_ready_o     <= or(rand(R_RAND_DO_READY)) when G_RANDOM else
                   '1';

  verify_proc : process (clk_i)
  begin
    if rising_edge(clk_i) then
      if s_valid_i = '1' and s_ready_o = '1' then

        for i in 0 to G_DATA_BYTES - 1 loop
          assert s_data_i((G_DATA_BYTES - 1 - i) * 8 + 7 downto (G_DATA_BYTES - 1 - i) * 8) = verf_cnt(7 downto 0) + i
            report "Verify byte " & to_string(i) &
                   ". Received " & to_hstring(s_data_i(i * 8 + 7 downto i * 8)) &
                   ", expected " & to_hstring(verf_cnt(7 downto 0) + i);
        end loop;

        verf_cnt <= verf_cnt + G_DATA_BYTES;

        -- Check for wrap-around
        if verf_cnt > verf_cnt + G_DATA_BYTES then
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

