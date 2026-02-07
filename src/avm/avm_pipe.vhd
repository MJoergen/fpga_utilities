library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std_unsigned.all;

library work;
  use work.axis_pkg.all;
  use work.avm_pkg.all;

entity avm_pipe is
  port (
    clk_i : in    std_logic;
    rst_i : in    std_logic;
    s_avm : view  avm_slave_view;
    m_avm : view  avm_master_view
  );
end entity avm_pipe;

architecture synthesis of avm_pipe is

  constant C_ADDR_SIZE : positive := s_avm.address'length;
  constant C_DATA_SIZE : positive := s_avm.writedata'length;

  subtype  R_ADDRESS is natural range C_ADDR_SIZE - 1 downto 0;

  subtype  R_WRITEDATA is natural range R_ADDRESS'left    + C_DATA_SIZE     downto R_ADDRESS'left + 1;

  subtype  R_BYTEENABLE is natural range R_WRITEDATA'left  + C_DATA_SIZE / 8 downto R_WRITEDATA'left + 1;

  subtype  R_BURSTCOUNT is natural range R_BYTEENABLE'left + 8               downto R_BYTEENABLE'left + 1;

  constant C_WRITE   : natural    := R_BURSTCOUNT'left + 1;
  constant C_WR_SIZE : natural    := R_BURSTCOUNT'left + 2;

  signal   s_wr_axis : axis_rec_type (
                                      data(C_WR_SIZE - 1 downto 0)
                                     );

  signal   m_wr_axis : axis_rec_type (
                                      data(C_WR_SIZE - 1 downto 0)
                                     );

  signal   s_rd_axis : axis_rec_type (
                                      data(C_DATA_SIZE - 1 downto 0)
                                     );

  signal   m_rd_axis : axis_rec_type (
                                      data(C_DATA_SIZE - 1 downto 0)
                                     );

begin

  s_avm.waitrequest            <= not s_wr_axis.ready;
  s_wr_axis.data(R_ADDRESS)    <= s_avm.address;
  s_wr_axis.data(R_WRITEDATA)  <= s_avm.writedata;
  s_wr_axis.data(R_BYTEENABLE) <= s_avm.byteenable;
  s_wr_axis.data(R_BURSTCOUNT) <= s_avm.burstcount;
  s_wr_axis.data(C_WRITE)      <= s_avm.write;
  s_wr_axis.valid              <= s_avm.write or s_avm.read;

  m_wr_axis.ready              <= not m_avm.waitrequest;
  m_avm.address                <= m_wr_axis.data(R_ADDRESS);
  m_avm.writedata              <= m_wr_axis.data(R_WRITEDATA);
  m_avm.byteenable             <= m_wr_axis.data(R_BYTEENABLE);
  m_avm.burstcount             <= m_wr_axis.data(R_BURSTCOUNT);
  m_avm.write                  <= m_wr_axis.valid and m_wr_axis.data(C_WRITE);
  m_avm.read                   <= m_wr_axis.valid and not m_wr_axis.data(C_WRITE);

  axis_pipe_wr_inst : entity work.axis_pipe
    port map (
      clk_i  => clk_i,
      rst_i  => rst_i,
      s_axis => s_wr_axis,
      m_axis => m_wr_axis
    ); -- axis_pipe_wr_inst : entity work.axis_pipe


  s_rd_axis.data               <= m_avm.readdata;
  s_rd_axis.valid              <= m_avm.readdatavalid;

  s_avm.readdata               <= m_rd_axis.data;
  s_avm.readdatavalid          <= m_rd_axis.valid;
  m_rd_axis.ready              <= '1';

  axis_pipe_rd_inst : entity work.axis_pipe
    port map (
      clk_i  => clk_i,
      rst_i  => rst_i,
      s_axis => s_rd_axis,
      m_axis => m_rd_axis
    ); -- axis_pipe_rd_inst : entity work.axis_pipe

end architecture synthesis;

