-- ---------------------------------------------------------------------------------------
-- Description:
--   Round-robin arbiter between two Avalon-MM slave-side interfaces (s0, s1) and a single
--   downstream Avalon-MM master-side interface (m). Supports pipelined reads, multi-beat
--   bursts, and an optional "prefer swap" fairness mode (G_PREFER_SWAP).
--
-- Arbitration policy:
--   * Grants are issued one slave at a time and held for the entire burst.
--   * On burst completion, the *other* slave wins next if it has a pending request;
--     otherwise:
--       - G_PREFER_SWAP = false : the current owner keeps the grant (lowest latency for
--                                 back-to-back bursts from the same slave).
--       - G_PREFER_SWAP = true  : the grant is handed to the other side exactly once
--                                 while both sides remain idle, so a long-idle slave does
--                                 not pay first-request arbitration latency.
--
-- Implicit assumptions (DO NOT silently break):
--   1. The downstream master keeps address/burstcount/byteenable/writedata stable for the
--      whole burst (true for all Avalon-MM masters we instantiate today).
--   2. Reset is SYNCHRONOUS and active-high; it is applied at the END of each clocked
--      process so that it overrides any case/elsif assignment in the same cycle.
--   3. G_DATA_BITS is a multiple of 8 (m_byteenable_o is sized as G_DATA_BITS/8).
--   4. The shared 'burstcount' register is safe because at most one of s0/s1 is granted at
--      a time (enforced by grant_proc and by the top assertion).
--   5. No write-response channel exists; write completion is implied by waitrequest
--      handshake.
--   6. 'readdatavalid' for a granted read can arrive in the SAME cycle as the address
--      phase; burstcount_proc handles that explicitly.
--
-- SPDX-License-Identifier: MIT
-- ---------------------------------------------------------------------------------------

library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std.all;

entity avm_arbiter is
  generic (
    G_ADDR_BITS   : positive;
    G_DATA_BITS   : positive := 8;
    -- Burstcount width on all three Avalon-MM interfaces. Must match the downstream
    -- master and the two upstream slaves.
    G_BURST_BITS  : positive := 8;
    G_PREFER_SWAP : boolean  := true
  );
  port (
    clk_i              : in    std_logic;
    rst_i              : in    std_logic;

    -- Slave-side interface 0 (input)
    s0_waitrequest_o   : out   std_logic;
    s0_write_i         : in    std_logic;
    s0_read_i          : in    std_logic;
    s0_address_i       : in    std_logic_vector(G_ADDR_BITS - 1 downto 0);
    s0_writedata_i     : in    std_logic_vector(G_DATA_BITS - 1 downto 0);
    s0_byteenable_i    : in    std_logic_vector(G_DATA_BITS / 8 - 1 downto 0);
    s0_burstcount_i    : in    std_logic_vector(G_BURST_BITS - 1 downto 0);
    s0_readdatavalid_o : out   std_logic;
    s0_readdata_o      : out   std_logic_vector(G_DATA_BITS - 1 downto 0);

    -- Slave-side interface 1 (input)
    s1_waitrequest_o   : out   std_logic;
    s1_write_i         : in    std_logic;
    s1_read_i          : in    std_logic;
    s1_address_i       : in    std_logic_vector(G_ADDR_BITS - 1 downto 0);
    s1_writedata_i     : in    std_logic_vector(G_DATA_BITS - 1 downto 0);
    s1_byteenable_i    : in    std_logic_vector(G_DATA_BITS / 8 - 1 downto 0);
    s1_burstcount_i    : in    std_logic_vector(G_BURST_BITS - 1 downto 0);
    s1_readdatavalid_o : out   std_logic;
    s1_readdata_o      : out   std_logic_vector(G_DATA_BITS - 1 downto 0);

    -- Master-side interface (output)
    m_waitrequest_i    : in    std_logic;
    m_write_o          : out   std_logic;
    m_read_o           : out   std_logic;
    m_address_o        : out   std_logic_vector(G_ADDR_BITS - 1 downto 0);
    m_writedata_o      : out   std_logic_vector(G_DATA_BITS - 1 downto 0);
    m_byteenable_o     : out   std_logic_vector(G_DATA_BITS / 8 - 1 downto 0);
    m_burstcount_o     : out   std_logic_vector(G_BURST_BITS - 1 downto 0);
    m_readdatavalid_i  : in    std_logic;
    m_readdata_i       : in    std_logic_vector(G_DATA_BITS - 1 downto 0)
  );
end entity avm_arbiter;

architecture rtl of avm_arbiter is

  -- ----------------------------------------------------------------------------------
  -- "any request pending" per slave (combinational)
  -- ----------------------------------------------------------------------------------
  signal s0_active_req : std_logic;
  signal s1_active_req : std_logic;

  -- ----------------------------------------------------------------------------------
  -- One-hot grant register. Mutually exclusive: at most one of these is '1' at any
  -- time. Encoded together in 'active_grants' for the grant_proc case statement.
  -- ----------------------------------------------------------------------------------
  signal s0_active_grant : std_logic := '0';
  signal s1_active_grant : std_logic := '0';
  signal active_grants   : std_logic_vector(1 downto 0);

  -- "Last beat of the granted burst with no back-to-back follow-on" (combinational).
  signal s0_last : std_logic;
  signal s1_last : std_logic;

  -- Fairness state. 'last_grant' = id of the slave whose burst we most recently
  -- granted; used as a tie-breaker when both sides request from idle. 'swapped' is
  -- only meaningful when G_PREFER_SWAP=true (see policy comment above).
  signal last_grant : std_logic      := '1';
  signal swapped    : std_logic      := '0';

  -- Remaining beats of the currently granted burst.
  --   * Write address phase loads burstcount_i-1 (because that cycle is also beat 1).
  --   * Read  address phase loads burstcount_i   (responses arrive later), unless
  --     readdatavalid arrives in the SAME cycle, in which case it pre-decrements.
  --   * Each subsequent accepted write beat or readdatavalid decrements by 1.
  signal burstcount : unsigned(G_BURST_BITS - 1 downto 0);

begin

  -- ------------------------------------------------------------------------------------
  -- Top-level sanity checks. These fire only in simulation but document the contract.
  -- ------------------------------------------------------------------------------------
  assert not (s0_active_grant = '1' and s1_active_grant = '1')
    report "avm_arbiter: s0_active_grant and s1_active_grant asserted in the same cycle"
    severity failure;

  assert (G_DATA_BITS mod 8) = 0
    report "avm_arbiter: G_DATA_BITS must be a multiple of 8 (byteenable is G_DATA_BITS/8 wide)"
    severity failure;

  -- ------------------------------------------------------------------------------------
  -- Waitrequest fan-out: the downstream master's waitrequest is forwarded only to the
  -- granted slave; the non-granted slave is permanently back-pressured.
  -- ------------------------------------------------------------------------------------
  s0_waitrequest_o   <= m_waitrequest_i or not s0_active_grant;
  s1_waitrequest_o   <= m_waitrequest_i or not s1_active_grant;

  -- "Any kind of access requested" per slave.
  s0_active_req      <= s0_write_i or s0_read_i;
  s1_active_req      <= s1_write_i or s1_read_i;

  -- ====================================================================================
  -- burstcount_proc
  --
  -- Tracks the remaining beats of the currently granted burst on the master side.
  -- A single shared register is sufficient because grant_proc guarantees mutual
  -- exclusion between s0 and s1.
  -- ====================================================================================
  burstcount_proc : process (clk_i)
    -- Apply the "address-phase accepted" rule for one slave.
    --   write accept while counter is idle  -> load burstcount_i-1 (beat 1 just went)
    --   read  accept                        -> load burstcount_i, or burstcount_i-1
    --                                          if readdatavalid is also asserted this
    --                                          same cycle (bug §1.1 fix).
    -- Returns TRUE if it consumed the cycle, so the caller can short-circuit.

    procedure load_for_slave (
      signal   write_i       : in  std_logic;
      signal   read_i        : in  std_logic;
      signal   waitrequest_o : in  std_logic;
      signal   burstcount_i  : in  std_logic_vector(G_BURST_BITS - 1 downto 0);
      variable handled       : out boolean
    ) is
    begin
      handled := false;
      -- Write address phase: only fires when no burst is currently in flight,
      -- so 'burstcount = 0' is the right guard.
      if write_i = '1' and waitrequest_o = '0' and burstcount = 0 then
        burstcount <= unsigned(burstcount_i) - 1;
        handled    := true;
      elsif read_i = '1' and waitrequest_o = '0' then
        if m_readdatavalid_i = '1' then
          burstcount <= unsigned(burstcount_i) - 1;
        else
          burstcount <= unsigned(burstcount_i);
        end if;
        handled := true;
      end if;
    end procedure load_for_slave;

    variable handled_v : boolean;
  begin
    if rising_edge(clk_i) then
      load_for_slave(s0_write_i, s0_read_i, s0_waitrequest_o,
                     s0_burstcount_i, handled_v);
      if not handled_v then
        load_for_slave(s1_write_i, s1_read_i, s1_waitrequest_o,
                       s1_burstcount_i, handled_v);
      end if;

      -- No address-phase event this cycle: decrement for any accepted beat.
      if not handled_v then
        if (s0_write_i and not s0_waitrequest_o) = '1' or
           s0_readdatavalid_o = '1' or
           (s1_write_i and not s1_waitrequest_o) = '1' or
           s1_readdatavalid_o = '1' then
          burstcount <= unsigned(burstcount) - 1;
        end if;
      end if;

      -- Synchronous reset (applied LAST so it overrides the assignments above).
      if rst_i = '1' then
        burstcount <= (others => '0');
      end if;
    end if;
  end process burstcount_proc;

  -- ====================================================================================
  -- last_proc
  --
  -- Combinational. Asserted on the last beat of the granted burst when the same slave
  -- is NOT already presenting a follow-on transaction that the master can accept.
  -- grant_proc uses this edge to release the grant.
  --
  -- The "burstcount = 0" branch catches single-beat writes (burstcount_proc loaded
  -- burstcount_i - 1 = 0 on the address phase) - that's why the inner condition has
  -- the apparently-odd `s0_burstcount_i = 1 and s0_write_i='1'` term.
  -- ====================================================================================
  last_proc : process (all)
    -- Per-slave decision factored into a procedure to kill the S0/S1 duplication.

    procedure last_for_slave (
      signal   active_grant : in  std_logic;
      signal   active_req   : in  std_logic;
      signal   write_i      : in  std_logic;
      signal   readdv_o     : in  std_logic;
      signal   waitreq_o    : in  std_logic;
      signal   burstcount_i : in  std_logic_vector(G_BURST_BITS - 1 downto 0);
      signal   last_o       : out std_logic
    ) is
    begin
      last_o <= '0';
      if active_grant = '1' then
        -- Outer guard: we are on (or past) the last beat of the burst.
        if burstcount = 0
           or (burstcount = 1 and readdv_o = '1')
           or (burstcount = 1 and write_i  = '1') then
          -- Inner guard: nothing keeps the grant alive this cycle.
          --   * no follow-on request, OR
          --   * the final read beat just arrived but no new address phase was
          --     accepted, OR
          --   * the final write beat was just accepted, OR
          --   * a single-beat write address phase was just accepted (covered
          --     separately because burstcount was loaded to 0, not 1).
          if active_req = '0'
             or (burstcount             = 1 and readdv_o = '1' and waitreq_o = '1')
             or (burstcount             = 1 and write_i  = '1' and waitreq_o = '0')
             or (unsigned(burstcount_i) = 1 and write_i  = '1' and waitreq_o = '0') then
            last_o <= '1';
          end if;
        end if;
      end if;
    end procedure last_for_slave;

  begin
    last_for_slave(s0_active_grant, s0_active_req, s0_write_i,
                   s0_readdatavalid_o, s0_waitrequest_o, s0_burstcount_i, s0_last);
    last_for_slave(s1_active_grant, s1_active_req, s1_write_i,
                   s1_readdatavalid_o, s1_waitrequest_o, s1_burstcount_i, s1_last);
  end process last_proc;

  active_grants      <= s1_active_grant & s0_active_grant;

  -- ====================================================================================
  -- grant_proc
  --
  -- Owns the one-hot grant register and the fairness state ('last_grant', 'swapped').
  -- The S0-currently-granted and S1-currently-granted arms are mirror images of each
  -- other, so they share one procedure: arbitrate_end_of_burst, parameterised by
  -- "self" and "other" identifiers.
  -- ====================================================================================
  grant_proc : process (clk_i)
    -- End-of-burst arbitration for whichever slave is currently granted.
    --
    -- self_*  : the slave that just finished its burst (currently granted)
    -- other_* : the slave that did not have the grant
    -- self_last_id : value that 'last_grant' takes when 'self' is the owner
    --                ('0' for s0, '1' for s1)

    procedure arbitrate_end_of_burst (
      signal   self_active_req    : in  std_logic;
      signal   other_active_req   : in  std_logic;
      signal   self_active_grant  : out std_logic;
      signal   other_active_grant : out std_logic;
      constant self_last_id       : in  std_logic
    ) is
      constant C_OTHER_LAST_ID : std_logic := not self_last_id;
    begin
      -- Try to re-grant self first; otherwise hand over to other; otherwise see
      -- the "both idle" policy below.
      if self_active_req = '1' and
         not (last_grant = self_last_id and other_active_req = '1') then
        self_active_grant <= '1';
        last_grant        <= self_last_id;
      elsif other_active_req = '1' and
            not (last_grant = C_OTHER_LAST_ID and self_active_req = '1') then
        other_active_grant <= '1';
        self_active_grant  <= '0';
        last_grant         <= C_OTHER_LAST_ID;
      end if;

      -- Both slaves idle: apply the configured fairness policy.
      if G_PREFER_SWAP then
        -- Hand the grant to the OTHER side exactly once between real requests
        -- (tracked by 'swapped'); after that, stick with self so we don't churn.
        if self_active_req = '0' and other_active_req = '0' then
          if swapped = '0' then
            other_active_grant <= '1';
            self_active_grant  <= '0';
            last_grant         <= C_OTHER_LAST_ID;
            swapped            <= '1';
          else
            self_active_grant <= '1';
            last_grant        <= self_last_id;
          end if;
        end if;
      else
        -- No swap policy: keep the existing grant on self so a back-to-back burst
        -- from the same slave incurs zero arbitration latency.
        if self_active_req = '0' and other_active_req = '0' then
          self_active_grant <= '1';
          last_grant        <= self_last_id;
        end if;
      end if;
    end procedure arbitrate_end_of_burst;

  begin
    if rising_edge(clk_i) then
      -- On the last beat of a burst, release the grant. arbitrate_end_of_burst may
      -- immediately re-assert it below.
      if s0_last = '1' then
        s0_active_grant <= '0';
      end if;
      if s1_last = '1' then
        s1_active_grant <= '0';
      end if;

      case active_grants is

        when "00" =>
          -- Idle: grant whichever side is requesting, with last_grant as tie-breaker.
          if s0_active_req = '1' and (last_grant = '1' or s1_active_req = '0') then
            s0_active_grant <= '1';
            last_grant      <= '0';
          end if;
          if s1_active_req = '1' and (last_grant = '0' or s0_active_req = '0') then
            s1_active_grant <= '1';
            last_grant      <= '1';
          end if;

        when "01" =>
          -- S0 currently granted.
          if s0_last = '1' then
            arbitrate_end_of_burst (
                                    self_active_req    => s0_active_req,
                                    other_active_req   => s1_active_req,
                                    self_active_grant  => s0_active_grant,
                                    other_active_grant => s1_active_grant,
                                    self_last_id       => '0'
                                  );
          end if;

        when "10" =>
          -- S1 currently granted.
          if s1_last = '1' then
            arbitrate_end_of_burst (
                                    self_active_req    => s1_active_req,
                                    other_active_req   => s0_active_req,
                                    self_active_grant  => s1_active_grant,
                                    other_active_grant => s0_active_grant,
                                    self_last_id       => '1'
                                  );
          end if;

        when others =>
          -- Unreachable by construction (the top assert guards it). Be defensive
          -- in hardware anyway: drop both grants so we don't lock up.
          report "avm_arbiter: S0 and S1 both granted (active_grants = ""11"")"
            severity failure;
          s0_active_grant <= '0';
          s1_active_grant <= '0';

      end case;

      -- Any real activity invalidates the one-shot "swap because idle" decision.
      if s1_active_req = '1' or s0_active_req = '1' then
        swapped <= '0';
      end if;

      -- Synchronous reset, applied LAST so it overrides the case above.
      if rst_i = '1' then
        s0_active_grant <= '0';
        s1_active_grant <= '0';
        last_grant      <= '1';   -- => S0 wins the first arbitration after reset
        swapped         <= '0';
      end if;
    end if;
  end process grant_proc;

  -- ====================================================================================
  -- Master-side output mux (combinational).
  --
  -- Selected by the actual grant signals (NOT by 'last_grant'), so the master is
  -- never driven from a slave that does not currently own the bus. m_write_o /
  -- m_read_o are additionally ANDed with the grant so they go to '0' when nobody
  -- is granted (e.g. the cycle after reset).
  -- ====================================================================================
  m_write_o          <= (s1_write_i and s1_active_grant) when s1_active_grant = '1' else
                        (s0_write_i and s0_active_grant);
  m_read_o           <= (s1_read_i  and s1_active_grant) when s1_active_grant = '1' else
                        (s0_read_i  and s0_active_grant);
  m_address_o        <= s1_address_i when s1_active_grant = '1' else
                        s0_address_i;
  m_writedata_o      <= s1_writedata_i when s1_active_grant = '1' else
                        s0_writedata_i;
  m_byteenable_o     <= s1_byteenable_i when s1_active_grant = '1' else
                        s0_byteenable_i;
  m_burstcount_o     <= s1_burstcount_i when s1_active_grant = '1' else
                        s0_burstcount_i;

  -- ====================================================================================
  -- Read-data fan-out (combinational).
  --
  -- 'readdata' is broadcast to both slaves (they will ignore it when their
  -- 'readdatavalid' is low). 'readdatavalid' is gated by the corresponding grant so
  -- only the slave that issued the burst observes the responses.
  -- ====================================================================================
  s0_readdata_o      <= m_readdata_i;
  s0_readdatavalid_o <= m_readdatavalid_i when s0_active_grant = '1' else
                        '0';

  s1_readdata_o      <= m_readdata_i;
  s1_readdatavalid_o <= m_readdatavalid_i when s1_active_grant = '1' else
                        '0';

end architecture rtl;

