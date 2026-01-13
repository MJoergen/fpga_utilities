-- ---------------------------------------------------------------------------------------
-- Description: This simulates an Avalon Slave.
-- ---------------------------------------------------------------------------------------

library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std.all;

entity avm_slave_sim is
  generic (
    G_NAME      : string  := "";
    G_DEBUG     : boolean := false;
    G_ADDR_SIZE : integer; -- Number of bits
    G_DATA_SIZE : integer  -- Number of bits
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
    s_burstcount_i    : in    std_logic_vector(7 downto 0);
    s_readdatavalid_o : out   std_logic;
    s_readdata_o      : out   std_logic_vector(G_DATA_SIZE - 1 downto 0)
  );
end entity avm_slave_sim;

architecture simulation of avm_slave_sim is

  -- This defines a type containing an array of words
  type   mem_type is array (0 to 2 ** G_ADDR_SIZE - 1) of std_logic_vector(G_DATA_SIZE - 1 downto 0);

  signal write_burstcount : natural range 0 to 255;
  signal write_address    : std_logic_vector(G_ADDR_SIZE - 1 downto 0);

  signal read_burstcount : natural range 0 to 255;
  signal read_address    : std_logic_vector(G_ADDR_SIZE - 1 downto 0);

  signal mem_write_burstcount : natural range 0 to 255;
  signal mem_read_burstcount  : natural range 0 to 255;
  signal mem_write_address    : std_logic_vector(G_ADDR_SIZE - 1 downto 0);
  signal mem_read_address     : std_logic_vector(G_ADDR_SIZE - 1 downto 0);

begin

  mem_write_address    <= s_address_i when write_burstcount = 0 else
                          write_address;
  mem_read_address     <= s_address_i when read_burstcount = 0 else
                          read_address;
  mem_write_burstcount <= to_integer(unsigned(s_burstcount_i)) when write_burstcount = 0 else
                          write_burstcount;
  mem_read_burstcount  <= to_integer(unsigned(s_burstcount_i)) when read_burstcount = 0 else
                          read_burstcount;

  s_waitrequest_o      <= '0' when read_burstcount = 0 else
                          '1';

  mem_proc : process (clk_i)
    variable mem_v : mem_type := (others => (others => '0'));
    variable idx_v : natural range 0 to 2 ** G_ADDR_SIZE - 1;
  begin
    if rising_edge(clk_i) then
      s_readdatavalid_o <= '0';

      if s_write_i = '1' and s_waitrequest_o = '0' then
        write_address    <= std_logic_vector(unsigned(mem_write_address) + 1);
        write_burstcount <= mem_write_burstcount - 1;

        if G_DEBUG then
          report "Avalon SLAVE " & G_NAME &
                 ": Writing 0x" & to_hstring(s_writedata_i) &
                 " to 0x" & to_hstring(mem_write_address) &
                 " with burstcount " & to_string(mem_write_burstcount) &
                 " and byteenable 0x" & to_hstring(s_byteenable_i);
        end if;
        idx_v := to_integer(unsigned(mem_write_address));
        for b in 0 to G_DATA_SIZE / 8 - 1 loop
          if s_byteenable_i(b) = '1' then
            mem_v(idx_v)(8 * b + 7 downto 8 * b) := s_writedata_i(8 * b + 7 downto 8 * b);
          end if;
        end loop;
      end if;

      if (s_read_i = '1' and s_waitrequest_o = '0') or read_burstcount > 0 then
        read_address      <= std_logic_vector(unsigned(mem_read_address) + 1);
        read_burstcount   <= mem_read_burstcount - 1;

        idx_v             := to_integer(unsigned(mem_read_address));
        s_readdatavalid_o <= '1';
        s_readdata_o      <= mem_v(idx_v);

        if G_DEBUG then
          report "Avalon SLAVE " & G_NAME &
                 ": Reading 0x" & to_hstring(mem_v(idx_v)) &
                 " from 0x" & to_hstring(mem_read_address) &
                 " with burstcount " & to_string(mem_read_burstcount);
        end if;
      end if;

      if rst_i = '1' then
        write_burstcount <= 0;
        read_burstcount  <= 0;
      end if;
    end if;
  end process mem_proc;

end architecture simulation;

