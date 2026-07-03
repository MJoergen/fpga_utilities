-- ---------------------------------------------------------------------------------------
-- Title       : axip_master_sim - Random AXI-stream packet generator (simulation only)
-- Description : Generates a stream of random packets for stimulating an AXI-stream sink.
--
--               Packet format on the wire (MSB byte lane first):
--                 * First beat, top byte lane : length byte L (== number of payload
--                                               bytes that follow the length byte)
--                 * Remaining byte lanes      : payload bytes from an incrementing
--                                               counter (stim_cnt)
--                 * Subsequent beats          : further payload bytes from stim_cnt
--                 * m_last_o is asserted on the beat carrying the final payload byte
--
--               Example (G_DATA_BYTES = 4, packets end-to-end):
--                 Packet 1 (L=3): 03 00 01 02
--                 Packet 2 (L=4): 04 03 04 05     06 __ __ __
--                 Packet 3 (L=2): 02 07 08
--
--               The payload byte counter (stim_cnt) is monotonically incrementing
--               across packet boundaries and is only cleared by rst_i. A downstream
--               checker seeded identically can therefore reproduce the expected
--               byte sequence deterministically for end-to-end integrity checks.
--
--               There are no idle gaps in the output stream: a new packet is
--               launched on the same cycle the previous packet's last beat is
--               accepted. This is achieved by the guard
--                   (m_ready_i = '1' or m_valid_o = '0')
--               on both FSM states.
--
-- Requires    : VHDL-2008 (to_string, to_hstring, numeric_std_unsigned)
--
-- SPDX-License-Identifier: MIT
-- ---------------------------------------------------------------------------------------

library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std_unsigned.all;

entity axip_master_sim is
  generic (
    G_SEED       : std_logic_vector(63 downto 0) := x"DEADBEEFC007BABE"; -- RNG seed
    G_NAME       : string                        := "";                  -- Instance tag for report messages
    G_DEBUG      : boolean                       := false;               -- If true, per-packet length is logged
    G_CNT_SIZE   : natural                       := 8;                   -- Width of stim_cnt (must be >= 8)
    G_DATA_BYTES : natural;                                              -- Bus width in bytes (must be >= 2)
    G_MIN_LENGTH : natural                       := 1;                   -- Min payload bytes per packet (>= 1)
    G_MAX_LENGTH : natural                       := 255                  -- Max payload bytes per packet (<= 255)
  );
  port (
    clk_i     : in    std_logic;
    rst_i     : in    std_logic;                        -- Synchronous, active-high reset

    -- Master AXI-stream-like interface. Standard valid/ready handshake:
    -- a transfer occurs when both m_valid_o and m_ready_i are '1' on a
    -- rising edge of clk_i. m_bytes_o carries the number of valid bytes on
    -- this beat and is guaranteed to be non-zero whenever m_valid_o = '1'.
    m_ready_i : in    std_logic;
    m_valid_o : out   std_logic;
    m_data_o  : out   std_logic_vector(G_DATA_BYTES * 8 - 1 downto 0);
    m_last_o  : out   std_logic;                        -- '1' on the last beat of a packet
    m_bytes_o : out   natural range 0 to G_DATA_BYTES   -- Number of valid bytes in this beat
  );
end entity axip_master_sim;

architecture simulation of axip_master_sim is

  -- Maximum payload bytes per packet. This is bounded by the 8-bit length
  -- field in the first beat; do NOT raise without also widening that field.
  constant C_MAX_PACKET_LEN : natural := 255;

  -- State machine controlling packet generation and transmission:
  --   IDLE_ST : roll a new random length and emit the FIRST beat.
  --   DATA_ST : emit continuation beats until the packet is complete.
  type    state_type is (IDLE_ST, DATA_ST);
  signal  state : state_type := IDLE_ST;

  -- Global payload byte counter. Runs unbroken across packet boundaries and
  -- is only cleared by rst_i, so a downstream checker can reproduce the
  -- expected byte sequence deterministically from the same seed.
  signal  stim_cnt   : std_logic_vector(G_CNT_SIZE - 1 downto 0);

  -- Payload bytes still to emit for the packet currently being sent
  -- (i.e. not counting the length byte, and not counting bytes already sent).
  signal  bytes_left : natural range 0 to C_MAX_PACKET_LEN;

  -- 64-bit uniform-random word regenerated every clock by the RNG below.
  signal  rand : std_logic_vector(63 downto 0);

  -- Slice of rand used to derive the packet length.
  -- The size of the slice (16 bits) is chosen large enough such that the
  -- modulo operation generates a roughly uniform distribution over
  -- [G_MIN_LENGTH, G_MAX_LENGTH].
  subtype R_RAND_LENGTH is natural range 15 downto 0;

begin

  ----------------------------------------------------------
  -- Static parameter checks
  ----------------------------------------------------------

  assert G_CNT_SIZE >= 8
    report "axip_master_sim: G_CNT_SIZE must be >= 8"
    severity failure;

  assert G_DATA_BYTES >= 2
    report "axip_master_sim: G_DATA_BYTES must be >= 2"
    severity failure;

  assert G_MIN_LENGTH >= 1
    report "axip_master_sim: G_MIN_LENGTH must be >= 1"
    severity failure;

  assert G_MIN_LENGTH <= G_MAX_LENGTH
    report "axip_master_sim: G_MIN_LENGTH must be <= G_MAX_LENGTH"
    severity failure;

  assert G_MAX_LENGTH <= C_MAX_PACKET_LEN
    report "axip_master_sim: G_MAX_LENGTH must be <= " & to_string(C_MAX_PACKET_LEN)
    severity failure;

  -- Runtime protocol check: a beat with m_valid_o = '1' must always carry
  -- at least one valid byte. The guard on rst_i avoids spurious firings
  -- during the pre-reset window when signals may still be 'U'.
  assert not (m_bytes_o = 0 and m_valid_o = '1' and rst_i = '0')
    report "axip_master_sim: zero-byte beat generated"
    severity failure;


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
    ); -- random_inst


  ----------------------------------------------------------
  -- Generate AXI packet output
  ----------------------------------------------------------
  --
  -- FSM behaviour:
  --   IDLE_ST : rolls a new random packet length and emits the FIRST beat
  --             (length byte + up to G_DATA_BYTES-1 payload bytes). Stays
  --             in IDLE_ST if the whole packet fitted in one beat;
  --             otherwise moves to DATA_ST with bytes_left tracking the
  --             remainder.
  --   DATA_ST : emits payload beats until bytes_left <= G_DATA_BYTES, then
  --             asserts m_last_o and returns to IDLE_ST on the same cycle.
  --
  -- The guard "(m_ready_i = '1' or m_valid_o = '0')" ensures back-to-back
  -- packets are emitted without any idle gap between them.
  ----------------------------------------------------------

  fsm_proc : process (clk_i)
    variable length_v : natural range 0 to C_MAX_PACKET_LEN;
    variable first_v  : boolean := true;
  begin
    if rising_edge(clk_i) then

      -- One-shot startup banner printed on the first non-reset cycle.
      if rst_i = '0' and first_v then
        report "axip_master_sim " & G_NAME &
               ": Test started";
        first_v := false;
      end if;

      -- Clear m_valid_o whenever the current beat has been accepted; the
      -- FSM body below may re-assert it in the same cycle if a new beat
      -- is ready to be presented (last-assignment-wins).
      if m_ready_i = '1' then
        m_valid_o <= '0';
      end if;

      case state is

        when IDLE_ST =>
          -- We may drive a new beat this cycle.
          if (m_ready_i = '1' or m_valid_o = '0') and rst_i = '0' then

            -- First-beat layout, MSB byte lane first:
            --
            --   byte lane [G_DATA_BYTES-1]       : length byte (== length_v,
            --                                      the number of payload bytes
            --                                      that will follow the length
            --                                      byte in this packet)
            --   byte lanes [G_DATA_BYTES-2 .. 0] : payload byte counter values
            --                                      stim_cnt+0 ..
            --                                      stim_cnt+min(length_v, G_DATA_BYTES-1)-1
            --
            -- Total bytes on the wire = 1 (length) + length_v (payload).

            -- Draw a new packet length uniformly from [G_MIN_LENGTH, G_MAX_LENGTH].
            length_v := (to_integer(rand(R_RAND_LENGTH)) mod (G_MAX_LENGTH - G_MIN_LENGTH + 1)) + G_MIN_LENGTH;

            -- Per-packet debug trace: length and starting byte value.
            if rst_i = '0' and G_DEBUG then
              report "axip_master_sim " & G_NAME &
                     ": STIM length " & to_string(length_v) &
                     ", first byte " & to_hstring(stim_cnt(7 downto 0));
            end if;

            -- Place the length byte in the top (MSB) byte lane.
            m_data_o(G_DATA_BYTES * 8 - 1 downto G_DATA_BYTES * 8 - 8) <= to_slv(length_v, 8);

            -- Fill payload lanes below the length byte, MSB lane first
            -- (lane G_DATA_BYTES-2 gets stim_cnt+0, lane G_DATA_BYTES-3
            -- gets stim_cnt+1, ...). At most min(G_DATA_BYTES-1, length_v)
            -- payload bytes are written here; any remainder is streamed
            -- from DATA_ST.
            for i in 1 to G_DATA_BYTES - 1 loop
              if i <= length_v then
                m_data_o((G_DATA_BYTES - 1 - i) * 8 + 7 downto (G_DATA_BYTES - 1 - i) * 8) <= stim_cnt(7 downto 0) + i - 1;
              end if;
            end loop;

            m_valid_o <= '1';

            if length_v <= G_DATA_BYTES - 1 then
              -- Whole packet fits in the first beat: emit and stay in IDLE_ST.
              m_bytes_o <= length_v + 1;    -- 1 length byte + length_v payload bytes
              m_last_o  <= '1';
              stim_cnt  <= stim_cnt + length_v;
            else
              -- Packet spans multiple beats. First beat is full
              -- (length byte + G_DATA_BYTES-1 payload bytes); the
              -- remainder is streamed from DATA_ST.
              m_bytes_o  <= G_DATA_BYTES;
              m_last_o   <= '0';
              bytes_left <= length_v - (G_DATA_BYTES - 1);
              stim_cnt   <= stim_cnt + (G_DATA_BYTES - 1);
              state      <= DATA_ST;
            end if;
          end if;

        when DATA_ST =>
          -- We may drive a new beat this cycle.
          if m_ready_i = '1' or m_valid_o = '0' then

            -- Fill lanes with payload bytes, MSB lane first.
            -- At most min(G_DATA_BYTES, bytes_left) lanes are written.
            for i in 0 to G_DATA_BYTES - 1 loop
              if i < bytes_left then
                m_data_o((G_DATA_BYTES - 1 - i) * 8 + 7 downto (G_DATA_BYTES - 1 - i) * 8) <= stim_cnt(7 downto 0) + i;
              end if;
            end loop;

            m_valid_o <= '1';

            if bytes_left <= G_DATA_BYTES then
              -- Final beat: emit remaining payload bytes and return to IDLE_ST.
              m_bytes_o <= bytes_left;
              m_last_o  <= '1';
              stim_cnt  <= stim_cnt + bytes_left;
              state     <= IDLE_ST;
            else
              -- Middle beat: full bus, more to follow.
              m_bytes_o  <= G_DATA_BYTES;
              m_last_o   <= '0';
              bytes_left <= bytes_left - G_DATA_BYTES;
              stim_cnt   <= stim_cnt + G_DATA_BYTES;
            end if;
          end if;

      end case;

      -- Synchronous reset overrides above logic. Note: m_last_o, m_data_o,
      -- and m_bytes_o are intentionally not cleared here; they are only
      -- meaningful when m_valid_o = '1', and m_valid_o is cleared below.
      if rst_i = '1' then
        stim_cnt  <= (others => '0');
        m_valid_o <= '0';
        state     <= IDLE_ST;
      end if;
    end if;
  end process fsm_proc;

end architecture simulation;

