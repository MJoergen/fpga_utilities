--------------------------------------------------------------------------------
-- avm_decrease.vhd
--
-- Avalon Memory-Mapped (Avalon-MM) data-width down-converter.
--
-- The slave port (s_*) is the "wide" side and faces an upstream Avalon-MM
-- master. The master port (m_*) is the "narrow" side and faces a downstream
-- Avalon-MM slave. Each wide-side transaction is expanded into C_RATIO
-- narrow-side beats, where:
--
--     C_RATIO = G_SLAVE_DATA_BITS / G_MASTER_DATA_BITS  (must be a power of 2)
--
-- Address mapping: the master-side address has C_ADDRESS_SHIFT more LSBs than
-- the slave-side address. Those LSBs are driven to 0 by this block, because the
-- downstream slave's burst engine increments the address per beat.
--
-- Burst-count mapping: the slave-side burstcount is multiplied by C_RATIO to
-- produce the master-side burstcount, i.e. one wide beat -> C_RATIO narrow
-- beats. The shared port width G_BURST_BITS must be sized to hold the *master*
-- (multiplied) count without overflow.
--
-- Write path:
--   * The first wide write is registered on acceptance in IDLE_ST.
--   * WRITING_ST issues beats 0..C_RATIO-2; the final beat (index C_RATIO-1) is
--     intentionally issued from IDLE_ST, which allows a new transaction to be
--     latched on the same edge without disturbing the in-flight beat (back-to-
--     back bursts with zero idle gap).
--
-- Read path:
--   * A wide read is launched in IDLE_ST and immediately propagated; the master
--     issues a burst of C_RATIO narrow reads.
--   * Returning narrow words are reassembled into s_readdata_o using s_read_pos
--     as the sub-word index; s_readdatavalid_o pulses once per completed wide
--     word.
--   * READ_DRAIN_ST blocks new requests if a new burst would overlap an in-
--     flight one, because the design has only one reassembly counter.
--
-- Assumptions on the downstream slave:
--   * Avalon-MM compliant: read responses are returned in request order.
--   * Accepts m_burstcount_o held stable for the duration of the burst.
--   * Honours m_byteenable_o per beat.
--------------------------------------------------------------------------------

library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std.all;

entity avm_decrease is
  generic (
    -- Width of both s_burstcount_i and m_burstcount_o. Must be wide enough to
    -- hold the master-side count, i.e. (max slave burstcount) * C_RATIO without
    -- wrapping.
    G_BURST_BITS         : positive := 8;

    -- Address and data widths.
    -- Constraints (enforced by assertions in the architecture):
    --   * G_SLAVE_DATA_BITS = C_RATIO * G_MASTER_DATA_BITS
    --   * C_RATIO is a power of two (i.e. 2**C_ADDRESS_SHIFT = C_RATIO)
    --   * G_MASTER_ADDRESS_BITS = G_SLAVE_ADDRESS_BITS + log2(C_RATIO)
    -- A degenerate ratio of 1 is rejected; use a passthrough wrapper instead.
    G_SLAVE_ADDRESS_BITS  : positive;
    G_SLAVE_DATA_BITS     : positive; -- power-of-two multiple of G_MASTER_DATA_BITS
    G_MASTER_ADDRESS_BITS : positive;
    G_MASTER_DATA_BITS    : positive
  );
  port (
    clk_i             : in    std_logic;
    rst_i             : in    std_logic; -- Synchronous, active high.

    --------------------------------------------------------------------------
    -- Slave port (faces upstream Avalon-MM master) — wide side.
    -- s_waitrequest_o gates acceptance of (s_write_i | s_read_i).
    -- A new transaction is accepted on any edge where (s_write_i or s_read_i)
    -- and s_waitrequest_o = '0'.
    --------------------------------------------------------------------------
    s_waitrequest_o   : out   std_logic;
    s_write_i         : in    std_logic;
    s_read_i          : in    std_logic;
    s_address_i       : in    std_logic_vector(G_SLAVE_ADDRESS_BITS - 1 downto 0);
    s_writedata_i     : in    std_logic_vector(G_SLAVE_DATA_BITS - 1 downto 0);
    s_byteenable_i    : in    std_logic_vector(G_SLAVE_DATA_BITS / 8 - 1 downto 0);
    s_burstcount_i    : in    std_logic_vector(G_BURST_BITS - 1 downto 0);
    s_readdata_o      : out   std_logic_vector(G_SLAVE_DATA_BITS - 1 downto 0);
    s_readdatavalid_o : out   std_logic;

    --------------------------------------------------------------------------
    -- Master port (faces downstream Avalon-MM slave) — narrow side.
    -- m_burstcount_o is held stable for the whole burst. m_byteenable_o is
    -- updated per beat from the corresponding slice of s_byteenable.
    --------------------------------------------------------------------------
    m_waitrequest_i   : in    std_logic;
    m_write_o         : out   std_logic;
    m_read_o          : out   std_logic;
    m_address_o       : out   std_logic_vector(G_MASTER_ADDRESS_BITS - 1 downto 0);
    m_writedata_o     : out   std_logic_vector(G_MASTER_DATA_BITS - 1 downto 0);
    m_byteenable_o    : out   std_logic_vector(G_MASTER_DATA_BITS / 8 - 1 downto 0);
    m_burstcount_o    : out   std_logic_vector(G_BURST_BITS - 1 downto 0);
    m_readdata_i      : in    std_logic_vector(G_MASTER_DATA_BITS - 1 downto 0);
    m_readdatavalid_i : in    std_logic
  );
end entity avm_decrease;

architecture synthesis of avm_decrease is

  -- Expansion ratio: number of narrow (master) words per wide (slave) word.
  -- Required to be a power of two; this is enforced by the assertion
  --   C_RATIO = 2 ** C_ADDRESS_SHIFT
  -- below (it fires only if both data sizes are themselves powers of two and
  -- consistent with the address widths).
  constant C_RATIO : positive                                              := G_SLAVE_DATA_BITS / G_MASTER_DATA_BITS;

  -- Extra address LSBs present on the master side, i.e. log2(C_RATIO).
  -- Derived from the address-width difference and cross-checked against
  -- C_RATIO by an assertion below.
  constant C_ADDRESS_SHIFT : natural                                       := G_MASTER_ADDRESS_BITS - G_SLAVE_ADDRESS_BITS;

  -- Fixed all-zero pattern concatenated as the LSBs of m_address_o so that the
  -- downstream burst engine starts at the aligned base of the wide word.
  constant C_ZERO_ADDRESS : std_logic_vector(C_ADDRESS_SHIFT - 1 downto 0) := (others => '0');

  -- Registered copies of the currently in-flight transaction, captured when the
  -- request is accepted in IDLE_ST. They drive the master-side outputs until
  -- the burst completes; s_write/s_read are cleared on each accepted beat by
  -- the handshake block (and re-asserted in WRITING_ST to hold across the
  -- write burst, see comment there).
  signal   s_write      : std_logic;
  signal   s_read       : std_logic;
  signal   s_address    : std_logic_vector(G_SLAVE_ADDRESS_BITS - 1 downto 0);
  signal   s_writedata  : std_logic_vector(G_SLAVE_DATA_BITS - 1 downto 0);
  signal   s_byteenable : std_logic_vector(G_SLAVE_DATA_BITS / 8 - 1 downto 0);
  signal   s_burstcount : std_logic_vector(G_BURST_BITS - 1 downto 0); -- master-side count (= slave count * C_RATIO)

  -- FSM state.
  --   IDLE_ST       : ready to accept a new wide transaction. Also the state in
  --                   which the final beat of a write burst is issued (see
  --                   WRITING_ST comments).
  --   WRITING_ST    : driving narrow write beats 0..C_RATIO-2 of the current
  --                   wide write.
  --   READ_DRAIN_ST : holding off new requests until the currently in-flight
  --                   read burst has been fully reassembled.
  type     state_type is (
    IDLE_ST,
    WRITING_ST,
    READ_DRAIN_ST
  );
  signal   state : state_type                                              := IDLE_ST;

  -- Sub-word indices into the wide slave word.
  --   s_write_pos selects which narrow slice of s_writedata / s_byteenable is
  --   driven onto the master in the current cycle. Advances on each accepted
  --   master beat; wraps to 0 on the first beat of a new burst.
  --
  --   s_read_pos selects which narrow slice of s_readdata_o is written with the
  --   next m_readdata_i. Advances on each master read response; rollover from
  --   C_RATIO-1 to 0 pulses s_readdatavalid_o.
  signal   s_write_pos : integer range 0 to C_RATIO - 1                    := 0;
  signal   s_read_pos  : integer range 0 to C_RATIO - 1                    := 0;

begin

  --------------------------------------------------------------------------
  -- Compile-time consistency checks
  --
  -- These run during elaboration and catch generic combinations that the
  -- design cannot support, with explicit messages where useful.
  --------------------------------------------------------------------------

  -- Reject the degenerate 1:1 ratio. A pass-through is the right tool for
  -- that case; this block assumes at least one extra address LSB.
  assert C_ADDRESS_SHIFT >= 1
    report "avm_decrease: degenerate ratio 1 not supported; use a passthrough"
    severity failure;

  -- Enforce C_RATIO power-of-two (i.e. C_RATIO = 2**C_ADDRESS_SHIFT).
  -- Also implicitly cross-checks the slave/master address-width difference
  -- against the data-size ratio.
  assert C_RATIO = 2 ** C_ADDRESS_SHIFT
    severity failure;

  -- Confirm the integer division above was exact.
  assert G_SLAVE_DATA_BITS = C_RATIO * G_MASTER_DATA_BITS
    severity failure;


  --------------------------------------------------------------------------
  -- Main FSM
  --
  -- Executed every rising clock edge. The body is structured as:
  --   1. Output/handshake defaults (s_readdatavalid_o pulse, s_write/s_read
  --      clear on accepted beat).
  --   2. Read-response reassembly (independent of FSM state; uses s_read_pos
  --      as the destination slice index).
  --   3. State machine (accepts new transactions, issues write beats,
  --      drains overlapping read bursts).
  --   4. Synchronous reset (last; overrides all of the above).
  --
  -- Note that step (1) and step (3) both assign to s_write/s_read. The later
  -- write in (3) wins, which is how WRITING_ST holds m_write_o asserted for
  -- the full burst.
  --------------------------------------------------------------------------
  fsm_proc : process (clk_i)
  begin
    if rising_edge(clk_i) then
      -- Default: s_readdatavalid_o is a single-cycle pulse; deassert each
      -- cycle and let the read-reassembly block re-assert when a wide word
      -- has been completely received.
      s_readdatavalid_o <= '0';

      -- Transaction-accepted handshake (Avalon-MM): when the downstream
      -- slave deasserts m_waitrequest_i, the current beat is accepted, so
      -- the master-side command can be deasserted. WRITING_ST re-asserts
      -- s_write below to keep the burst going.
      if m_waitrequest_i = '0' then
        s_write <= '0';
        s_read  <= '0';
      end if;

      -- Read-response reassembly:
      -- Each narrow read response is written into the s_read_pos slice of
      -- s_readdata_o. When the final (C_RATIO-1) slice is filled, the wide
      -- word is complete: emit s_readdatavalid_o and wrap s_read_pos to 0
      -- ready for the next wide read.
      if m_readdatavalid_i = '1' then
        s_readdata_o(G_MASTER_DATA_BITS * s_read_pos + G_MASTER_DATA_BITS - 1 downto G_MASTER_DATA_BITS * s_read_pos) <= m_readdata_i;

        if s_read_pos = C_RATIO - 1 then
          s_read_pos        <= 0;
          s_readdatavalid_o <= '1';
        else
          s_read_pos <= s_read_pos + 1;
        end if;
      end if;

      case state is

        -- IDLE_ST: ready to latch a new transaction. Also the state in
        -- which the *last* beat of a write burst is issued; see the note
        -- inside WRITING_ST for why that is safe.
        when IDLE_ST =>
          if (s_write_i = '1' or s_read_i = '1') and s_waitrequest_o = '0' then
            -- Latch the new transaction.
            s_write      <= s_write_i;
            s_read       <= s_read_i;
            s_address    <= s_address_i;
            s_writedata  <= s_writedata_i;
            s_byteenable <= s_byteenable_i;

            -- Multiply the slave burstcount by C_RATIO to obtain the
            -- master burstcount. Implemented as a left-shift by
            -- C_ADDRESS_SHIFT = log2(C_RATIO).
            -- CAVEAT: this silently wraps if the slave burstcount is so
            -- large that the result does not fit in G_BURST_BITS bits.
            -- The integrator must size G_BURST_BITS for the master side.
            s_burstcount <= s_burstcount_i sll C_ADDRESS_SHIFT;

            if s_write_i = '1' then
              -- Begin a new write burst at sub-word 0.
              s_write_pos <= 0;
              state       <= WRITING_ST;
            elsif s_read_pos /= 0 or m_readdatavalid_i = '1' then
              -- A previous read burst is still being reassembled
              -- (s_read_pos has advanced past 0, or a response is
              -- arriving on this very edge). Issue this new read
              -- immediately, but block further requests until the
              -- in-flight burst finishes so the two cannot interleave.
              state <= READ_DRAIN_ST;
            end if;
          end if;

        -- WRITING_ST: drive narrow beats of the current wide write.
        -- Beats 0..C_RATIO-2 are issued from this state; the final beat
        -- (index C_RATIO-1) is issued from IDLE_ST after the transition
        -- below. This overlap is intentional (see note inside).
        when WRITING_ST =>
          if m_waitrequest_i = '0' then
            -- Advance to the next sub-word slice of the wide write.
            s_write_pos <= s_write_pos + 1;

            -- Override the default "deassert s_write on accepted beat"
            -- handshake above so that m_write_o remains asserted across
            -- all C_RATIO beats of the burst.
            --
            -- Note: the final beat (s_write_pos = C_RATIO - 1) is
            -- intentionally issued in IDLE_ST. The outputs in that cycle
            -- are driven by the registered s_writedata / s_address /
            -- s_byteenable captured *before* the previous edge, so they
            -- remain correct even if a new transaction is latched on the
            -- same edge. This permits back-to-back bursts with zero idle
            -- cycles between them.
            s_write     <= s_write;

            if s_write_pos = C_RATIO - 2 then
              state <= IDLE_ST;
            end if;
          end if;

        -- READ_DRAIN_ST: a new request was accepted while a previous read
        -- burst was still in flight. Hold s_waitrequest_o = '1' (via the
        -- assignment below the process) until the in-flight burst has
        -- fully reassembled, i.e. s_read_pos has wrapped back to 0. This
        -- avoids issuing two overlapping read bursts whose responses
        -- would race into the same reassembly counter.
        when READ_DRAIN_ST =>
          if s_read_pos = 0 then
            state <= IDLE_ST;
          end if;

      end case;

      -- Synchronous reset (placed last so it overrides everything above).
      -- The registers below are reset explicitly. The remaining registers
      -- (s_address, s_writedata, s_byteenable, s_burstcount) are not
      -- reset because they are only consumed while s_write or s_read is
      -- asserted, and both of those are reset to '0' here.
      if rst_i = '1' then
        s_write           <= '0';
        s_read            <= '0';
        s_read_pos        <= 0;
        s_write_pos       <= 0;
        s_readdatavalid_o <= '0';
        state             <= IDLE_ST;
      end if;
    end if;
  end process fsm_proc;

  --------------------------------------------------------------------------
  -- Combinational master-side outputs
  --
  -- All driven directly from the registered transaction. m_writedata_o and
  -- m_byteenable_o are sliced by s_write_pos so a different narrow slice
  -- of the wide word is presented on each burst beat.
  --------------------------------------------------------------------------

  m_write_o       <= s_write;
  m_read_o        <= s_read;

  -- Concatenate the zero LSBs so the downstream burst starts at the
  -- aligned base of the wide word; the slave's burst engine increments
  -- the address per beat.
  m_address_o     <= s_address & C_ZERO_ADDRESS;

  -- Select the s_write_pos-th narrow slice of the wide write data.
  m_writedata_o   <= s_writedata(G_MASTER_DATA_BITS * s_write_pos + G_MASTER_DATA_BITS - 1 downto G_MASTER_DATA_BITS * s_write_pos);

  -- Same slicing for byte enables (G_MASTER_DATA_BITS / 8 bytes per beat).
  m_byteenable_o  <= s_byteenable(G_MASTER_DATA_BITS / 8 * s_write_pos + G_MASTER_DATA_BITS / 8 - 1 downto G_MASTER_DATA_BITS / 8 * s_write_pos);

  -- Master burstcount is held for the full burst (already the multiplied
  -- value computed in IDLE_ST).
  m_burstcount_o  <= s_burstcount;

  -- s_waitrequest_o policy:
  --   * In IDLE_ST, accept new requests except when an outgoing beat is
  --     currently being held by downstream waitrequest. The expression
  --     (s_write or s_read) is non-zero only when a transaction is
  --     in-flight on the master side; combined with m_waitrequest_i this
  --     stalls the slave port iff the master port is stalled mid-beat.
  --   * In WRITING_ST and READ_DRAIN_ST, unconditionally backpressure
  --     the upstream master.
  s_waitrequest_o <= ((s_write or s_read) and m_waitrequest_i) when state = IDLE_ST else
                     '1';

end architecture synthesis;

