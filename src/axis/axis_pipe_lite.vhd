-- ---------------------------------------------------------------------------------------
-- This module implements a pipe consisting of only a single register layer.  It has its
-- use in elastic pipelines, where the data flow has back-pressure.  It places registers
-- on the valid and data signals in the downstream direction, but the ready signal in the
-- upstream direction is still combinatorial.  The pipe supports simultaneous read and
-- write, both when the pipe is full and when it is empty.
--
-- For additional information, see:
-- https://www.itdev.co.uk/blog/pipelining-axi-buses-registered-ready-signals
-- ---------------------------------------------------------------------------------------

library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std.all;

entity axis_pipe_lite is
  generic (
    G_DATA_SIZE : positive
  );
  port (
    clk_i     : in    std_logic;
    rst_i     : in    std_logic;
    s_ready_o : out   std_logic;
    s_valid_i : in    std_logic;
    s_data_i  : in    std_logic_vector(G_DATA_SIZE - 1 downto 0);
    m_ready_i : in    std_logic;
    m_valid_o : out   std_logic;
    m_data_o  : out   std_logic_vector(G_DATA_SIZE - 1 downto 0)
  );
end entity axis_pipe_lite;

architecture synthesis of axis_pipe_lite is

begin

  -- We accept data from upstream in two situations:
  -- * When pipe is empty.
  -- * When downstream is ready.
  -- The latter situation allows simultaneous read and write, even when the
  -- pipe is full.
  s_ready_o <= m_ready_i or not m_valid_o;

  m_proc : process (clk_i)
  begin
    if rising_edge(clk_i) then
      if s_ready_o then
        m_data_o  <= s_data_i;
        m_valid_o <= s_valid_i;
      end if;

      -- Reset empties the pipe
      if rst_i = '1' then
        m_valid_o <= '0';
      end if;
    end if;
  end process m_proc;

end architecture synthesis;

