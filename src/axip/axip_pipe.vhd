-- ---------------------------------------------------------------------------------------
-- Description: An elastic pipeline for an AXI Packet interface.
-- ---------------------------------------------------------------------------------------

library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std.all;

entity axip_pipe is
  generic (
    G_DATA_BYTES : natural
  );
  port (
    clk_i     : in    std_logic;
    rst_i     : in    std_logic;

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
end entity axip_pipe;

architecture synthesis of axip_pipe is

  subtype  R_DATA is natural range G_DATA_BYTES * 8 - 1 downto 0;

  subtype  R_BYTES is natural range G_DATA_BYTES * 8 + 14 downto G_DATA_BYTES * 8;

  constant C_LAST : natural := G_DATA_BYTES * 8 + 15;

  signal   s_in  : std_logic_vector(G_DATA_BYTES * 8 + 15 downto 0);
  signal   m_out : std_logic_vector(G_DATA_BYTES * 8 + 15 downto 0);

begin

  axis_pipe_inst : entity work.axis_pipe
    generic map (
      G_DATA_SIZE => G_DATA_BYTES * 8 + 16
    )
    port map (
      clk_i     => clk_i,
      rst_i     => rst_i,
      s_ready_o => s_ready_o,
      s_valid_i => s_valid_i,
      s_data_i  => s_in,
      s_fill_o  => open,
      m_ready_i => m_ready_i,
      m_valid_o => m_valid_o,
      m_data_o  => m_out
    ); -- axis_pipe_inst : entity work.axis_pipe

  s_in(R_DATA)  <= s_data_i;
  s_in(R_BYTES) <= std_logic_vector(to_unsigned(s_bytes_i, 15));
  s_in(C_LAST)  <= s_last_i;
  m_data_o      <= m_out(R_DATA);
  m_bytes_o     <= to_integer(unsigned(m_out(R_BYTES)));
  m_last_o      <= m_out(C_LAST);

end architecture synthesis;

