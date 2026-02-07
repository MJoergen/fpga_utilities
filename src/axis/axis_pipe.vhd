-- ---------------------------------------------------------------------------------------
-- Description: An AXI streaming elastic pipeline with two stages, i.e. can accept two
-- writes before blocking.  In other words, a FIFO of depth two.  This can be useful for
-- adding registers to an AXI streaming pipeline for helping to achieve timing closure.
--
-- For additional information, see:
-- https://www.itdev.co.uk/blog/pipelining-axi-buses-registered-ready-signals
-- ---------------------------------------------------------------------------------------

library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std.all;

library work;
  use work.axis_pkg.all;

entity axis_pipe is
  port (
    clk_i    : in    std_logic;
    rst_i    : in    std_logic;
    s_fill_o : out   std_logic_vector(1 downto 0);
    s_axis   : view  axis_slave_view;
    m_axis   : view  axis_master_view
  );
end entity axis_pipe;

architecture synthesis of axis_pipe is

  -- Input registers
  signal s_data : std_logic_vector(s_axis.data'range);

begin

  s_fill_o <= "00" when m_axis.valid = '0' else
              "01" when m_axis.valid = '1' and s_axis.ready = '1' else
              "10"; --  when m_axis.valid = '1' and s_axis.ready = '0'

  s_data_proc : process (clk_i)
  begin
    if rising_edge(clk_i) then
      if s_axis.ready = '1' then
        s_data <= s_axis.data;
      end if;
    end if;
  end process s_data_proc;

  s_ready_proc : process (clk_i)
  begin
    if rising_edge(clk_i) then
      if m_axis.valid = '1' then
        s_axis.ready <= m_axis.ready or (s_axis.ready and not s_axis.valid);
      end if;

      if rst_i = '1' then
        s_axis.ready <= '1';
      end if;
    end if;
  end process s_ready_proc;

  m_proc : process (clk_i)
  begin
    if rising_edge(clk_i) then
      if s_axis.ready = '1' then
        if m_axis.valid = '0' or m_axis.ready = '1' then
          m_axis.valid <= s_axis.valid;
          m_axis.data  <= s_axis.data;
        end if;
      else
        if m_axis.ready = '1' then
          m_axis.data <= s_data;
        end if;
      end if;

      if rst_i = '1' then
        m_axis.valid <= '0';
      end if;
    end if;
  end process m_proc;

end architecture synthesis;

