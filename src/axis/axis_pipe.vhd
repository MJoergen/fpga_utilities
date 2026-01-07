-- ----------------------------------------------------------------------------
-- Author     : Michael Jørgensen
-- Platform   : AMD Artix 7
-- ----------------------------------------------------------------------------
-- Description: An elastic pipeline with two stages, i.e. can accept two writes
-- before blocking.  In other words, a FIFO of depth two.
-- ----------------------------------------------------------------------------

library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std.all;

entity axis_pipe is
  generic (
    G_DATA_SIZE : integer
  );
  port (
    clk_i     : in    std_logic;
    rst_i     : in    std_logic;
    s_ready_o : out   std_logic;
    s_valid_i : in    std_logic;
    s_data_i  : in    std_logic_vector(G_DATA_SIZE - 1 downto 0);
    s_fill_o  : out   std_logic_vector(1 downto 0);
    m_ready_i : in    std_logic;
    m_valid_o : out   std_logic;
    m_data_o  : out   std_logic_vector(G_DATA_SIZE - 1 downto 0)
  );
end entity axis_pipe;

architecture synthesis of axis_pipe is

  -- Input registers
  signal s_data : std_logic_vector(G_DATA_SIZE - 1 downto 0);

begin

  s_fill_o <= "00" when m_valid_o = '0' else
              "01" when m_valid_o = '1' and s_ready_o = '1' else
              "10"; --  when m_valid_o = '1' and s_ready_o = '0'

  s_data_proc : process (clk_i)
  begin
    if rising_edge(clk_i) then
      if s_ready_o = '1' then
        s_data <= s_data_i;
      end if;
    end if;
  end process s_data_proc;

  s_ready_proc : process (clk_i)
  begin
    if rising_edge(clk_i) then
      if m_valid_o = '1' then
        s_ready_o <= m_ready_i or (s_ready_o and not s_valid_i);
      end if;

      if rst_i = '1' then
        s_ready_o <= '1';
      end if;
    end if;
  end process s_ready_proc;

  m_proc : process (clk_i)
  begin
    if rising_edge(clk_i) then
      if s_ready_o = '1' then
        if m_valid_o = '0' or m_ready_i = '1' then
          m_valid_o <= s_valid_i;
          m_data_o  <= s_data_i;
        end if;
      else
        if m_ready_i = '1' then
          m_data_o <= s_data;
        end if;
      end if;

      if rst_i = '1' then
        m_valid_o <= '0';
      end if;
    end if;
  end process m_proc;

end architecture synthesis;

