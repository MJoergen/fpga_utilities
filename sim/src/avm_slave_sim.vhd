-- ---------------------------------------------------------------------------------------
-- Description:
--   Simple simulation-only Avalon-MM slave memory model.
--
--   The model stores one G_DATA_SIZE-bit word at each address and supports byte-enable
--   writes. Burst reads and writes are supported by incrementing the word address by one
--   for each accepted beat.
--
-- Important assumptions / limitations:
--   * Address input is treated as a word address, not a byte address.
--   * G_DATA_SIZE must be a multiple of 8.
--   * Burstcount must be nonzero when a read or write command is accepted.
--   * Read bursts are returned with one data beat per clock.
--   * While a read burst is being returned, waitrequest is asserted and no new command is
--     accepted.
--   * The model is intended for simulation only and is not synthesizable as written.
--   * Memory contents are initialized to zero at elaboration and are not cleared by reset.
-- ---------------------------------------------------------------------------------------

library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std.all;

entity avm_slave_sim is
  generic (
    G_BURST_WIDTH : positive := 8;
    G_NAME        : string   := "";
    G_DEBUG       : boolean  := false;
    G_ADDR_SIZE   : positive; -- Address width in bits. Memory depth is 2**G_ADDR_SIZE words.
    G_DATA_SIZE   : positive  -- Data width in bits. Must be a multiple of 8.
  );
  port (
    clk_i             : in    std_logic;
    rst_i             : in    std_logic;
    s_waitrequest_o   : out   std_logic;
    s_write_i         : in    std_logic;
    s_read_i          : in    std_logic;
    s_address_i       : in    std_logic_vector(G_ADDR_SIZE - 1 downto 0);
    s_writedata_i     : in    std_logic_vector(G_DATA_SIZE - 1 downto 0);
    s_byteenable_i    : in    std_logic_vector(G_DATA_SIZE / 8 - 1 downto 0);
    s_burstcount_i    : in    std_logic_vector(G_BURST_WIDTH - 1 downto 0);
    s_readdatavalid_o : out   std_logic;
    s_readdata_o      : out   std_logic_vector(G_DATA_SIZE - 1 downto 0)
  );
end entity avm_slave_sim;

architecture simulation of avm_slave_sim is

  constant C_BYTES_PER_WORD : natural                              := G_DATA_SIZE / 8;
  constant C_MEM_DEPTH      : natural                              := 2 ** G_ADDR_SIZE;

  -- This defines a type containing an array of words
  type     mem_type is array (0 to C_MEM_DEPTH - 1) of std_logic_vector(G_DATA_SIZE - 1 downto 0);

  signal   read_active_s  : std_logic;
  signal   write_active_s : std_logic;

  signal   write_burstcount : unsigned(G_BURST_WIDTH - 1 downto 0) := (others => '0');
  signal   write_address    : unsigned(G_ADDR_SIZE - 1 downto 0)   := (others => '0');

  signal   read_burstcount : unsigned(G_BURST_WIDTH - 1 downto 0)  := (others => '0');
  signal   read_address    : unsigned(G_ADDR_SIZE - 1 downto 0)    := (others => '0');

  signal   mem_write_burstcount : unsigned(G_BURST_WIDTH - 1 downto 0);
  signal   mem_read_burstcount  : unsigned(G_BURST_WIDTH - 1 downto 0);
  signal   mem_write_address    : unsigned(G_ADDR_SIZE - 1 downto 0);
  signal   mem_read_address     : unsigned(G_ADDR_SIZE - 1 downto 0);

begin

  assert G_DATA_SIZE mod 8 = 0
    report "G_DATA_SIZE must be a multiple of 8"
    severity failure;


  read_active_s        <= '1' when read_burstcount  /= 0 else
                          '0';
  write_active_s       <= '1' when write_burstcount /= 0 else
                          '0';


  mem_write_address    <= unsigned(s_address_i) when write_active_s = '0' else
                          write_address;
  mem_read_address     <= unsigned(s_address_i) when read_active_s = '0' else
                          read_address;
  mem_write_burstcount <= unsigned(s_burstcount_i) when write_active_s = '0' else
                          write_burstcount;
  mem_read_burstcount  <= unsigned(s_burstcount_i) when read_active_s = '0' else
                          read_burstcount;

  s_waitrequest_o      <= '1' when read_active_s = '1' else
                          '1' when write_active_s = '1' and s_write_i = '0' else
                          '1' when write_active_s = '1' and s_read_i = '1' else
                          '0';


  mem_proc : process (clk_i)
    variable mem_v : mem_type := (others => (others => '0'));
    variable idx_v : natural range 0 to 2 ** G_ADDR_SIZE - 1;
  begin
    if rising_edge(clk_i) then
      s_readdatavalid_o <= '0';

      if write_active_s = '1' then
        assert s_write_i = '1'
          report "Avalon SLAVE " & G_NAME &
                 ": write burst was interrupted before all beats were accepted"
          severity failure;

        assert s_read_i = '0'
          report "Avalon SLAVE " & G_NAME &
                 ": read command issued during unfinished write burst"
          severity failure;
      end if;


      if read_active_s = '1' then
        assert s_read_i = '0' and s_write_i = '0'
          report "Avalon SLAVE " & G_NAME &
                 ": command issued while slave is returning read burst data"
          severity warning;
      end if;


      assert not (s_read_i = '1' and s_write_i = '1' and s_waitrequest_o = '0')
        report "Avalon SLAVE " & G_NAME & ": simultaneous read and write are not supported"
        severity failure;

      if s_write_i = '1' and s_waitrequest_o = '0' then
        if unsigned(s_burstcount_i) = 0 then
          report "Avalon SLAVE " & G_NAME & ": write with burstcount 0 is invalid"
            severity failure;
        end if;

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

        -- Byte lane b maps to data bits 8*b+7 downto 8*b.
        -- This follows the usual little-endian Avalon byte-enable convention.
        for b in 0 to C_BYTES_PER_WORD - 1 loop
          if s_byteenable_i(b) = '1' then
            mem_v(idx_v)(8 * b + 7 downto 8 * b) := s_writedata_i(8 * b + 7 downto 8 * b);
          end if;
        end loop;
      end if;

      if (s_read_i = '1' and s_waitrequest_o = '0') or read_active_s = '1' then
        if unsigned(s_burstcount_i) = 0 then
          report "Avalon SLAVE " & G_NAME & ": read with burstcount 0 is invalid"
            severity failure;
        end if;

        read_address      <= mem_read_address + 1;
        read_burstcount   <= mem_read_burstcount - 1;

        idx_v             := to_integer(mem_read_address);
        s_readdatavalid_o <= '1';
        s_readdata_o      <= mem_v(idx_v);

        if G_DEBUG then
          report "Avalon SLAVE " & G_NAME &
                 ": Reading 0x" & to_hstring(mem_v(idx_v)) &
                 " from 0x" & to_hstring(mem_read_address) &
                 " with burstcount " & to_hstring(mem_read_burstcount);
        end if;
      end if;

      if rst_i = '1' then
        s_readdatavalid_o <= '0';
        write_burstcount  <= (others => '0');
        read_burstcount   <= (others => '0');
      end if;
    end if;
  end process mem_proc;

end architecture simulation;

