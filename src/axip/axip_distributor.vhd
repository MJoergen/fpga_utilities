-- ---------------------------------------------------------------------------------------
-- Description: Distribute AXI packet to two different AXI masters
-- ---------------------------------------------------------------------------------------

library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std.all;

entity axip_distributor is
  generic (
    G_DATA_BYTES : natural
  );
  port (
    clk_i      : in    std_logic;
    rst_i      : in    std_logic;

    s_ready_o  : out   std_logic;
    s_valid_i  : in    std_logic;
    s_data_i   : in    std_logic_vector(G_DATA_BYTES * 8 - 1 downto 0);
    s_last_i   : in    std_logic;
    s_bytes_i  : in    natural range 0 to G_DATA_BYTES;
    s_dst_i    : in    std_logic;

    m0_ready_i : in    std_logic;
    m0_valid_o : out   std_logic;
    m0_data_o  : out   std_logic_vector(G_DATA_BYTES * 8 - 1 downto 0);
    m0_last_o  : out   std_logic;
    m0_bytes_o : out   natural range 0 to G_DATA_BYTES;

    m1_ready_i : in    std_logic;
    m1_valid_o : out   std_logic;
    m1_data_o  : out   std_logic_vector(G_DATA_BYTES * 8 - 1 downto 0);
    m1_last_o  : out   std_logic;
    m1_bytes_o : out   natural range 0 to G_DATA_BYTES
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
      if s_valid_i = '1' and s_ready_o = '1' then
        s_first <= s_last_i;
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
      if s_valid_i = '1' and s_ready_o = '1' and s_first = '1' then
        s_dst_r <= s_dst_i;
      end if;

      if rst_i = '1' then
        s_dst_r <= '0';
      end if;
    end if;
  end process dst_proc;

  -- Only change direction when a new packet starts
  s_dst      <= s_dst_i when s_first = '1' else
                s_dst_r;


  m0_valid_o <= s_valid_i when s_dst = '0' else
                '0';
  m1_valid_o <= s_valid_i when s_dst = '1' else
                '0';
  s_ready_o  <= m0_ready_i when s_dst = '0' else
                m1_ready_i;

  m0_data_o  <= s_data_i;
  m1_data_o  <= s_data_i;

  m0_last_o  <= s_last_i;
  m1_last_o  <= s_last_i;

  m0_bytes_o <= s_bytes_i;
  m1_bytes_o <= s_bytes_i;

end architecture synthesis;

