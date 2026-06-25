-- ---------------------------------------------------------------------------------------
-- Description:
--   Simulation-only Avalon-MM slave memory model.
--
--   The model implements a simple word-addressed memory with byte-enable support.
--   Each address corresponds to one G_DATA_BITS-bit word. Burst transactions are
--   supported by incrementing the address by one word for each accepted beat.
--
-- Behavior:
--   * Read responses have fixed 1-cycle latency and produce one data beat per clock.
--   * During read bursts, the slave returns remaining beats autonomously.
--   * During write bursts, the master must continuously supply write beats.
--
-- Important assumptions / limitations:
--   * Address input is treated as a word address (not byte address).
--   * G_DATA_BITS must be a multiple of 8 (byte-enable granularity).
--   * Burstcount must be nonzero when a command is accepted.
--   * Simultaneous read and write commands are not supported.
--   * During a write burst:
--       - Only write continuation beats are accepted
--       - Reads or idle cycles are treated as protocol violations
--   * During a read burst:
--       - waitrequest is asserted and no new commands are accepted
--   * The model is intentionally strict and asserts on protocol violations.
--   * Intended for simulation only (not synthesizable).
--   * Memory contents are initialized to zero at elaboration and are not reset.
--
-- ---------------------------------------------------------------------------------------

library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std.all;

entity avm_slave_sim is
  generic (
    G_BURST_BITS : positive := 8;
    G_NAME        : string   := "";
    G_DEBUG       : boolean  := false;
    G_ADDR_BITS   : positive; -- Address width in bits (memory depth = 2**G_ADDR_BITS words)
    G_DATA_BITS   : positive  -- Data width in bits (must be multiple of 8)
  );
  port (
    clk_i             : in    std_logic;
    rst_i             : in    std_logic;

    -- Avalon-MM slave interface
    s_waitrequest_o   : out   std_logic;
    s_write_i         : in    std_logic;
    s_read_i          : in    std_logic;
    s_address_i       : in    std_logic_vector(G_ADDR_BITS - 1 downto 0);
    s_writedata_i     : in    std_logic_vector(G_DATA_BITS - 1 downto 0);
    s_byteenable_i    : in    std_logic_vector(G_DATA_BITS / 8 - 1 downto 0);
    s_burstcount_i    : in    std_logic_vector(G_BURST_BITS - 1 downto 0);

    s_readdatavalid_o : out   std_logic;
    s_readdata_o      : out   std_logic_vector(G_DATA_BITS - 1 downto 0)
  );
end entity avm_slave_sim;


architecture simulation of avm_slave_sim is

  -- Number of byte lanes per word (must be integer)
  constant C_BYTES_PER_WORD : natural                              := G_DATA_BITS / 8;

  -- Number of addressable words in memory
  constant C_MEM_DEPTH : natural                                   := 2 ** G_ADDR_BITS;

  -- Word-addressed memory array
  type     mem_type is array (0 to C_MEM_DEPTH - 1) of
                     std_logic_vector(G_DATA_BITS - 1 downto 0);

  -- Burst activity flags (remaining beats > 0)
  signal   read_active_s  : std_logic;
  signal   write_active_s : std_logic;

  -- Internal burst state (remaining beats and current address)
  signal   write_burstcount : unsigned(G_BURST_BITS - 1 downto 0) := (others => '0');
  signal   write_address    : unsigned(G_ADDR_BITS - 1 downto 0)   := (others => '0');

  signal   read_burstcount : unsigned(G_BURST_BITS - 1 downto 0)  := (others => '0');
  signal   read_address    : unsigned(G_ADDR_BITS - 1 downto 0)    := (others => '0');

  -- Muxed address/burstcount:
  --   * When no burst is active: use bus inputs
  --   * During burst: use internally updated state
  signal   mem_write_burstcount : unsigned(G_BURST_BITS - 1 downto 0);
  signal   mem_read_burstcount  : unsigned(G_BURST_BITS - 1 downto 0);
  signal   mem_write_address    : unsigned(G_ADDR_BITS - 1 downto 0);
  signal   mem_read_address     : unsigned(G_ADDR_BITS - 1 downto 0);

begin

  -- Enforce valid byte-enable configuration
  assert G_DATA_BITS mod 8 = 0
    report "G_DATA_BITS must be a multiple of 8"
    severity failure;


  -- Burst is active when remaining beat count is nonzero
  read_active_s        <= '1' when read_burstcount  /= 0 else
                          '0';
  write_active_s       <= '1' when write_burstcount /= 0 else
                          '0';


  -- Select initial or continuation state
  mem_write_address    <= unsigned(s_address_i) when write_active_s = '0' else
                          write_address;
  mem_read_address     <= unsigned(s_address_i) when read_active_s  = '0' else
                          read_address;
  mem_write_burstcount <= unsigned(s_burstcount_i) when write_active_s = '0' else
                          write_burstcount;
  mem_read_burstcount  <= unsigned(s_burstcount_i) when read_active_s  = '0' else
                          read_burstcount;


  -- waitrequest behavior:
  --   * Asserted during read burst response (no command acceptance)
  s_waitrequest_o      <= '1' when read_active_s = '1' else
                          '0';


  mem_proc : process (clk_i)
    -- Simulation memory storage (persistent across cycles)
    variable mem_v : mem_type := (others => (others => '0'));

    -- Address index into memory
    variable idx_v : natural range 0 to C_MEM_DEPTH - 1;
  begin
    if rising_edge(clk_i) then
      -- Default: no read data valid unless explicitly generated below
      s_readdatavalid_o <= '0';

      ------------------------------------------------------------------------
      -- Protocol checks: write burst integrity
      ------------------------------------------------------------------------
      if write_active_s = '1' then
        -- Enforce continuous write burst (no gaps)
        assert s_write_i = '1'
          report "Avalon SLAVE " & G_NAME &
                 ": write burst was interrupted before all beats were accepted"
          severity failure;

        -- Disallow read during ongoing write burst
        assert s_read_i = '0'
          report "Avalon SLAVE " & G_NAME &
                 ": read command issued during unfinished write burst"
          severity failure;
      end if;


      ------------------------------------------------------------------------
      -- Protocol checks: read burst behavior
      ------------------------------------------------------------------------
      if read_active_s = '1' then
        -- No command should be issued while read response is in progress
        assert s_read_i = '0' and s_write_i = '0'
          report "Avalon SLAVE " & G_NAME &
                 ": command issued while slave is returning read burst data"
          severity warning;
      end if;


      ------------------------------------------------------------------------
      -- Protocol checks: unsupported simultaneous commands
      ------------------------------------------------------------------------
      assert not (s_read_i = '1' and s_write_i = '1' and s_waitrequest_o = '0')
        report "Avalon SLAVE " & G_NAME &
               ": simultaneous read and write are not supported"
        severity failure;


      ------------------------------------------------------------------------
      -- Write handling (accept new or continuation write beat)
      ------------------------------------------------------------------------
      if s_write_i = '1' and s_waitrequest_o = '0' then
        -- Validate burstcount
        if unsigned(s_burstcount_i) = 0 then
          report "Avalon SLAVE " & G_NAME &
                 ": write with burstcount 0 is invalid"
            severity failure;
        end if;

        -- Advance address and remaining burst count
        write_address    <= mem_write_address + 1;
        write_burstcount <= mem_write_burstcount - 1;

        if G_DEBUG then
          report "Avalon SLAVE " & G_NAME &
                 ": Writing 0x" & to_hstring(s_writedata_i) &
                 " to 0x" & to_hstring(mem_write_address) &
                 " with remaining burstcount " & to_hstring(mem_write_burstcount) &
                 " and byteenable 0x" & to_hstring(s_byteenable_i);
        end if;

        idx_v := to_integer(mem_write_address);

        -- Byte lane mapping:
        --   byte lane b -> bits (8*b+7 downto 8*b)
        --   (standard little-endian Avalon-MM convention)
        for b in 0 to C_BYTES_PER_WORD - 1 loop
          if s_byteenable_i(b) = '1' then
            mem_v(idx_v)(8 * b + 7 downto 8 * b) := s_writedata_i(8 * b + 7 downto 8 * b);
          end if;
        end loop;
      end if;


      ------------------------------------------------------------------------
      -- Read handling (new command or continuation of burst)
      ------------------------------------------------------------------------
      if (s_read_i = '1' and s_waitrequest_o = '0') or read_active_s = '1' then
        -- Validate burstcount on new command
        if unsigned(s_burstcount_i) = 0 then
          report "Avalon SLAVE " & G_NAME &
                 ": read with burstcount 0 is invalid"
            severity failure;
        end if;

        -- Advance address and remaining burst count
        read_address      <= mem_read_address + 1;
        read_burstcount   <= mem_read_burstcount - 1;

        idx_v             := to_integer(mem_read_address);

        -- Return read data
        s_readdatavalid_o <= '1';
        s_readdata_o      <= mem_v(idx_v);

        if G_DEBUG then
          report "Avalon SLAVE " & G_NAME &
                 ": Reading 0x" & to_hstring(mem_v(idx_v)) &
                 " from 0x" & to_hstring(mem_read_address) &
                 " with remaining burstcount " & to_hstring(mem_read_burstcount);
        end if;
      end if;


      ------------------------------------------------------------------------
      -- Reset behavior
      --   * Clears burst state and read outputs
      --   * Does NOT clear memory contents
      ------------------------------------------------------------------------
      if rst_i = '1' then
        s_readdatavalid_o <= '0';
        write_burstcount  <= (others => '0');
        read_burstcount   <= (others => '0');
      end if;
    end if;
  end process mem_proc;

end architecture simulation;

