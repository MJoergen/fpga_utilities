-- ---------------------------------------------------------------------------------------
-- Description: Generates a stream of random packets and verifies the response.
-- ---------------------------------------------------------------------------------------

library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std_unsigned.all;

library std;
  use std.env.stop;

library work;
  use work.axis_pkg.all;
  use work.axip_pkg.all;

entity axip_slave_sim is
  generic (
    G_SEED       : std_logic_vector(63 downto 0) := x"DEADBEAFC007BABE";
    G_NAME       : string                        := "";
    G_DEBUG      : boolean;
    G_RANDOM     : boolean;
    G_MIN_LENGTH : natural;
    G_MAX_LENGTH : natural;
    G_CNT_SIZE   : natural
  );
  port (
    clk_i  : in    std_logic;
    rst_i  : in    std_logic;
    s_axip : view  axip_slave_view
  );
end entity axip_slave_sim;

architecture simulation of axip_slave_sim is

  constant C_DATA_BYTES : positive := s_axip.data'length / 8;

  -- C_LENGTH_SIZE is the number of bits necessary to encode the packet length.
  -- The value 8 allows packet lengths up to 255 bytes.
  constant C_LENGTH_SIZE : natural         := 8;

  -- State machine for controlling reception and verification of AXI packets.
  type     verf_state_type is (VERF_IDLE_ST, VERF_DATA_ST);
  signal   verf_state    : verf_state_type := VERF_IDLE_ST;
  signal   verf_length   : natural range 0 to G_MAX_LENGTH;
  signal   verf_cnt      : std_logic_vector(G_CNT_SIZE - 1 downto 0);
  signal   verf_do_ready : std_logic;

  -- Randomness
  signal   rand : std_logic_vector(63 downto 0);

  -- This controls how often data is received.

  subtype  R_RAND_DO_READY is natural range 32 downto 30;

  signal   header : axis_rec_type (
                                   data(7 downto 0)
                                  );

  signal   payload : axip_rec_type (
                                    data(C_DATA_BYTES * 8 - 1 downto 0)
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
  -- Remove length as first byte
  ----------------------------------------------------------

  axip_remove_fixed_header_inst : entity work.axip_remove_fixed_header
    port map (
      clk_i  => clk_i,
      rst_i  => rst_i,
      s_axip => s_axip,
      m_axip => payload,
      h_axis => header
    ); -- axip_remove_fixed_header_inst : entity work.axip_remove_fixed_header


  ----------------------------------------------------------
  -- Verify AXI packet input
  ----------------------------------------------------------

  verf_do_ready <= or(rand(R_RAND_DO_READY)) when G_RANDOM else
                   '1';
  payload.ready <= verf_do_ready when verf_state = VERF_DATA_ST else
                   '0';

  header.ready  <= '1' when verf_state = VERF_IDLE_ST else
                   '0';

  verify_proc : process (clk_i)
    variable length_v : natural range G_MIN_LENGTH to G_MAX_LENGTH;
  begin
    if rising_edge(clk_i) then

      case verf_state is

        when VERF_IDLE_ST =>
          if header.valid = '1' and header.ready = '1' then
            length_v := to_integer(header.data);
            if G_DEBUG then
              report "axip_sim " & G_NAME &
                     ": VERF length " & to_string(length_v);
            end if;
            verf_length <= length_v;
            verf_state  <= VERF_DATA_ST;
          end if;

        when VERF_DATA_ST =>
          if payload.valid = '1' and payload.ready = '1' then

            for i in 0 to payload.bytes - 1 loop
              assert payload.data((C_DATA_BYTES - 1 - i) * 8 + 7 downto (C_DATA_BYTES - 1 - i) * 8) = verf_cnt(7 downto 0) + i
                report "axip_sim " & G_NAME &
                       ": Verify byte " & to_string(i) &
                       ". Received " & to_hstring(payload.data(i * 8 + 7 downto i * 8)) &
                       ", expected " & to_hstring(verf_cnt(7 downto 0) + i);
            end loop;

            verf_cnt    <= verf_cnt + payload.bytes;
            assert payload.bytes <= verf_length
              report "axip_sim " & G_NAME &
                     ": FAIL: Packet too long";
            verf_length <= verf_length - payload.bytes;

            if payload.last = '1' then
              assert payload.bytes = verf_length
                report "axip_sim " & G_NAME &
                       ": FAIL: Packet length received=" & to_string(verf_length - payload.bytes);
              verf_state <= VERF_IDLE_ST;
            end if;

            -- Check for wrap-around
            if verf_cnt > verf_cnt + payload.bytes then
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

