library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std_unsigned.all;

entity axis_increase is
  generic (
    G_INPUT_BITS  : natural;
    G_OUTPUT_BITS : natural
  );
  port (
    clk_i     : in    std_logic;
    rst_i     : in    std_logic;
    s_ready_o : out   std_logic;
    s_valid_i : in    std_logic;
    s_data_i  : in    std_logic_vector(G_INPUT_BITS - 1 downto 0);
    m_ready_i : in    std_logic;
    m_valid_o : out   std_logic;
    m_data_o  : out   std_logic_vector(G_OUTPUT_BITS - 1 downto 0)
  );
end entity axis_increase;

architecture rtl of axis_increase is

  constant C_CONCAT_BITS : natural := G_OUTPUT_BITS + G_INPUT_BITS;

  signal   concat_s : std_logic_vector(C_CONCAT_BITS - 1 downto 0);

  signal   data_r : std_logic_vector(G_OUTPUT_BITS - 1 downto 0);
  signal   size_r : natural range 0 to C_CONCAT_BITS;

begin

  assert G_OUTPUT_BITS > G_INPUT_BITS;

  s_ready_o <= '0' when rst_i = '1' else
               '0' when m_valid_o = '1' and m_ready_i = '0' else
               '1' when size_r + G_INPUT_BITS <= G_OUTPUT_BITS else
               '1';

  concat_s  <= data_r & s_data_i;

  increase_proc : process (clk_i)
  begin
    if rising_edge(clk_i) then
      if m_ready_i = '1' then
        m_valid_o <= '0';
      end if;

      if s_valid_i = '1' and s_ready_o = '1' then
        data_r <= concat_s(G_OUTPUT_BITS - 1 downto 0);

        if size_r + G_INPUT_BITS < G_OUTPUT_BITS then
          size_r <= size_r + G_INPUT_BITS;
        else
          m_data_o  <= concat_s(size_r + G_INPUT_BITS - 1 downto size_r + G_INPUT_BITS - G_OUTPUT_BITS);
          m_valid_o <= '1';
          size_r    <= size_r + G_INPUT_BITS - G_OUTPUT_BITS;
        end if;
      end if;

      if rst_i = '1' then
        size_r    <= 0;
        m_valid_o <= '0';
      end if;
    end if;
  end process increase_proc;

end architecture rtl;

