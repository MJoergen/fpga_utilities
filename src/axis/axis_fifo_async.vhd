-------------------------------------------------------------
-- Description: An AXI stream asynchronous FIFO
--
-- SPDX-License-Identifier: MIT
-------------------------------------------------------------

library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std.all;

entity axis_fifo_async is
  generic (
    G_ADDR_BITS : positive := 12;
    G_DATA_BITS : positive := 8
  );
  port (
    -- Input AXI stream
    s_clk_i   : in    std_logic;
    s_rst_i   : in    std_logic;
    s_ready_o : out   std_logic;
    s_valid_i : in    std_logic;
    s_data_i  : in    std_logic_vector(G_DATA_BITS - 1 downto 0);
    s_fill_o  : out   natural range 0 to 2 ** G_ADDR_BITS;
    -- Output AXI stream
    m_clk_i   : in    std_logic;
    m_rst_i   : in    std_logic;
    m_ready_i : in    std_logic;
    m_valid_o : out   std_logic;
    m_data_o  : out   std_logic_vector(G_DATA_BITS - 1 downto 0);
    m_fill_o  : out   natural range 0 to 2 ** G_ADDR_BITS
  );
end entity axis_fifo_async;

architecture rtl of axis_fifo_async is

  -- Number of words in FIFO
  constant C_FIFO_SIZE : positive                                  := 2 ** G_ADDR_BITS;

  -- Dual-port RAM memory to contain the FIFO data.
  type     ram_type is array (natural range <>) of std_logic_vector(G_DATA_BITS - 1 downto 0);
  signal   dpram : ram_type(0 to C_FIFO_SIZE - 1);

  -- We're using gray codes to avoid glitches when transferring between clock domains.

  -- Write pointer (gray code) in source clock domain
  signal   s_gray_wr : std_logic_vector(G_ADDR_BITS downto 0)      := (others => '0');

  -- Write pointer (gray code) in destination clock domain
  signal   m_gray_wr : std_logic_vector(G_ADDR_BITS downto 0)      := (others => '0');

  -- Read pointer (gray code) in destination clock domain
  signal   m_gray_rd : std_logic_vector(G_ADDR_BITS downto 0)      := (others => '0');

  -- Read pointer (gray code) in source clock domain
  signal   s_gray_rd : std_logic_vector(G_ADDR_BITS downto 0)      := (others => '0');

  -- Handle CDC
  -- There must additionally be an explicit set_max_delay in the constraint file.
  signal   m_gray_wr_meta : std_logic_vector(G_ADDR_BITS downto 0) := (others => '0');
  signal   s_gray_rd_meta : std_logic_vector(G_ADDR_BITS downto 0) := (others => '0');
  attribute async_reg : string;
  attribute async_reg of m_gray_wr_meta : signal is "true";
  attribute async_reg of m_gray_wr      : signal is "true";
  attribute async_reg of s_gray_rd_meta : signal is "true";
  attribute async_reg of s_gray_rd      : signal is "true";

  -- Convert binary to gray code

  pure function unsigned2gray (
    b : unsigned
  ) return std_logic_vector is
    variable g_v : std_logic_vector(b'range);
  begin
    g_v(b'left) := b(b'left);

    for i in b'left - 1 downto b'right loop
      g_v(i) := b(i + 1) xor b(i);
    end loop;

    return g_v;
  end function unsigned2gray;

  -- Convert gray code to binary

  pure function gray2unsigned (
    g : std_logic_vector
  ) return unsigned is
    variable b_v : unsigned(g'range);
  begin
    b_v(g'left) := g(g'left);

    for i in g'left - 1 downto g'right loop
      b_v(i) := b_v(i + 1) xor g(i);
    end loop;

    return b_v;
  end function gray2unsigned;

  -- When the two binary pointers differ by exactly C_FIFO_SIZE,
  -- then the gray-coded values are identical except for the two
  -- most significant bits.

  pure function get_gray_full return std_logic_vector is
    variable res_v : std_logic_vector(G_ADDR_BITS downto 0);
  begin
    res_v                  := (others => '0');
    res_v(G_ADDR_BITS)     := '1';
    res_v(G_ADDR_BITS - 1) := '1';
    return res_v;
  end function get_gray_full;

  constant C_GRAY_FULL : std_logic_vector(G_ADDR_BITS downto 0)    := get_gray_full;

begin

  -----------------------------------------------------------
  -- Input flow control
  -- Accept when pipeline contains less than C_FIFO_SIZE.
  -----------------------------------------------------------

  s_ready_o <= '0' when (s_gray_wr xor s_gray_rd) = C_GRAY_FULL else
               '1';

  s_fill_o <= to_integer(gray2unsigned(s_gray_wr) - gray2unsigned(s_gray_rd));
  m_fill_o <= to_integer(gray2unsigned(m_gray_wr) - gray2unsigned(m_gray_rd));

  -----------------------------------------------------------
  -- Update write pointer
  -----------------------------------------------------------

  s_proc : process (s_clk_i)
  begin
    if rising_edge(s_clk_i) then
      if s_valid_i = '1' and s_ready_o = '1' then
        s_gray_wr <= unsigned2gray(gray2unsigned(s_gray_wr) + 1);
      end if;
      if s_rst_i = '1' then
        s_gray_wr <= (others => '0');
      end if;
    end if;
  end process s_proc;


  -----------------------------------------------------------
  -- Dual port memory: One write port, and one read port.
  -- There is no need for a complete CDC circuit on the output of the RAM, a simple flip-flop is sufficient. This is
  -- because the contents being read from the RAM is not changing at the time it is sampled. This is due to the CDC
  -- causing a two-cycle delay between writing to and reading from a given memory location.
  -----------------------------------------------------------

  dpram_proc : process (s_clk_i, m_clk_i)
    variable index_v : natural range 0 to C_FIFO_SIZE - 1;
  begin
    -- Write to memory
    if rising_edge(s_clk_i) then
      if s_valid_i = '1' and s_ready_o = '1' then
        index_v        := to_integer(gray2unsigned(s_gray_wr)) mod C_FIFO_SIZE;
        dpram(index_v) <= s_data_i;
      end if;
    end if;

    -- Read from memory
    if rising_edge(m_clk_i) then
      if m_gray_wr /= m_gray_rd and (m_ready_i = '1' or m_valid_o = '0') then
        index_v  := to_integer(gray2unsigned(m_gray_rd)) mod C_FIFO_SIZE;
        m_data_o <= dpram(index_v);
      end if;
    end if;
  end process dpram_proc;


  -----------------------------------------------------------
  -- Handle CDC explicitly.
  -- We won't use the Xilinx XPM primitive, because that includes a set_false_path.
  -- Instead, we use a set_max_delay in the constraints.
  -- It's placed inside a 'block' to simplify the associated timing constraint.
  -----------------------------------------------------------

  axis_pipe_async_block : block is
  begin

    async_m_proc : process (m_clk_i)
    begin
      if rising_edge(m_clk_i) then
        m_gray_wr_meta <= s_gray_wr;
        m_gray_wr      <= m_gray_wr_meta;
      end if;
    end process async_m_proc;

    async_s_proc : process (s_clk_i)
    begin
      if rising_edge(s_clk_i) then
        s_gray_rd_meta <= m_gray_rd;
        s_gray_rd      <= s_gray_rd_meta;
      end if;
    end process async_s_proc;

  end block axis_pipe_async_block;


  -----------------------------------------------------------
  -- Forward data, one word at a time, as soon as the write pointer is different from
  -- the read pointer.
  -----------------------------------------------------------

  m_proc : process (m_clk_i)
  begin
    if rising_edge(m_clk_i) then
      if m_ready_i = '1' then
        m_valid_o <= '0';
      end if;

      if m_gray_wr /= m_gray_rd and (m_ready_i = '1' or m_valid_o = '0') then
        m_gray_rd <= unsigned2gray(gray2unsigned(m_gray_rd) + 1);
        m_valid_o <= '1';
      end if;

      if m_rst_i = '1' then
        m_gray_rd <= (others => '0');
      end if;
    end if;
  end process m_proc;

end architecture rtl;

