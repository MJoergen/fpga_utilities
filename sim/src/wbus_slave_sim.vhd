-- ---------------------------------------------------------------------------------------
-- Description: This simulates a Wishbone Slave.
-- ---------------------------------------------------------------------------------------

library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std_unsigned.all;

library work;
  use work.wbus_pkg.all;

entity wbus_slave_sim is
  generic (
    G_NAME  : string    := "";
    G_FIRST : std_logic := 'U';
    G_DEBUG : boolean   := false
  );
  port (
    clk_i  : in    std_logic;
    rst_i  : in    std_logic;
    s_wbus : view wbus_slave_view
  );
end entity wbus_slave_sim;

architecture simulation of wbus_slave_sim is

  type   ram_type is array (natural range <>) of std_logic_vector(s_wbus.wrdat'range);
  signal ram : ram_type(0 to 2 ** s_wbus.addr'length - 1);

  signal req_active : std_logic := '0';

begin

  s_wbus.stall <= req_active;

  --------------------------------
  -- Generate RAM
  --------------------------------

  ram_proc : process (clk_i)
  begin
    if rising_edge(clk_i) then
      s_wbus.ack <= '0';
      if s_wbus.cyc = '1' and s_wbus.stall = '0' and s_wbus.stb = '1' and s_wbus.we = '1' then
        ram(to_integer(s_wbus.addr)) <= s_wbus.wrdat;
        s_wbus.ack                   <= '1';
        if G_DEBUG then
          report "WBUS SLAVE " & G_NAME &
                 ": Write " & to_hstring(s_wbus.wrdat) &
                 " to address " & to_hstring(s_wbus.addr);
        end if;
      end if;
      if s_wbus.cyc = '1' and s_wbus.stall = '0' and s_wbus.stb = '1' and s_wbus.we = '0' then
        s_wbus.rddat <= ram(to_integer(s_wbus.addr));
        s_wbus.ack   <= '1';
        if G_DEBUG then
          report "WBUS SLAVE " & G_NAME &
                 ": Read  " & to_hstring(ram(to_integer(s_wbus.addr))) &
                 " from address " & to_hstring(s_wbus.addr);
        end if;
      end if;

      if rst_i = '1' or s_wbus.cyc = '0' then
        s_wbus.ack <= '0';
      end if;
    end if;
  end process ram_proc;


  --------------------------------
  -- Monitor requests
  --------------------------------

  assert_proc : process (clk_i)
  begin
    if rising_edge(clk_i) then
      if s_wbus.cyc = '1' and s_wbus.stall = '0' and s_wbus.stb = '1' then
        assert req_active = '0'
          report "WBUS SLAVE " & G_NAME &
                 ": Repeated access received";
        req_active <= '1';
      end if;

      if s_wbus.ack = '1' then
        assert req_active = '1'
          report "WBUS SLAVE " & G_NAME &
                 ": Missing access";
        req_active <= '0';
      end if;

      if rst_i = '1' or s_wbus.cyc = '0' then
        req_active <= '0';
      end if;
    end if;
  end process assert_proc;

end architecture simulation;

