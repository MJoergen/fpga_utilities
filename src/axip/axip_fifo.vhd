-- ---------------------------------------------------------------------------------------
-- Description: This is a simple synchronous AXI packet FIFO.
-- s_bytes_i is only valid when s_last_i is 1.
-- m_bytes_o is only valid when m_last_o is 1.
--
-- SPDX-License-Identifier: MIT
-- ---------------------------------------------------------------------------------------

library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std.all;

entity axip_fifo is
  generic (
    G_ADDR_BITS  : positive;
    G_DATA_BYTES : positive;
    G_RAM_STYLE  : string := "auto"
  );
  port (
    clk_i     : in    std_logic;
    rst_i     : in    std_logic;
    fill_o    : out   natural range 0 to 2**G_ADDR_BITS - 1;

    -- AXI packet input interface
    s_ready_o : out   std_logic;
    s_valid_i : in    std_logic;
    s_data_i  : in    std_logic_vector(G_DATA_BYTES * 8 - 1 downto 0);
    s_last_i  : in    std_logic;
    s_bytes_i : in    natural range 0 to G_DATA_BYTES;

    -- AXI packet output interface
    m_ready_i : in    std_logic;
    m_valid_o : out   std_logic;
    m_data_o  : out   std_logic_vector(G_DATA_BYTES * 8 - 1 downto 0);
    m_last_o  : out   std_logic;
    m_bytes_o : out   natural range 0 to G_DATA_BYTES
  );
end entity axip_fifo;

architecture rtl of axip_fifo is

  signal   s_data_in  : std_logic_vector(G_DATA_BYTES * 8 + 15 downto 0);
  signal   m_data_out : std_logic_vector(G_DATA_BYTES * 8 + 15 downto 0);

  subtype  R_DATA is natural range G_DATA_BYTES * 8 - 1 downto 0;

  subtype  R_BYTES is natural range G_DATA_BYTES * 8 + 14 downto G_DATA_BYTES * 8;

  constant C_LAST : natural := G_DATA_BYTES * 8 + 15;

begin

  axis_fifo_inst : entity work.axis_fifo
    generic map (
      G_ADDR_BITS => G_ADDR_BITS,
      G_DATA_BITS => G_DATA_BYTES * 8 + 16,
      G_RAM_STYLE => G_RAM_STYLE
    )
    port map (
      clk_i     => clk_i,
      rst_i     => rst_i,
      fill_o    => fill_o,
      s_ready_o => s_ready_o,
      s_valid_i => s_valid_i,
      s_data_i  => s_data_in,
      m_ready_i => m_ready_i,
      m_valid_o => m_valid_o,
      m_data_o  => m_data_out
    ); -- axis_fifo_inst : entity work.axis_fifo

  s_data_in(R_DATA)  <= s_data_i;
  s_data_in(C_LAST)  <= s_last_i;
  s_data_in(R_BYTES) <= std_logic_vector(to_unsigned(s_bytes_i, 15));

  m_data_o           <= m_data_out(R_DATA);
  m_last_o           <= m_data_out(C_LAST);
  m_bytes_o          <= to_integer(unsigned(m_data_out(R_BYTES)));

end architecture rtl;

