-- ---------------------------------------------------------------------------------------
-- Description: Verify axip_remove_fixed_header
-- ---------------------------------------------------------------------------------------

library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std_unsigned.all;

library std;
  use std.env.stop;

library work;
  use work.axis_pkg.all;
  use work.axip_pkg.all;

entity tb_axip_remove_fixed_header is
  generic (
    G_DEBUG        : boolean;
    G_MAX_LENGTH   : natural;
    G_CNT_SIZE     : natural;
    G_FAST         : boolean;
    G_RANDOM       : boolean;
    G_DATA_BYTES   : natural;
    G_HEADER_BYTES : natural
  );
end entity tb_axip_remove_fixed_header;

architecture simulation of tb_axip_remove_fixed_header is

  signal   clk : std_logic                 := '1';
  signal   rst : std_logic                 := '1';

  signal   s_axip : axip_rec_type (
                                   data(G_DATA_BYTES * 8 - 1 downto 0)
                                  );

  signal   m_axip : axip_rec_type (
                                   data(G_DATA_BYTES * 8 - 1 downto 0)
                                  );

  signal   h_axis : axis_rec_type (
                                   data(G_HEADER_BYTES * 8 - 1 downto 0)
                                  );


  -- C_LENGTH_SIZE is the number of bits necessary to encode the packet length.
  -- The value 8 allows packet lengths up to 255 bytes.
  constant C_LENGTH_SIZE : natural         := 8;

  -- C_RAM_DEPTH is the maximum number of allowed packets sent but not received. The
  -- reason is that the lengths of each transmitted packet must be stored until the
  -- packet is received. So this value is determined by the maximum latency outside this
  -- module.
  constant C_RAM_DEPTH : natural           := 4;

  -- FIFO containing lengths of packets sent, but not yet received.
  signal   length_s_axis : axis_rec_type (
                                          data(C_LENGTH_SIZE - 1 downto 0)
                                         );
  signal   length_m_axis : axis_rec_type (
                                          data(C_LENGTH_SIZE - 1 downto 0)
                                         );

  signal   length_fill : natural range 0 to C_RAM_DEPTH - 1;

  -- State machine for controlling generation and transmission of packets.
  type     stim_state_type is (STIM_IDLE_ST, STIM_DATA_ST);
  signal   stim_state    : stim_state_type := STIM_IDLE_ST;
  signal   stim_length   : natural range 0 to G_MAX_LENGTH;
  signal   stim_cnt      : std_logic_vector(G_CNT_SIZE - 1 downto 0);
  signal   stim_do_valid : std_logic;

  -- State machine for controlling reception and verification of packets.
  type     verf_state_type is (VERF_IDLE_ST, VERF_DATA_ST);
  signal   verf_state    : verf_state_type := VERF_IDLE_ST;
  signal   verf_length   : natural range 0 to G_MAX_LENGTH;
  signal   verf_cnt      : std_logic_vector(G_CNT_SIZE - 1 downto 0);
  signal   verf_do_ready : std_logic;

  -- Randomness
  signal   rand : std_logic_vector(63 downto 0);

  -- This controls how often data is transmitted.

  subtype  R_RAND_DO_VALID is natural range 42 downto 40;

  -- This controls how often data is received.

  subtype  R_RAND_DO_READY is natural range 32 downto 30;

  -- This controls the total length of the packet.

  subtype  R_RAND_LENGTH is natural range 20 downto 5;

  -- This controls the number of bytes sent in this beat.

  subtype  R_RAND_BYTES is natural range 15 downto 0;

  -- This controls the first byte sent in this beat.

  subtype  R_RAND_START is natural range 35 downto 20;

begin

  --------------------------------------------
  -- Clock and reset
  --------------------------------------------

  clk <= not clk after 5 ns;
  rst <= '1', '0' after 100 ns;

  h_axis.ready <= '1';

  --------------------------------------------
  -- Instantiate DUT
  --------------------------------------------

  axip_remove_fixed_header_inst : entity work.axip_remove_fixed_header
    port map (
      clk_i  => clk,
      rst_i  => rst,
      s_axip => s_axip,
      m_axip => m_axip,
      h_axis => h_axis
    ); -- axip_remove_fixed_header_inst : entity work.axip_remove_fixed_header


  --------------------------------------------
  -- Generate stimuli and verify response
  --------------------------------------------

  assert G_MAX_LENGTH < 2 ** C_LENGTH_SIZE;

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


  stim_do_valid <= or(rand(R_RAND_DO_VALID)) when G_RANDOM else
                   '1';

  stimuli_proc : process (clk)
    variable length_v : natural range 1 to G_MAX_LENGTH;
    variable bytes_v  : natural range 1 to G_DATA_BYTES;
    variable first_v  : boolean := true;
  begin
    if rising_edge(clk) then
      if rst = '0' and first_v then
        report "Test started";
        first_v := false;
      end if;

      if s_axip.ready = '1' then
        s_axip.valid <= '0';
        s_axip.data  <= (others => '0');
        s_axip.bytes <= 0;
        s_axip.last  <= '0';
      end if;

      if length_s_axis.ready = '1' then
        length_s_axis.valid <= '0';
      end if;

      case stim_state is

        when STIM_IDLE_ST =>
          if length_s_axis.ready = '1' or length_s_axis.valid = '0' then
            length_v := (to_integer(rand(R_RAND_LENGTH)) mod (G_MAX_LENGTH - G_HEADER_BYTES)) + G_HEADER_BYTES;

            if rst = '0' and G_DEBUG then
              report "STIM length " & to_string(length_v);
            end if;

            -- Store length in FIFO
            length_s_axis.data  <= to_stdlogicvector(length_v, C_LENGTH_SIZE);
            length_s_axis.valid <= '1';

            stim_length         <= length_v;
            stim_state          <= STIM_DATA_ST;
          end if;

        when STIM_DATA_ST =>
          if s_axip.valid = '0' or (G_FAST and s_axip.ready = '1') then
            if stim_do_valid = '1' then
              bytes_v := G_DATA_BYTES;
              if bytes_v > stim_length then
                bytes_v := stim_length;
              end if;

              stim_cnt    <= stim_cnt + bytes_v;
              stim_length <= stim_length - bytes_v;

              for i in 0 to bytes_v - 1 loop
                s_axip.data((G_DATA_BYTES - 1 - i) * 8 + 7 downto (G_DATA_BYTES - 1 - i) * 8) <= stim_cnt(7 downto 0) + i;
              end loop;

              s_axip.valid <= '1';
              s_axip.bytes <= bytes_v;
              s_axip.last  <= '0';
              if stim_length = bytes_v then
                s_axip.last <= '1';
                stim_state  <= STIM_IDLE_ST;

                if G_FAST then
                  if length_s_axis.ready = '1' or length_s_axis.valid = '0' then
                    length_v := (to_integer(rand(R_RAND_LENGTH)) mod (G_MAX_LENGTH - G_HEADER_BYTES)) + G_HEADER_BYTES;

                    if rst = '0' and G_DEBUG then
                      report "STIM length " & to_string(length_v);
                    end if;

                    -- Store length in FIFO
                    length_s_axis.data  <= to_stdlogicvector(length_v, C_LENGTH_SIZE);
                    length_s_axis.valid <= '1';

                    stim_length         <= length_v;
                    stim_state          <= STIM_DATA_ST;
                  end if;
                end if;
              end if;
            end if;
          end if;

      end case;

      if rst = '1' then
        s_axip.valid        <= '0';
        s_axip.data         <= (others => '0');
        s_axip.bytes        <= 0;
        s_axip.last         <= '0';
        --
        length_s_axis.valid <= '0';
        stim_cnt            <= (others => '0');
        stim_state          <= STIM_IDLE_ST;
      end if;
    end if;
  end process stimuli_proc;

  axis_fifo_length_inst : entity work.axis_fifo
    generic map (
      G_RAM_STYLE => "auto",
      G_RAM_DEPTH => C_RAM_DEPTH
    )
    port map (
      clk_i  => clk,
      rst_i  => rst,
      fill_o => length_fill,
      s_axis => length_s_axis,
      m_axis => length_m_axis
    ); -- axis_fifo_length_inst : entity work.axis_fifo


  ----------------------------------------------------------
  -- Verify output
  ----------------------------------------------------------

  verf_do_ready       <= or(rand(R_RAND_DO_READY)) when G_RANDOM else
                         '1';
  m_axip.ready        <= verf_do_ready when verf_state = VERF_DATA_ST else
                         '0';

  length_m_axis.ready <= '1' when verf_state = VERF_IDLE_ST else
                         '0';

  verify_proc : process (clk)
    variable length_v : natural range 1 to G_MAX_LENGTH;
  begin
    if rising_edge(clk) then

      case verf_state is

        when VERF_IDLE_ST =>
          if length_m_axis.valid = '1' and length_m_axis.ready = '1' then
            length_v := to_integer(length_m_axis.data);
            if G_DEBUG then
              report "VERF length " & to_string(length_v);
            end if;
            verf_length <= length_v - G_HEADER_BYTES;
            verf_cnt    <= verf_cnt + G_HEADER_BYTES;
            verf_state  <= VERF_DATA_ST;
          end if;

        when VERF_DATA_ST =>
          if m_axip.valid = '1' and m_axip.ready = '1' then
            assert m_axip.bytes <= verf_length
              report "FAIL: Packet too long";
            if m_axip.last = '1' then
              assert m_axip.bytes = verf_length
                report "FAIL: Packet length received=" & to_string(verf_length - m_axip.bytes);
            end if;

            for i in 0 to m_axip.bytes - 1 loop
              assert m_axip.data((G_DATA_BYTES - 1 - i) * 8 + 7 downto (G_DATA_BYTES - 1 - i) * 8) = verf_cnt(7 downto 0) + i
                report "Verify byte " & to_string(i) &
                       ". Received " & to_hstring(m_axip.data((G_DATA_BYTES - 1 - i) * 8 + 7 downto (G_DATA_BYTES - 1 - i) * 8)) &
                       ", expected " & to_hstring(verf_cnt(7 downto 0) + i);
            end loop;

            verf_cnt    <= verf_cnt + m_axip.bytes;
            verf_length <= verf_length - m_axip.bytes;

            if m_axip.last = '1' then
              verf_state <= VERF_IDLE_ST;
            end if;

            -- Check for wrap-around
            if verf_cnt > verf_cnt + m_axip.bytes then
              report "Test finished";
              stop;
            end if;
          end if;

      end case;

      if rst = '1' then
        verf_cnt   <= (others => '0');
        verf_state <= VERF_IDLE_ST;
      end if;
    end if;
  end process verify_proc;

end architecture simulation;

