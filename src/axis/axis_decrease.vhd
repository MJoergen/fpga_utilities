-- ---------------------------------------------------------------------------------------
-- Description: Pack an AXI stream into fewer bits
--
-- SPDX-License-Identifier: MIT
-- ---------------------------------------------------------------------------------------

library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std.all;

entity axis_decrease is
  generic (
    G_SLAVE_DATA_BITS  : natural;
    G_MASTER_DATA_BITS : natural
  );
  port (
    clk_i     : in    std_logic;
    rst_i     : in    std_logic;
    s_ready_o : out   std_logic;
    s_valid_i : in    std_logic;
    s_data_i  : in    std_logic_vector(G_SLAVE_DATA_BITS - 1 downto 0);
    m_ready_i : in    std_logic;
    m_valid_o : out   std_logic;
    m_data_o  : out   std_logic_vector(G_MASTER_DATA_BITS - 1 downto 0)
  );
end entity axis_decrease;

architecture rtl of axis_decrease is

  constant C_CONCAT_BITS : natural := 2 * G_SLAVE_DATA_BITS;

  signal   concat_s : std_logic_vector(C_CONCAT_BITS - 1 downto 0);

  signal   data_r : std_logic_vector(G_SLAVE_DATA_BITS - 1 downto 0);
  signal   size_r : natural range 0 to C_CONCAT_BITS;

begin

  concat_s  <= data_r & s_data_i;

  assert G_MASTER_DATA_BITS < G_SLAVE_DATA_BITS;

  s_ready_o <= '0' when rst_i = '1' else
               m_ready_i or not m_valid_o when size_r < G_MASTER_DATA_BITS else
               '0';

  decrease_proc : process (clk_i)
  begin
    if rising_edge(clk_i) then
      if m_ready_i = '1' then
        m_valid_o <= '0';
      end if;

      if s_valid_i = '1' and s_ready_o = '1' then
        m_data_o  <= concat_s(size_r + G_SLAVE_DATA_BITS - 1 downto size_r + G_SLAVE_DATA_BITS - G_MASTER_DATA_BITS);
        m_valid_o <= '1';

        data_r    <= s_data_i;
        size_r    <= size_r + G_SLAVE_DATA_BITS - G_MASTER_DATA_BITS;
      else
        if size_r >= G_MASTER_DATA_BITS and (m_ready_i = '1' or m_valid_o = '0') then
          m_data_o  <= concat_s(size_r + G_SLAVE_DATA_BITS - 1 downto size_r + G_SLAVE_DATA_BITS - G_MASTER_DATA_BITS);
          m_valid_o <= '1';
          size_r    <= size_r - G_MASTER_DATA_BITS;
        end if;
      end if;

      if rst_i = '1' then
        size_r    <= 0;
        m_valid_o <= '0';
      end if;
    end if;
  end process decrease_proc;

end architecture rtl;

