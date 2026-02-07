-- ---------------------------------------------------------------------------------------
-- Description: Distribute AXI packet to two different AXI masters
-- ---------------------------------------------------------------------------------------

library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std.all;

library work;
  use work.axip_pkg.all;

entity axip_distributor is
  port (
    clk_i   : in    std_logic;
    rst_i   : in    std_logic;
    s_dst_i : in    std_logic;
    s_axip  : view axip_slave_view;
    m0_axip : view axip_master_view;
    m1_axip : view axip_master_view
  );
end entity axip_distributor;

architecture synthesis of axip_distributor is

  signal s_first : std_logic := '1';
  signal s_dst   : std_logic := '0';
  signal s_dst_r : std_logic := '0';

begin

  -- s_first is asserted on the first clock cycle of the next packet
  first_proc : process (clk_i)
  begin
    if rising_edge(clk_i) then
      if s_axip.valid = '1' and s_axip.ready = '1' then
        s_first <= s_axip.last;
      end if;

      if rst_i = '1' then
        s_first <= '1';
      end if;
    end if;
  end process first_proc;

  -- s_dst_i is sampled on the first clock cycle of the packet, and remembered
  dst_proc : process (clk_i)
  begin
    if rising_edge(clk_i) then
      if s_axip.valid = '1' and s_axip.ready = '1' and s_first = '1' then
        s_dst_r <= s_dst_i;
      end if;

      if rst_i = '1' then
        s_dst_r <= '0';
      end if;
    end if;
  end process dst_proc;

  -- Only change direction when a new packet starts
  s_dst         <= s_dst_i when s_first = '1' else
                   s_dst_r;


  m0_axip.valid <= s_axip.valid when s_dst = '0' else
                   '0';
  m1_axip.valid <= s_axip.valid when s_dst = '1' else
                   '0';
  s_axip.ready  <= m0_axip.ready when s_dst = '0' else
                   m1_axip.ready;

  m0_axip.data  <= s_axip.data;
  m1_axip.data  <= s_axip.data;

  m0_axip.last  <= s_axip.last;
  m1_axip.last  <= s_axip.last;

  m0_axip.bytes <= s_axip.bytes;
  m1_axip.bytes <= s_axip.bytes;

end architecture synthesis;

