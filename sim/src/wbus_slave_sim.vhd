-- ---------------------------------------------------------------------------------------
-- Description:
-- Single-outstanding-request Wishbone slave with a memory backing store. Accepts a
-- request on the cycle it asserts stall=0 and stb=1, returns ack on the next cycle. Stall
-- is asserted while the previous transaction is in flight.
--
-- SPDX-License-Identifier: MIT
-- ---------------------------------------------------------------------------------------

library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std_unsigned.all;

entity wbus_slave_sim is
  generic (
    G_NAME      : string  := "";
    G_DEBUG     : boolean := false;
    G_ADDR_BITS : natural;
    G_DATA_BITS : natural
  );
  port (
    clk_i     : in    std_logic;
    rst_i     : in    std_logic;
    s_cyc_i   : in    std_logic;
    s_stall_o : out   std_logic;
    s_stb_i   : in    std_logic;
    s_addr_i  : in    std_logic_vector(G_ADDR_BITS - 1 downto 0);
    s_we_i    : in    std_logic;
    s_wrdat_i : in    std_logic_vector(G_DATA_BITS - 1 downto 0);
    s_sel_i   : in    std_logic_vector(G_DATA_BITS / 8 - 1 downto 0);
    s_ack_o   : out   std_logic;
    s_rddat_o : out   std_logic_vector(G_DATA_BITS - 1 downto 0)
  );
end entity wbus_slave_sim;

architecture simulation of wbus_slave_sim is

  type   ram_type is array (natural range <>) of std_logic_vector(G_DATA_BITS - 1 downto 0);
  signal ram : ram_type(0 to 2 ** G_ADDR_BITS - 1);

  signal req_active : std_logic := '0';

begin

  s_stall_o <= req_active;

  --------------------------------
  -- Generate RAM
  --------------------------------

  ram_proc : process (clk_i)
  begin
    if rising_edge(clk_i) then
      s_ack_o <= '0';
      if s_cyc_i = '1' and s_stall_o = '0' and s_stb_i = '1' then
        -- A request is accepted.
        req_active <= '1';
        if s_we_i = '1' then
          for i in s_sel_i'range loop
            if s_sel_i(i) = '1' then
              ram(to_integer(s_addr_i))(i * 8 + 7 downto i * 8) <= s_wrdat_i(i * 8 + 7 downto i * 8);
            end if;
          end loop;
          s_ack_o <= '1';
          if G_DEBUG then
            report "WBUS SLAVE " & G_NAME &
                   ": Write " & to_hstring(s_wrdat_i) &
                   " sel " & to_hstring(s_sel_i) &
                   " to address " & to_hstring(s_addr_i);
          end if;
        else
          s_rddat_o <= ram(to_integer(s_addr_i));
          s_ack_o   <= '1';
          if G_DEBUG then
            report "WBUS SLAVE " & G_NAME &
                   ": Read  " & to_hstring(ram(to_integer(s_addr_i))) &
                   " from address " & to_hstring(s_addr_i);
          end if;
        end if;
      end if;

      if rst_i = '1' or s_cyc_i = '0' or s_ack_o = '1' then
        req_active <= '0';
        s_ack_o    <= '0';
      end if;
    end if;
  end process ram_proc;


  --------------------------------
  -- Monitor requests
  --------------------------------

  assert_proc : process (clk_i)
  begin
    if rising_edge(clk_i) then
      if s_cyc_i = '1' and s_stall_o = '0' and s_stb_i = '1' then
        assert req_active = '0'
          report "WBUS SLAVE " & G_NAME &
                 ": Repeated access received";
      end if;

      if s_ack_o = '1' then
        assert req_active = '1'
          report "WBUS SLAVE " & G_NAME &
                 ": Missing access";
      end if;
    end if;
  end process assert_proc;

end architecture simulation;

