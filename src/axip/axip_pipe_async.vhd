-- ---------------------------------------------------------------------------------------
-- Description: An AXI packet stream asynchronous pipe (shallow FIFO).
-- ---------------------------------------------------------------------------------------

library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std.all;

library work;
  use work.axis_pkg.all;
  use work.axip_pkg.all;

entity axip_pipe_async is
  generic (
    G_PIPE_SIZE : positive range 2 to 16
  );
  port (
    -- AXI packet input interface
    s_clk_i : in    std_logic;
    s_axip  : view  axip_slave_view;

    -- AXI packet output interface
    m_clk_i : in    std_logic;
    m_axip  : view  axip_master_view
  );
end entity axip_pipe_async;

architecture synthesis of axip_pipe_async is

  constant C_DATA_BYTES : positive := s_axip.data'length / 8;

  subtype  R_DATA is natural range C_DATA_BYTES * 8 - 1 downto 0;

  subtype  R_BYTES is natural range C_DATA_BYTES * 8 + 14 downto C_DATA_BYTES * 8;

  constant C_LAST : natural        := C_DATA_BYTES * 8 + 15;

  signal   s_axis : axis_rec_type (
                                   data(C_DATA_BYTES * 8 + 15 downto 0)
                                  );

  signal   m_axis : axis_rec_type (
                                   data(C_DATA_BYTES * 8 + 15 downto 0)
                                  );

begin

  s_axis.valid         <= s_axip.valid;
  s_axis.data(R_DATA)  <= s_axip.data;
  s_axis.data(R_BYTES) <= std_logic_vector(to_unsigned(s_axip.bytes, 15));
  s_axis.data(C_LAST)  <= s_axip.last;
  s_axip.ready         <= s_axis.ready;

  m_axip.valid         <= m_axis.valid;
  m_axip.data          <= m_axis.data(R_DATA);
  m_axip.bytes         <= to_integer(unsigned(m_axis.data(R_BYTES)));
  m_axip.last          <= m_axis.data(C_LAST);
  m_axis.ready         <= m_axip.ready;

  axis_pipe_async_inst : entity work.axis_pipe_async
    generic map (
      G_PIPE_SIZE => G_PIPE_SIZE
    )
    port map (
      s_clk_i => s_clk_i,
      s_axis  => s_axis,
      m_clk_i => m_clk_i,
      m_axis  => m_axis
    ); -- axis_pipe_async_inst : entity work.axis_pipe_async

end architecture synthesis;

