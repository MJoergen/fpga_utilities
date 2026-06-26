-------------------------------------------------------------------------------
-- Description:
--
-- SPDX-License-Identifier: MIT
-------------------------------------------------------------------------------

library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std_unsigned.all;

entity avm_pipe is
  generic (
    G_BURST_BITS : positive := 8; -- Number of bits
    G_ADDR_BITS  : positive; -- Number of bits
    G_DATA_BITS  : positive  -- Number of bits
  );
  port (
    clk_i             : in    std_logic;
    rst_i             : in    std_logic;
    s_waitrequest_o   : out   std_logic;
    s_write_i         : in    std_logic;
    s_read_i          : in    std_logic;
    s_address_i       : in    std_logic_vector(G_ADDR_BITS - 1 downto 0);
    s_writedata_i     : in    std_logic_vector(G_DATA_BITS - 1 downto 0);
    s_byteenable_i    : in    std_logic_vector(G_DATA_BITS / 8 - 1 downto 0);
    s_burstcount_i    : in    std_logic_vector(G_BURST_BITS - 1 downto 0);
    s_readdata_o      : out   std_logic_vector(G_DATA_BITS - 1 downto 0);
    s_readdatavalid_o : out   std_logic;
    m_waitrequest_i   : in    std_logic;
    m_write_o         : out   std_logic;
    m_read_o          : out   std_logic;
    m_address_o       : out   std_logic_vector(G_ADDR_BITS - 1 downto 0);
    m_writedata_o     : out   std_logic_vector(G_DATA_BITS - 1 downto 0);
    m_byteenable_o    : out   std_logic_vector(G_DATA_BITS / 8 - 1 downto 0);
    m_burstcount_o    : out   std_logic_vector(G_BURST_BITS - 1 downto 0);
    m_readdata_i      : in    std_logic_vector(G_DATA_BITS - 1 downto 0);
    m_readdatavalid_i : in    std_logic
  );
end entity avm_pipe;

architecture rtl of avm_pipe is

  subtype  R_ADDRESS    is natural range G_ADDR_BITS - 1 downto 0;
  subtype  R_WRITEDATA  is natural range R_ADDRESS'left    + G_DATA_BITS     downto R_ADDRESS'left + 1;
  subtype  R_BYTEENABLE is natural range R_WRITEDATA'left  + G_DATA_BITS / 8 downto R_WRITEDATA'left + 1;
  subtype  R_BURSTCOUNT is natural range R_BYTEENABLE'left + G_BURST_BITS    downto R_BYTEENABLE'left + 1;
  constant C_WRITE   : natural := R_BURSTCOUNT'left + 1;
  constant C_WR_BITS : natural := R_BURSTCOUNT'left + 2;

  signal   s_wr_ready : std_logic;
  signal   s_wr_valid : std_logic;
  signal   s_wr_data  : std_logic_vector(C_WR_BITS - 1 downto 0);

  signal   m_wr_ready : std_logic;
  signal   m_wr_valid : std_logic;
  signal   m_wr_data  : std_logic_vector(C_WR_BITS - 1 downto 0);

begin

  assert s_read_i /= '1' or s_write_i /= '1' or rst_i = '1'
    report "Simultaneous read+write not allowed"
    severity failure;

  s_waitrequest_o         <= not s_wr_ready;
  s_wr_data(R_ADDRESS)    <= s_address_i;
  s_wr_data(R_WRITEDATA)  <= s_writedata_i;
  s_wr_data(R_BYTEENABLE) <= s_byteenable_i;
  s_wr_data(R_BURSTCOUNT) <= s_burstcount_i;
  s_wr_data(C_WRITE)      <= s_write_i;
  s_wr_valid              <= s_write_i or s_read_i;


  axis_pipe_wr_inst : entity work.axis_pipe
    generic map (
      G_DATA_BITS => C_WR_BITS
    )
    port map (
      clk_i     => clk_i,
      rst_i     => rst_i,
      s_ready_o => s_wr_ready,
      s_valid_i => s_wr_valid,
      s_data_i  => s_wr_data,
      m_ready_i => m_wr_ready,
      m_valid_o => m_wr_valid,
      m_data_o  => m_wr_data
    ); -- axis_pipe_wr_inst : entity work.axis_pipe

  m_wr_ready     <= not m_waitrequest_i;
  m_address_o    <= m_wr_data(R_ADDRESS);
  m_writedata_o  <= m_wr_data(R_WRITEDATA);
  m_byteenable_o <= m_wr_data(R_BYTEENABLE);
  m_burstcount_o <= m_wr_data(R_BURSTCOUNT);
  m_write_o      <= m_wr_valid and m_wr_data(C_WRITE);
  m_read_o       <= m_wr_valid and not m_wr_data(C_WRITE);


  -- The read response pipe has m_ready_i tied to '1' because Avalon-MM
  -- responses cannot be back-pressured. The 2-stage pipe buffers any
  -- transient depth needed for the address-phase pipelining; the master
  -- side is expected to consume responses as they arrive.
  axis_pipe_rd_inst : entity work.axis_pipe
    generic map (
      G_DATA_BITS => G_DATA_BITS
    )
    port map (
      clk_i     => clk_i,
      rst_i     => rst_i,
      s_ready_o => open,
      s_valid_i => m_readdatavalid_i,
      s_data_i  => m_readdata_i,
      m_ready_i => '1',
      m_valid_o => s_readdatavalid_o,
      m_data_o  => s_readdata_o
    ); -- axis_pipe_rd_inst : entity work.axis_pipe

end architecture rtl;

