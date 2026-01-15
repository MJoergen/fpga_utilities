-- ---------------------------------------------------------------------------------------
-- Description: This is a simple synchronuous AXI packet FIFO.
-- ---------------------------------------------------------------------------------------

library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std.all;

entity axip_fifo_sync is
  generic (
    G_RAM_STYLE  : string := "auto";
    G_RAM_DEPTH  : natural;
    G_DATA_BYTES : natural
  );
  port (
    clk_i     : in    std_logic;
    rst_i     : in    std_logic;
    fill_o    : out   natural range 0 to G_RAM_DEPTH - 1;

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
end entity axip_fifo_sync;

architecture synthesis of axip_fifo_sync is

  signal   s_data_in  : std_logic_vector(G_DATA_BYTES * 8 + 15 downto 0);
  signal   m_data_out : std_logic_vector(G_DATA_BYTES * 8 + 15 downto 0);

  subtype  R_AXI_FIFO_DATA is natural range G_DATA_BYTES * 8 - 1 downto 0;

  subtype  R_AXI_FIFO_BYTES is natural range G_DATA_BYTES * 8 + 14 downto G_DATA_BYTES * 8;

  constant C_AXI_FIFO_LAST : natural := G_DATA_BYTES * 8 + 15;

begin

  axis_fifo_sync_inst : entity work.axis_fifo_sync
    generic map (
      G_RAM_STYLE => G_RAM_STYLE,
      G_RAM_DEPTH => G_RAM_DEPTH,
      G_DATA_SIZE => G_DATA_BYTES * 8 + 16
    )
    port map (
      clk_i     => clk_i,
      rst_i     => rst_i,
      s_ready_o => s_ready_o,
      s_valid_i => s_valid_i,
      s_data_i  => s_data_in,
      m_ready_i => m_ready_i,
      m_valid_o => m_valid_o,
      m_data_o  => m_data_out
    ); -- axi_fifo_sync_inst : entity work.axi_fifo_sync

  s_data_in(R_AXI_FIFO_DATA)  <= s_data_i;
  s_data_in(C_AXI_FIFO_LAST)  <= s_last_i;
  s_data_in(R_AXI_FIFO_BYTES) <= std_logic_vector(to_unsigned(s_bytes_i, 15));

  m_data_o                    <= m_data_out(R_AXI_FIFO_DATA);
  m_last_o                    <= m_data_out(C_AXI_FIFO_LAST);
  m_bytes_o                   <= to_integer(unsigned(m_data_out(R_AXI_FIFO_BYTES)));

end architecture synthesis;

