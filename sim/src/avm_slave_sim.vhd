-- ---------------------------------------------------------------------------------------
-- Description: This simulates an Avalon Slave.
-- ---------------------------------------------------------------------------------------

library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std.all;

library work;
  use work.avm_pkg.all;

entity avm_slave_sim is
  generic (
    G_NAME  : string  := "";
    G_DEBUG : boolean := false
  );
  port (
    clk_i : in    std_logic;
    rst_i : in    std_logic;
    s_avm : view  avm_slave_view
  );
end entity avm_slave_sim;

architecture simulation of avm_slave_sim is

  constant C_ADDR_SIZE : positive := s_avm.address'length;
  constant C_DATA_SIZE : positive := s_avm.writedata'length;

  -- This defines a type containing an array of words
  type   mem_type is array (0 to 2 ** C_ADDR_SIZE - 1) of std_logic_vector(C_DATA_SIZE - 1 downto 0);

  signal write_burstcount : natural range 0 to 255;
  signal write_address    : std_logic_vector(C_ADDR_SIZE - 1 downto 0);

  signal read_burstcount : natural range 0 to 255;
  signal read_address    : std_logic_vector(C_ADDR_SIZE - 1 downto 0);

  signal mem_write_burstcount : natural range 0 to 255;
  signal mem_read_burstcount  : natural range 0 to 255;
  signal mem_write_address    : std_logic_vector(C_ADDR_SIZE - 1 downto 0);
  signal mem_read_address     : std_logic_vector(C_ADDR_SIZE - 1 downto 0);

begin

  mem_write_address    <= s_avm.address when write_burstcount = 0 else
                          write_address;
  mem_read_address     <= s_avm.address when read_burstcount = 0 else
                          read_address;
  mem_write_burstcount <= to_integer(unsigned(s_avm.burstcount)) when write_burstcount = 0 else
                          write_burstcount;
  mem_read_burstcount  <= to_integer(unsigned(s_avm.burstcount)) when read_burstcount = 0 else
                          read_burstcount;

  s_avm.waitrequest    <= '0' when read_burstcount = 0 else
                          '1';

  mem_proc : process (clk_i)
    variable mem_v : mem_type := (others => (others => '0'));
    variable idx_v : natural range 0 to 2 ** C_ADDR_SIZE - 1;
  begin
    if rising_edge(clk_i) then
      s_avm.readdatavalid <= '0';

      if s_avm.write = '1' and s_avm.waitrequest = '0' then
        write_address    <= std_logic_vector(unsigned(mem_write_address) + 1);
        write_burstcount <= mem_write_burstcount - 1;

        if G_DEBUG then
          report "Avalon SLAVE " & G_NAME &
                 ": Writing 0x" & to_hstring(s_avm.writedata) &
                 " to 0x" & to_hstring(mem_write_address) &
                 " with burstcount " & to_string(mem_write_burstcount) &
                 " and byteenable 0x" & to_hstring(s_avm.byteenable);
        end if;
        idx_v := to_integer(unsigned(mem_write_address));

        for b in 0 to C_DATA_SIZE / 8 - 1 loop
          if s_avm.byteenable(b) = '1' then
            mem_v(idx_v)(8 * b + 7 downto 8 * b) := s_avm.writedata(8 * b + 7 downto 8 * b);
          end if;
        end loop;

      end if;

      if (s_avm.read = '1' and s_avm.waitrequest = '0') or read_burstcount > 0 then
        read_address        <= std_logic_vector(unsigned(mem_read_address) + 1);
        read_burstcount     <= mem_read_burstcount - 1;

        idx_v               := to_integer(unsigned(mem_read_address));
        s_avm.readdatavalid <= '1';
        s_avm.readdata      <= mem_v(idx_v);

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

