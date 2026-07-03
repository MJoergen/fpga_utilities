-- ---------------------------------------------------------------------------------------
-- Title       : axip_slave_sim - AXI-stream packet checker (simulation only)
-- Description : Companion to axip_master_sim. Consumes a stream of packets and
--               verifies that each byte matches the expected value from a shared
--               reference byte counter (verf_cnt).
--
--               Expected packet format on the wire (MSB byte lane first):
--                 * First beat, top byte lane : length byte L (== number of payload
--                                               bytes that follow the length byte)
--                 * Remaining byte lanes      : payload bytes from an incrementing
--                                               counter (verf_cnt)
--                 * Subsequent beats          : further payload bytes from verf_cnt
--                 * s_last_i is expected on the beat carrying the final payload byte
--
--               The length byte itself is not counted by verf_cnt and is not
--               required to match any particular value; only the payload bytes
--               are checked.
--
--               Test termination: the process stops the simulation the first time
--               verf_cnt wraps around its full range (2**G_CNT_SIZE bytes). Size
--               G_CNT_SIZE to control test duration.
--
-- Backpressure: none. s_ready_o is tied high, so the checker never stalls the
--               upstream master. Randomised backpressure could be added later
--               without changing the checker logic.
--
-- Requires    : VHDL-2008 (to_string, to_hstring, numeric_std_unsigned)
--
-- SPDX-License-Identifier: MIT
-- ---------------------------------------------------------------------------------------

library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std_unsigned.all;

library std;
  use std.env.stop;

entity axip_slave_sim is
  generic (
    G_NAME       : string   := "";     -- Instance tag for report messages
    G_DEBUG      : boolean  := false;  -- If true, per-packet length is logged
    G_CNT_SIZE   : positive := 8;      -- Width of verf_cnt; also sets test duration
    G_DATA_BYTES : positive            -- Bus width in bytes (must be >= 2)
  );
  port (
    clk_i     : in    std_logic;
    rst_i     : in    std_logic;                        -- Synchronous, active-high reset

    -- Slave AXI-stream-like interface. Standard valid/ready handshake:
    -- a transfer occurs when both s_valid_i and s_ready_o are '1' on a
    -- rising edge of clk_i. s_bytes_i is only meaningful on the last
    -- beat of a packet (s_last_i = '1'); on non-last beats all
    -- G_DATA_BYTES lanes are assumed valid.
    s_ready_o : out   std_logic;
    s_valid_i : in    std_logic;
    s_data_i  : in    std_logic_vector(G_DATA_BYTES * 8 - 1 downto 0);
    s_last_i  : in    std_logic;                        -- '1' on the last beat of a packet
    s_bytes_i : in    natural range 0 to G_DATA_BYTES   -- Number of valid bytes in last beat
  );
end entity axip_slave_sim;

architecture simulation of axip_slave_sim is

  -- Maximum payload bytes per packet. Must match the value used by
  -- axip_master_sim (bounded by the 8-bit length field on the wire).
  constant C_MAX_PACKET_LEN : natural := 255;

  -- State machine controlling packet reception and verification:
  --   IDLE_ST : consume the FIRST beat of a packet, extract the length
  --             byte from the top lane and verify any payload bytes
  --             riding along in the lower lanes.
  --   DATA_ST : verify continuation beats until s_last_i is seen.
  type   state_type is (IDLE_ST, DATA_ST);
  signal state : state_type := IDLE_ST;

  -- Global payload byte counter mirroring axip_master_sim.stim_cnt.
  -- Runs unbroken across packet boundaries and is only cleared by rst_i,
  -- so any per-byte mismatch indicates data corruption in the DUT.
  signal verf_cnt   : std_logic_vector(G_CNT_SIZE - 1 downto 0);

  -- Payload bytes still to verify for the packet currently being received
  -- (not counting the length byte, and not counting bytes already checked).
  signal bytes_left : natural range 0 to C_MAX_PACKET_LEN;

begin

  ----------------------------------------------------------
  -- Static parameter checks
  ----------------------------------------------------------

  assert G_CNT_SIZE >= 8
    report "axip_slave_sim: G_CNT_SIZE must be >= 8"
    severity failure;

  assert G_DATA_BYTES >= 2
    report "axip_slave_sim: G_DATA_BYTES must be >= 2"
    severity failure;

  -- Runtime protocol check: a beat with s_valid_i = '1' must carry at
  -- least one valid byte on the final beat. The rst_i guard avoids
  -- spurious firings during the pre-reset window when signals may be 'U'.
  assert not (s_valid_i = '1' and s_last_i = '1' and s_bytes_i = 0 and rst_i = '0')
    report "axip_slave_sim: last beat with zero valid bytes"
    severity failure;

  ----------------------------------------------------------
  -- AXI-stream slave: unconditionally ready
  ----------------------------------------------------------

  s_ready_o <= '1';

  ----------------------------------------------------------
  -- Verify AXI packet input
  --
  -- The first beat of each packet carries the length byte in the top
  -- lane; the lower lanes carry the first up-to-(G_DATA_BYTES-1) payload
  -- bytes. Every payload byte is checked against verf_cnt and each match
  -- advances verf_cnt by one. On packet boundaries the FSM returns to
  -- IDLE_ST. Simulation terminates when verf_cnt wraps.
  ----------------------------------------------------------

  fsm_proc : process (clk_i)
    variable length_v : natural range 0 to C_MAX_PACKET_LEN;
    variable data_v   : std_logic_vector(7 downto 0);
  begin
    if rising_edge(clk_i) then

      case state is

        when IDLE_ST =>
          if s_valid_i = '1' then
            -- First beat of the packet. Extract the length byte from the
            -- top (MSB) byte lane; it is NOT itself a byte to be checked.
            length_v := to_integer(s_data_i(G_DATA_BYTES * 8 - 1 downto G_DATA_BYTES * 8 - 8));

            -- Per-packet debug trace: length and starting byte value.
            if G_DEBUG then
              report "axip_slave_sim " & G_NAME &
                     ": VERF length " & to_string(length_v) &
                     ", first byte " & to_hstring(verf_cnt(7 downto 0));
            end if;

            -- Verify the payload bytes that ride along in the lower lanes
            -- of the first beat (MSB lane first). At most
            -- min(G_DATA_BYTES-1, length_v) bytes are present here.
            --
            -- NOTE: the guard is "i <= length_v", not "i < length_v", so
            -- that the case length_v = G_DATA_BYTES - 1 (packet fits in
            -- one beat, last payload byte lands on the LSB lane) is
            -- checked. This mirrors the master's writer loop.
            for i in 1 to G_DATA_BYTES - 1 loop
              if i <= length_v then
                data_v := s_data_i((G_DATA_BYTES - 1 - i) * 8 + 7 downto (G_DATA_BYTES - 1 - i) * 8);
                assert data_v = verf_cnt(7 downto 0) + (i - 1)
                  report "axip_slave_sim " & G_NAME &
                         ": Verify byte " & to_string(i) &
                         ". Received " & to_hstring(data_v) &
                         ", expected " & to_hstring(verf_cnt(7 downto 0) + (i - 1))
                  severity failure;
              end if;
            end loop;

            if s_last_i = '1' then
              -- Single-beat packet: advance verf_cnt by the number of
              -- payload bytes actually present (s_bytes_i - 1 excludes
              -- the length byte, which is not part of the checked stream).
              verf_cnt <= verf_cnt + s_bytes_i - 1;
            else
              -- Multi-beat packet: this first beat carried
              -- (G_DATA_BYTES - 1) payload bytes; the remainder will
              -- arrive in DATA_ST.
              verf_cnt   <= verf_cnt + G_DATA_BYTES - 1;
              bytes_left <= length_v - (G_DATA_BYTES - 1);
              state      <= DATA_ST;
            end if;
          end if;

        when DATA_ST =>
          if s_valid_i = '1' then

            -- Verify payload bytes on this continuation beat, MSB lane
            -- first. At most min(G_DATA_BYTES, bytes_left) bytes are
            -- valid; the loop guard bytes_left is decremented below.
            for i in 0 to G_DATA_BYTES - 1 loop
              if i < bytes_left then
                data_v := s_data_i((G_DATA_BYTES - 1 - i) * 8 + 7 downto (G_DATA_BYTES - 1 - i) * 8);
                assert data_v = verf_cnt(7 downto 0) + i
                  report "axip_slave_sim " & G_NAME &
                         ": Verify byte " & to_string(i) &
                         ". Received " & to_hstring(data_v) &
                         ", expected " & to_hstring(verf_cnt(7 downto 0) + i)
                  severity failure;
              end if;
            end loop;

            if s_last_i = '1' then
              -- Final beat: advance by the number of valid bytes it
              -- carries and return to IDLE_ST to await the next packet.
              verf_cnt <= verf_cnt + s_bytes_i;
              state    <= IDLE_ST;
            else
              -- Middle beat: full bus of payload; more beats to come.
              verf_cnt   <= verf_cnt + G_DATA_BYTES;
              bytes_left <= bytes_left - G_DATA_BYTES;
            end if;

            -- Test-termination heuristic: stop the simulation the first
            -- time verf_cnt wraps its full range. Sized by G_CNT_SIZE
            -- (2**G_CNT_SIZE bytes verified before the run ends).
            if verf_cnt > verf_cnt + s_bytes_i then
              report "axip_slave_sim " & G_NAME &
                     ": Test finished";
              stop;
            end if;
          end if;

      end case;

      -- Synchronous reset overrides above logic.
      if rst_i = '1' then
        verf_cnt   <= (others => '0');
        bytes_left <= 0;
        state      <= IDLE_ST;
      end if;
    end if;
  end process fsm_proc;

end architecture simulation;

