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

library work;
  use work.axis_pkg.all;

entity axis_pipe_lite is
  port (
    clk_i  : in    std_logic;
    rst_i  : in    std_logic;
    s_axis : view  axis_slave_view;
    m_axis : view  axis_master_view
  );
end entity axis_pipe_lite;

architecture synthesis of axis_pipe_lite is

begin

  -- We accept data from upstream in two situations:
  -- * When pipe is empty.
  -- * When downstream is ready.
  -- The latter situation allows simultaneous read and write, even when the
  -- pipe is full.
  s_axis.ready <= m_axis.ready or not m_axis.valid;

  m_proc : process (clk_i)
  begin
    if rising_edge(clk_i) then
      if s_axis.ready then
        m_axis.data  <= s_axis.data;
        m_axis.valid <= s_axis.valid;
      end if;

      if rst_i then
        m_axis.valid <= '0';
      end if;
    end if;
  end process m_proc;

end architecture synthesis;

