-- ---------------------------------------------------------------------------------------
-- Description: Generates a stream of random packets and verifies the response.
-- ---------------------------------------------------------------------------------------

library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std_unsigned.all;

library std;
  use std.env.stop;

entity axip_sim is
  generic (
    G_SEED       : std_logic_vector(63 downto 0) := X"DEADBEAFC007BABE";
    G_NAME       : string := "";
    G_DEBUG      : boolean;
    G_RANDOM     : boolean;
    G_FAST       : boolean;
    G_MIN_LENGTH : natural;
    G_MAX_LENGTH : natural;
    G_CNT_SIZE   : natural;
    G_DATA_BYTES : natural
  );
  port (
    clk_i     : in    std_logic;
    rst_i     : in    std_logic;

    -- AXI packet output
    m_ready_i : in    std_logic;
    m_valid_o : out   std_logic;
    m_data_o  : out   std_logic_vector(G_DATA_BYTES * 8 - 1 downto 0);
    m_last_o  : out   std_logic;
    m_bytes_o : out   natural range 0 to G_DATA_BYTES;

    -- AXI packet input
    s_ready_o : out   std_logic;
    s_valid_i : in    std_logic;
    s_data_i  : in    std_logic_vector(G_DATA_BYTES * 8 - 1 downto 0);
    s_last_i  : in    std_logic;
    s_bytes_i : in    natural range 0 to G_DATA_BYTES
  );
end entity axip_sim;

architecture simulation of axip_sim is

  -- C_LENGTH_SIZE is the number of bits necessary to encode the packet length.
  -- The value 8 allows packet lengths up to 255 bytes.
  constant C_LENGTH_SIZE : natural         := 8;

  -- C_RAM_DEPTH is the maximum number of allowed packets sent but not received. The
  -- reason is that the lengths of each transmitted packet must be stored until the
  -- packet is received. So this value is determined by the maximum latency outside this
  -- module.
  constant C_RAM_DEPTH : natural           := 4;

  -- FIFO containing lengths of packets sent, but not yet received.
  signal   length_s_ready : std_logic;
  signal   length_s_valid : std_logic;
  signal   length_s_data  : std_logic_vector(C_LENGTH_SIZE - 1 downto 0);
  signal   length_m_ready : std_logic;
  signal   length_m_valid : std_logic;
  signal   length_m_data  : std_logic_vector(C_LENGTH_SIZE - 1 downto 0);
  signal   length_fill    : natural range 0 to C_RAM_DEPTH - 1;

  -- State machine for controlling generation and transmission of AXI packets.
  type     stim_state_type is (STIM_IDLE_ST, STIM_DATA_ST);
  signal   stim_state    : stim_state_type := STIM_IDLE_ST;
  signal   stim_length   : natural range 0 to G_MAX_LENGTH;
  signal   stim_cnt      : std_logic_vector(G_CNT_SIZE - 1 downto 0);
  signal   stim_do_valid : std_logic;

  -- State machine for controlling reception and verification of AXI packets.
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

  assert G_MAX_LENGTH < 2 ** C_LENGTH_SIZE;


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
  -- Generate AXI packet output
  ----------------------------------------------------------

  stim_do_valid <= or(rand(R_RAND_DO_VALID)) when G_RANDOM else
                   '1';

  stimuli_proc : process (clk_i)
    variable length_v : natural range G_MIN_LENGTH to G_MAX_LENGTH;
    variable bytes_v  : natural range 1 to G_DATA_BYTES;
    variable first_v  : boolean := true;
  begin
    if rising_edge(clk_i) then
      if rst_i = '0' and first_v then
        report "axip_sim " & G_NAME &
               ": Test started";
        first_v := false;
      end if;

      if m_ready_i = '1' then
        m_valid_o <= '0';
        m_data_o  <= (others => '0');
        m_last_o  <= '0';
        m_bytes_o <= 0;
      end if;

      if length_s_ready = '1' then
        length_s_valid <= '0';
      end if;

      case stim_state is

        when STIM_IDLE_ST =>
          if length_s_ready = '1' or length_s_valid = '0' then
            length_v := (to_integer(rand(R_RAND_LENGTH)) mod (G_MAX_LENGTH - G_MIN_LENGTH + 1)) + G_MIN_LENGTH;

            if rst_i = '0' and G_DEBUG then
              report "axip_sim " & G_NAME &
                     ": STIM length " & to_string(length_v);
            end if;

            -- Store length in FIFO
            length_s_data  <= to_stdlogicvector(length_v, C_LENGTH_SIZE);
            length_s_valid <= '1';

            stim_length    <= length_v;
            stim_state     <= STIM_DATA_ST;
          end if;

        when STIM_DATA_ST =>
          if m_valid_o = '0' or (G_FAST and m_ready_i = '1') then
            if stim_do_valid = '1' then
              bytes_v := G_DATA_BYTES;
              if bytes_v > stim_length then
                bytes_v := stim_length;
              end if;

              stim_cnt    <= stim_cnt + bytes_v;
              stim_length <= stim_length - bytes_v;

              for i in 0 to bytes_v - 1 loop
                m_data_o((G_DATA_BYTES - 1 - i) * 8 + 7 downto (G_DATA_BYTES - 1 - i) * 8) <= stim_cnt(7 downto 0) + i;
              end loop;

              m_valid_o <= '1';
              m_bytes_o <= bytes_v;
              if stim_length = bytes_v then
                m_last_o   <= '1';
                stim_state <= STIM_IDLE_ST;

                if G_FAST then
                  if length_s_ready = '1' or length_s_valid = '0' then
                    length_v := (to_integer(rand(R_RAND_LENGTH)) mod (G_MAX_LENGTH - G_MIN_LENGTH + 1)) + G_MIN_LENGTH;

                    if rst_i = '0' and G_DEBUG then
                      report "axip_sim " & G_NAME &
                             ": STIM length " & to_string(length_v);
                    end if;

                    -- Store length in FIFO
                    length_s_data  <= to_stdlogicvector(length_v, C_LENGTH_SIZE);
                    length_s_valid <= '1';

                    stim_length    <= length_v;
                    stim_state     <= STIM_DATA_ST;
                  end if;
                end if;
              end if;
            end if;
          end if;

      end case;

      if rst_i = '1' then
        m_valid_o      <= '0';
        m_data_o       <= (others => '0');
        m_last_o       <= '0';
        m_bytes_o      <= 0;
        --
        length_s_valid <= '0';
        stim_cnt       <= (others => '0');
        stim_state     <= STIM_IDLE_ST;
      end if;
    end if;
  end process stimuli_proc;


  ----------------------------------------------------------
  -- Instantiate FIFO containing lengths of each AXI packet
  ----------------------------------------------------------

  axis_fifo_sync_length_inst : entity work.axis_fifo_sync
    generic map (
      G_RAM_STYLE => "auto",
      G_DATA_SIZE => C_LENGTH_SIZE,
      G_RAM_DEPTH => C_RAM_DEPTH
    )
    port map (
      clk_i     => clk_i,
      rst_i     => rst_i,
      fill_o    => length_fill,
      s_ready_o => length_s_ready,
      s_valid_i => length_s_valid,
      s_data_i  => length_s_data,
      m_ready_i => length_m_ready,
      m_valid_o => length_m_valid,
      m_data_o  => length_m_data
    ); -- axis_fifo_sync_length_inst : entity work.axis_fifo_sync


  ----------------------------------------------------------
  -- Verify AXI packet input
  ----------------------------------------------------------

  verf_do_ready  <= or(rand(R_RAND_DO_READY)) when G_RANDOM else
                    '1';
  s_ready_o      <= verf_do_ready when verf_state = VERF_DATA_ST else
                    '0';

  length_m_ready <= '1' when verf_state = VERF_IDLE_ST else
                    '0';

  verify_proc : process (clk_i)
    variable length_v : natural range G_MIN_LENGTH to G_MAX_LENGTH;
  begin
    if rising_edge(clk_i) then

      case verf_state is

        when VERF_IDLE_ST =>
          if length_m_valid = '1' and length_m_ready = '1' then
            length_v := to_integer(length_m_data);
            if G_DEBUG then
              report "axip_sim " & G_NAME &
                     ": VERF length " & to_string(length_v);
            end if;
            verf_length <= length_v;
            verf_state  <= VERF_DATA_ST;
          end if;

        when VERF_DATA_ST =>
          if s_valid_i = '1' and s_ready_o = '1' then

            for i in 0 to s_bytes_i - 1 loop
              assert s_data_i((G_DATA_BYTES - 1 - i) * 8 + 7 downto (G_DATA_BYTES - 1 - i) * 8) = verf_cnt(7 downto 0) + i
                report "axip_sim " & G_NAME &
                       ": Verify byte " & to_string(i) &
                       ". Received " & to_hstring(s_data_i(i * 8 + 7 downto i * 8)) &
                       ", expected " & to_hstring(verf_cnt(7 downto 0) + i);
            end loop;

            verf_cnt    <= verf_cnt + s_bytes_i;
            assert s_bytes_i <= verf_length
              report "axip_sim " & G_NAME &
                     ": FAIL: Packet too long";
            verf_length <= verf_length - s_bytes_i;

            if s_last_i = '1' then
              assert s_bytes_i = verf_length
                report "axip_sim " & G_NAME &
                       ": FAIL: Packet length received=" & to_string(verf_length - s_bytes_i);
              verf_state <= VERF_IDLE_ST;
            end if;

            -- Check for wrap-around
            if verf_cnt > verf_cnt + s_bytes_i then
              report "axip_sim " & G_NAME &
                     ": Test finished";
              stop;
            end if;
          end if;

      end case;

      if rst_i = '1' then
        verf_cnt   <= (others => '0');
        verf_state <= VERF_IDLE_ST;
      end if;
    end if;
  end process verify_proc;

end architecture simulation;

