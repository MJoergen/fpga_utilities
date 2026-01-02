-- ----------------------------------------------------------------------------
-- Author     : Michael Jørgensen
-- Platform   : AMD Artix 7
-- ----------------------------------------------------------------------------
-- Description: Distribute AXI stream to two different AXI masters
-- ----------------------------------------------------------------------------

library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std.all;

entity axis_distributor is
  generic (
    G_DATA_SIZE : natural
  );
  port (
    clk_i      : in    std_logic;
    rst_i      : in    std_logic;

    s_ready_o  : out   std_logic;
    s_valid_i  : in    std_logic;
    s_data_i   : in    std_logic_vector(G_DATA_SIZE - 1 downto 0);
    s_dst_i    : in    std_logic;

    m0_ready_i : in    std_logic;
    m0_valid_o : out   std_logic;
    m0_data_o  : out   std_logic_vector(G_DATA_SIZE - 1 downto 0);

    m1_ready_i : in    std_logic;
    m1_valid_o : out   std_logic;
    m1_data_o  : out   std_logic_vector(G_DATA_SIZE - 1 downto 0)
  );
end entity axis_distributor;

architecture synthesis of axis_distributor is

begin

  m0_valid_o <= s_valid_i when s_dst_i = '0' else
                '0';
  m1_valid_o <= s_valid_i when s_dst_i = '1' else
                '0';
  s_ready_o  <= m0_ready_i when s_dst_i = '0' else
                m1_ready_i;

  m0_data_o  <= s_data_i;
  m1_data_o  <= s_data_i;

end architecture synthesis;

