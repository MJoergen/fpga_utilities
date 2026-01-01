library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std_unsigned.all;

library std;
  use std.env.stop;

entity tb_axis_fifo_sync is
  generic (
    G_RAM_DEPTH  : natural;
    G_RANDOM     : boolean;
    G_FAST       : boolean;
    G_CNT_SIZE   : natural;
    G_DATA_BYTES : natural
  );
end entity tb_axis_fifo_sync;

architecture simulation of tb_axis_fifo_sync is

  signal  clk : std_logic := '1';
  signal  rst : std_logic := '1';

  signal  s_ready : std_logic;
  signal  s_valid : std_logic;
  signal  s_data  : std_logic_vector(G_DATA_BYTES * 8 - 1 downto 0);

  signal  m_ready : std_logic;
  signal  m_valid : std_logic;
  signal  m_data  : std_logic_vector(G_DATA_BYTES * 8 - 1 downto 0);

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

  --------------------------------
  -- Clock and Reset
  --------------------------------

  clk <= not clk after 5 ns;
  rst <= '1', '0' after 100 ns;


  --------------------------------
  -- Instantiate DUT
  --------------------------------

  axis_fifo_sync_inst : entity work.axis_fifo_sync
    generic map (
      G_RAM_STYLE => "auto",
      G_RAM_DEPTH => G_RAM_DEPTH,
      G_DATA_SIZE => G_DATA_BYTES * 8
    )
    port map (
      clk_i     => clk,
      rst_i     => rst,
      s_ready_o => s_ready,
      s_valid_i => s_valid,
      s_data_i  => s_data,
      m_ready_i => m_ready,
      m_valid_o => m_valid,
      m_data_o  => m_data
    ); -- axis_fifo_sync_inst : entity work.axis_fifo_sync


  ----------------------------------------------------------
  -- Generate randomness
  ----------------------------------------------------------

  random_inst : entity work.random
    generic map (
      G_SEED => X"DEADBEAFC007BABE"
    )
    port map (
      clk_i    => clk,
      rst_i    => rst,
      update_i => '1',
      output_o => rand
    ); -- random_inst : entity work.random


  --------------------------------
  -- Instantiate stimulation and verification
  --------------------------------

  stim_do_valid <= or(rand(R_RAND_DO_VALID)) when G_RANDOM else
                   '1';

  stimuli_proc : process (clk)
    variable first_v : boolean := true;
  begin
    if rising_edge(clk) then
      if rst = '0' and first_v then
        report "Test started";
        first_v := false;
      end if;

      if s_ready = '1' then
        s_valid <= '0';
        s_data  <= (others => '0');
      end if;

      if s_valid = '0' or (G_FAST and s_ready = '1') then
        if stim_do_valid = '1' then
          stim_cnt <= stim_cnt + G_DATA_BYTES;

          for i in 0 to G_DATA_BYTES - 1 loop
            s_data((G_DATA_BYTES - 1 - i) * 8 + 7 downto (G_DATA_BYTES - 1 - i) * 8) <= stim_cnt(7 downto 0) + i;
          end loop;

          s_valid <= '1';
        end if;
      end if;

      if rst = '1' then
        stim_cnt <= (others => '0');
        s_valid  <= '0';
        s_data   <= (others => '0');
      end if;
    end if;
  end process stimuli_proc;


  ----------------------------------------------------------
  -- Verify output
  ----------------------------------------------------------

  m_ready       <= or(rand(R_RAND_DO_READY)) when G_RANDOM else
                   '1';

  verify_proc : process (clk)
  begin
    if rising_edge(clk) then
      if m_valid = '1' and m_ready = '1' then

        for i in 0 to G_DATA_BYTES - 1 loop
          assert m_data((G_DATA_BYTES - 1 - i) * 8 + 7 downto (G_DATA_BYTES - 1 - i) * 8) = verf_cnt(7 downto 0) + i
            report "Verify byte " & to_string(i) &
                   ". Received " & to_hstring(m_data(i * 8 + 7 downto i * 8)) &
                   ", expected " & to_hstring(verf_cnt(7 downto 0) + i);
        end loop;

        verf_cnt <= verf_cnt + G_DATA_BYTES;

        -- Check for wrap-around
        if verf_cnt > verf_cnt + G_DATA_BYTES then
          report "Test finished";
          stop;
        end if;
      end if;

      if rst = '1' then
        verf_cnt <= (others => '0');
      end if;
    end if;
  end process verify_proc;

end architecture simulation;

