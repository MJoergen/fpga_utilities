-- ---------------------------------------------------------------------------------------
-- Description: Generates a stream of random packets and verifies the response.
-- ---------------------------------------------------------------------------------------

library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std_unsigned.all;

library work;
  use work.axis_pkg.all;
  use work.axip_pkg.all;

entity axip_master_sim is
  generic (
    G_SEED       : std_logic_vector(63 downto 0) := x"DEADBEAFC007BABE";
    G_NAME       : string                        := "";
    G_DEBUG      : boolean;
    G_RANDOM     : boolean;
    G_FAST       : boolean;
    G_MIN_LENGTH : natural;
    G_MAX_LENGTH : natural;
    G_CNT_SIZE   : natural
  );
  port (
    clk_i  : in    std_logic;
    rst_i  : in    std_logic;
    m_axip : view axip_master_view
  );
end entity axip_master_sim;

architecture simulation of axip_master_sim is

  constant C_DATA_BYTES : positive         := m_axip.data'length / 8;

  -- C_LENGTH_SIZE is the number of bits necessary to encode the packet length.
  -- The value 8 allows packet lengths up to 255 bytes.
  constant C_LENGTH_SIZE : natural         := 8;

  -- State machine for controlling generation and transmission of AXI packets.
  type     stim_state_type is (STIM_IDLE_ST, STIM_DATA_ST);
  signal   stim_state    : stim_state_type := STIM_IDLE_ST;
  signal   stim_length   : natural range 0 to G_MAX_LENGTH;
  signal   stim_cnt      : std_logic_vector(G_CNT_SIZE - 1 downto 0);
  signal   stim_do_valid : std_logic;

  -- Randomness
  signal   rand : std_logic_vector(63 downto 0);

  -- This controls how often data is transmitted.

  subtype  R_RAND_DO_VALID is natural range 42 downto 40;

  -- This controls the total length of the packet.

  subtype  R_RAND_LENGTH is natural range 20 downto 5;

  signal   header : axis_rec_type (
                                   data(7 downto 0)
                                  );

  signal   payload : axip_rec_type (
                                    data(m_axip.data'range)
                                   );

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
    variable bytes_v  : natural range 1 to C_DATA_BYTES;
    variable first_v  : boolean := true;
  begin
    if rising_edge(clk_i) then
      if rst_i = '0' and first_v then
        report "axip_sim " & G_NAME &
               ": Test started";
        first_v := false;
      end if;

      if payload.ready = '1' then
        payload.valid <= '0';
        payload.data  <= (others => '0');
        payload.last  <= '0';
        payload.bytes <= 0;
      end if;

      if header.ready = '1' then
        header.valid <= '0';
      end if;

      case stim_state is

        when STIM_IDLE_ST =>
          if header.ready = '1' or header.valid = '0' then
            length_v := (to_integer(rand(R_RAND_LENGTH)) mod (G_MAX_LENGTH - G_MIN_LENGTH + 1)) + G_MIN_LENGTH;

            if rst_i = '0' and G_DEBUG then
              report "axip_sim " & G_NAME &
                     ": STIM length " & to_string(length_v);
            end if;

            -- Store length in FIFO
            header.data  <= to_stdlogicvector(length_v, C_LENGTH_SIZE);
            header.valid <= '1';

            stim_length  <= length_v;
            stim_state   <= STIM_DATA_ST;
          end if;

        when STIM_DATA_ST =>
          if payload.valid = '0' or (G_FAST and payload.ready = '1') then
            if stim_do_valid = '1' then
              bytes_v := C_DATA_BYTES;
              if bytes_v > stim_length then
                bytes_v := stim_length;
              end if;

              stim_cnt    <= stim_cnt + bytes_v;
              stim_length <= stim_length - bytes_v;

              for i in 0 to bytes_v - 1 loop
                payload.data((C_DATA_BYTES - 1 - i) * 8 + 7 downto (C_DATA_BYTES - 1 - i) * 8) <= stim_cnt(7 downto 0) + i;
              end loop;

              payload.valid <= '1';
              payload.bytes <= bytes_v;
              if stim_length = bytes_v then
                payload.last <= '1';
                stim_state   <= STIM_IDLE_ST;

                if G_FAST then
                  if header.ready = '1' or header.valid = '0' then
                    length_v := (to_integer(rand(R_RAND_LENGTH)) mod (G_MAX_LENGTH - G_MIN_LENGTH + 1)) + G_MIN_LENGTH;

                    if rst_i = '0' and G_DEBUG then
                      report "axip_sim " & G_NAME &
                             ": STIM length " & to_string(length_v);
                    end if;

                    -- Store length in FIFO
                    header.data  <= to_stdlogicvector(length_v, C_LENGTH_SIZE);
                    header.valid <= '1';

                    stim_length  <= length_v;
                    stim_state   <= STIM_DATA_ST;
                  end if;
                end if;
              end if;
            end if;
          end if;

      end case;

      if rst_i = '1' then
        payload.valid <= '0';
        payload.data  <= (others => '0');
        payload.last  <= '0';
        payload.bytes <= 0;
        --
        header.valid  <= '0';
        stim_cnt      <= (others => '0');
        stim_state    <= STIM_IDLE_ST;
      end if;
    end if;
  end process stimuli_proc;


  ----------------------------------------------------------
  -- Insert length as first byte
  ----------------------------------------------------------

  axip_insert_fixed_header_inst : entity work.axip_insert_fixed_header
    port map (
      clk_i  => clk_i,
      rst_i  => rst_i,
      h_axis => header,
      s_axip => payload,
      m_axip => m_axip
    ); -- axip_insert_fixed_header_inst : entity work.axip_insert_fixed_header

end architecture simulation;

