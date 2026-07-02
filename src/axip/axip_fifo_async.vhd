-- ---------------------------------------------------------------------------------------
-- Description: An AXI packet stream asynchronous FIFO.
-- s_bytes_i is only valid when s_last_i is 1.
-- m_bytes_o is only valid when m_last_o is 1.
--
-- SPDX-License-Identifier: MIT
-- ---------------------------------------------------------------------------------------


library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std.all;

entity axip_fifo_async is
  generic (
    G_ADDR_BITS  : positive;
    G_DATA_BYTES : positive;
    G_RAM_STYLE  : string := "auto"
  );
  port (
    async_rst_i : in    std_logic;
    -- AXI packet input interface
    s_clk_i     : in    std_logic;
    s_ready_o   : out   std_logic;
    s_valid_i   : in    std_logic;
    s_data_i    : in    std_logic_vector(G_DATA_BYTES * 8 - 1 downto 0);
    s_last_i    : in    std_logic;
    s_bytes_i   : in    natural range 0 to G_DATA_BYTES;

    -- AXI packet output interface
    m_clk_i     : in    std_logic;
    m_ready_i   : in    std_logic;
    m_valid_o   : out   std_logic;
    m_data_o    : out   std_logic_vector(G_DATA_BYTES * 8 - 1 downto 0);
    m_last_o    : out   std_logic;
    m_bytes_o   : out   natural range 0 to G_DATA_BYTES
  );
end entity axip_fifo_async;

architecture rtl of axip_fifo_async is

  subtype  R_DATA is natural range G_DATA_BYTES * 8 - 1 downto 0;

  subtype  R_BYTES is natural range G_DATA_BYTES * 8 + 14 downto G_DATA_BYTES * 8;

  constant C_LAST : natural := G_DATA_BYTES * 8 + 15;

  signal   s_in  : std_logic_vector(G_DATA_BYTES * 8 + 15 downto 0);
  signal   m_out : std_logic_vector(G_DATA_BYTES * 8 + 15 downto 0);

begin

  axis_fifo_async_inst : entity work.axis_fifo_async
    generic map (
      G_ADDR_BITS => G_ADDR_BITS,
      G_DATA_BITS => G_DATA_BYTES * 8 + 16,
      G_RAM_STYLE => G_RAM_STYLE
    )
    port map (
      async_rst_i => async_rst_i,
      s_clk_i     => s_clk_i,
      s_ready_o   => s_ready_o,
      s_valid_i   => s_valid_i,
      s_data_i    => s_in,
      m_clk_i     => m_clk_i,
      m_ready_i   => m_ready_i,
      m_valid_o   => m_valid_o,
      m_data_o    => m_out
    ); -- axis_fifo_async_inst : entity work.axis_fifo_async

  s_in(R_DATA)  <= s_data_i;
  s_in(R_BYTES) <= std_logic_vector(to_unsigned(s_bytes_i, 15));
  s_in(C_LAST)  <= s_last_i;
  m_data_o      <= m_out(R_DATA);
  m_bytes_o     <= to_integer(unsigned(m_out(R_BYTES)));
  m_last_o      <= m_out(C_LAST);

end architecture rtl;

