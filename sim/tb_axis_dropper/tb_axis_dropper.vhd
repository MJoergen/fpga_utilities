-- ---------------------------------------------------------------------------------------
-- Description: Verify axis_dropper
--
-- Frames of random length are sent to the DUT with random gaps, and the output is
-- stalled at random. The output alternates between fast and slow phases, so that the
-- FIFO is also exercised when it is full. s_drop is asserted at random, also while a beat is stalled, and
-- while s_valid is low (where it must be ignored).
--
-- A reference model decides which frames must be forwarded: a frame is dropped if
-- s_drop is high in any cycle in which s_valid is high, from its first beat up to and
-- including the accepted LAST beat. The output is compared beat by beat with the
-- frames that were not dropped, and cnt_drop is compared with the number of dropped
-- frames in every cycle.
--
-- SPDX-License-Identifier: MIT
-- ---------------------------------------------------------------------------------------

library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std.all;

library std;
  use std.env.stop;

entity tb_axis_dropper is
  generic (
    G_NUM_FRAMES : positive;
    G_MAX_LENGTH : positive; -- Must be less than 2 ** G_ADDR_BITS
    G_ADDR_BITS  : positive;
    G_DATA_BITS  : positive;
    G_CNT_BITS   : positive
  );
end entity tb_axis_dropper;

architecture tb of tb_axis_dropper is

  signal   clk : std_logic := '1';
  signal   rst : std_logic := '1';

  signal   cnt_drop : std_logic_vector(G_CNT_BITS - 1 downto 0);
  signal   s_ready  : std_logic;
  signal   s_valid  : std_logic;
  signal   s_data   : std_logic_vector(G_DATA_BITS - 1 downto 0);
  signal   s_drop   : std_logic;
  signal   s_last   : std_logic;
  signal   m_ready  : std_logic;
  signal   m_valid  : std_logic;
  signal   m_data   : std_logic_vector(G_DATA_BITS - 1 downto 0);
  signal   m_last   : std_logic;

  signal   rand : std_logic_vector(63 downto 0);

  subtype  R_RAND_VALID is natural range 2 downto 0;   -- New beat with probability 7/8
  subtype  R_RAND_READY is natural range 5 downto 4;   -- m_ready with probability 3/4 or 1/4
  subtype  R_RAND_DROP is natural range 10 downto 6;   -- s_drop with probability 1/32
  subtype  R_RAND_LENGTH is natural range 23 downto 16;

  -- Expected output: beats of the frames that are not dropped, in order
  type     word_array_type is array (natural range <>) of std_logic_vector(G_DATA_BITS downto 0);
  constant C_QUEUE_SIZE : natural := 1024;

  -- Number of dropped frames, according to the reference model
  signal   exp_cnt_drop : std_logic_vector(G_CNT_BITS - 1 downto 0);

  -- Alternates between fast ('0') and slow ('1') output phases
  signal   cycle_cnt  : unsigned(15 downto 0) := (others => '0');
  constant C_PHASE_BIT : natural := 9;

begin

  assert G_MAX_LENGTH < 2 ** G_ADDR_BITS
    report "tb_axis_dropper: G_MAX_LENGTH must be less than 2 ** G_ADDR_BITS"
    severity failure;


  --------------------------------
  -- Clock and Reset
  --------------------------------

  clk <= not clk after 5 ns;
  rst <= '1', '0' after 100 ns;


  --------------------------------
  -- Instantiate DUT
  --------------------------------

  axis_dropper_inst : entity work.axis_dropper
    generic map (
      G_ADDR_BITS => G_ADDR_BITS,
      G_DATA_BITS => G_DATA_BITS,
      G_CNT_BITS  => G_CNT_BITS
    )
    port map (
      clk_i      => clk,
      rst_i      => rst,
      cnt_drop_o => cnt_drop,
      s_ready_o  => s_ready,
      s_valid_i  => s_valid,
      s_data_i   => s_data,
      s_drop_i   => s_drop,
      s_last_i   => s_last,
      m_ready_i  => m_ready,
      m_valid_o  => m_valid,
      m_data_o   => m_data,
      m_last_o   => m_last
    ); -- axis_dropper_inst : entity work.axis_dropper


  --------------------------------
  -- Random stimulus
  --------------------------------

  random_inst : entity work.random
    generic map (
      G_SEED => X"0123456789ABCDEF"
    )
    port map (
      clk_i    => clk,
      rst_i    => rst,
      update_i => '1',
      output_o => rand
    ); -- random_inst : entity work.random

  cycle_cnt <= cycle_cnt + 1 when rising_edge(clk);

  m_ready <= or(rand(R_RAND_READY)) when cycle_cnt(C_PHASE_BIT) = '0' else
             and(rand(R_RAND_READY));
  s_drop  <= and(rand(R_RAND_DROP));


  --------------------------------
  -- Generate frames, model the DUT, and verify the output
  --------------------------------

  main_proc : process (clk)
    -- Generator
    variable frames_v  : natural := 0;                  -- Frames started
    variable length_v  : natural range 0 to G_MAX_LENGTH;
    variable beat_v    : natural range 0 to G_MAX_LENGTH;
    variable data_v    : unsigned(G_DATA_BITS - 1 downto 0);
    -- Reference model
    variable dropped_v : boolean;                       -- Current frame is dropped
    variable frame_v   : word_array_type(0 to G_MAX_LENGTH - 1);
    variable frame_len : natural range 0 to G_MAX_LENGTH;
    variable queue_v   : word_array_type(0 to C_QUEUE_SIZE - 1);
    variable q_wr_v    : natural range 0 to C_QUEUE_SIZE - 1;
    variable q_rd_v    : natural range 0 to C_QUEUE_SIZE - 1;
    variable q_cnt_v   : natural range 0 to C_QUEUE_SIZE;
    variable out_v     : natural := 0;                  -- Beats received
    variable idle_v    : natural := 0;
  begin
    if rising_edge(clk) then
      if rst = '1' then
        s_valid      <= '0';
        s_data       <= (others => '0');
        s_last       <= '0';
        frames_v     := 0;
        beat_v       := 0;
        length_v     := 0;
        data_v       := (others => '0');
        dropped_v    := false;
        frame_len    := 0;
        q_wr_v       := 0;
        q_rd_v       := 0;
        q_cnt_v      := 0;
        exp_cnt_drop <= (others => '0');
      else

        ----------------------------------
        -- Reference model of the input side
        ----------------------------------

        if s_valid = '1' then
          if s_drop = '1' and not dropped_v then
            dropped_v    := true;
            exp_cnt_drop <= std_logic_vector(unsigned(exp_cnt_drop) + 1);
          end if;

          if s_ready = '1' then
            if not dropped_v then
              frame_v(frame_len) := s_last & s_data;
              frame_len          := frame_len + 1;
            end if;
            if s_last = '1' then
              if not dropped_v then
                for i in 0 to frame_len - 1 loop
                  assert q_cnt_v < C_QUEUE_SIZE
                    report "tb_axis_dropper: Queue overflow"
                    severity failure;
                  queue_v(q_wr_v) := frame_v(i);
                  q_wr_v          := (q_wr_v + 1) mod C_QUEUE_SIZE;
                  q_cnt_v         := q_cnt_v + 1;
                end loop;
              end if;
              dropped_v := false;
              frame_len := 0;
            end if;
            s_valid <= '0';
          end if;
        end if;

        ----------------------------------
        -- Generate the next beat
        ----------------------------------

        if (s_valid = '0' or s_ready = '1') and frames_v < G_NUM_FRAMES and
           or(rand(R_RAND_VALID)) = '1' then
          if beat_v = 0 then
            length_v := to_integer(unsigned(rand(R_RAND_LENGTH))) mod G_MAX_LENGTH + 1;
          end if;
          s_valid <= '1';
          s_data  <= std_logic_vector(data_v);
          data_v  := data_v + 1;
          if beat_v = length_v - 1 then
            s_last   <= '1';
            beat_v   := 0;
            frames_v := frames_v + 1;
          else
            s_last <= '0';
            beat_v := beat_v + 1;
          end if;
        end if;

        ----------------------------------
        -- Verify the output
        ----------------------------------

        if m_valid = '1' and m_ready = '1' then
          assert q_cnt_v > 0
            report "tb_axis_dropper: Unexpected output beat " & to_hstring(m_data)
            severity failure;
          assert m_last & m_data = queue_v(q_rd_v)
            report "tb_axis_dropper: Output beat " & integer'image(out_v) &
                   ". Received " & to_string(m_last) & " " & to_hstring(m_data) &
                   ", expected " & to_string(queue_v(q_rd_v)(G_DATA_BITS)) & " " &
                   to_hstring(queue_v(q_rd_v)(G_DATA_BITS - 1 downto 0))
            severity failure;
          q_rd_v  := (q_rd_v + 1) mod C_QUEUE_SIZE;
          q_cnt_v := q_cnt_v - 1;
          out_v   := out_v + 1;
        end if;

        ----------------------------------
        -- End of test
        ----------------------------------

        if frames_v = G_NUM_FRAMES and s_valid = '0' and q_cnt_v = 0 and m_valid = '0' then
          idle_v := idle_v + 1;
        else
          idle_v := 0;
        end if;
        if idle_v = 10 then
          report "tb_axis_dropper: Test finished. " & integer'image(out_v) & " beats received, " &
                 integer'image(G_NUM_FRAMES) & " frames sent";
          stop;
        end if;
      end if;
    end if;
  end process main_proc;

  -- The drop counter must match the reference model in every cycle
  cnt_proc : process (clk)
  begin
    if rising_edge(clk) then
      if rst = '0' then
        assert cnt_drop = exp_cnt_drop
          report "tb_axis_dropper: cnt_drop is " & to_hstring(cnt_drop) &
                 ", expected " & to_hstring(exp_cnt_drop)
          severity failure;
      end if;
    end if;
  end process cnt_proc;

end architecture tb;
