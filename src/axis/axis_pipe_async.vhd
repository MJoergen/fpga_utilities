-------------------------------------------------------------
-- Description: An AXI stream asynchronous pipe (shallow FIFO).
-------------------------------------------------------------

library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std.all;

entity axis_pipe_async is
  generic (
    G_PIPE_SIZE : natural;
    G_DATA_SIZE : natural
  );
  port (
    -- Input AXI stream
    s_clk_i   : in    std_logic;
    s_ready_o : out   std_logic;
    s_valid_i : in    std_logic;
    s_data_i  : in    std_logic_vector(G_DATA_SIZE - 1 downto 0);
    -- Output AXI stream
    m_clk_i   : in    std_logic;
    m_ready_i : in    std_logic;
    m_valid_o : out   std_logic;
    m_data_o  : out   std_logic_vector(G_DATA_SIZE - 1 downto 0)
  );
end entity axis_pipe_async;

architecture synthesis of axis_pipe_async is

  pure function log2 (
    arg : positive
  ) return natural is
  begin
    for i in 0 to 31 loop
      if arg <= 2 ** i then
        return i;
      end if;
    end loop;
    return 32;
  end function log2;

  -- Number of bits in gray-code counters
  constant C_GRAY_SIZE : natural                                       := log2(G_PIPE_SIZE) + 1;

  -- Number of words in FIFO
  constant C_PIPE_SIZE : natural                                       := 2 ** (C_GRAY_SIZE - 1);

  -- Dual-port LUTRAM memory to contain the FIFO data
  -- We use LUTRAM instead of registers to save space in the FPGA.
  -- We could use BRAM, but there is a higher delay writing to BRAM than to LUTRAM.
  type     ram_type is array (natural range <>) of std_logic_vector(G_DATA_SIZE - 1 downto 0);
  signal   dpram : ram_type(0 to C_PIPE_SIZE - 1);
  attribute ram_style : string;
  attribute ram_style of dpram          : signal is "distributed";

  -- We're using gray codes to avoid glitches when transferring between clock domains.

  -- Write pointer (gray code) in source clock domain
  signal   s_gray_wr : std_logic_vector(C_GRAY_SIZE - 1 downto 0)      := (others => '0');

  -- Write pointer (gray code) in destination clock domain
  signal   m_gray_wr : std_logic_vector(C_GRAY_SIZE - 1 downto 0)      := (others => '0');

  -- Read pointer (gray code) in destination clock domain
  signal   m_gray_rd : std_logic_vector(C_GRAY_SIZE - 1 downto 0)      := (others => '0');

  -- Read pointer (gray code) in source clock domain
  signal   s_gray_rd : std_logic_vector(C_GRAY_SIZE - 1 downto 0)      := (others => '0');

  -- Handle CDC
  -- There must additionally be an explicit set_max_delay in the constraint file.
  signal   m_gray_wr_meta : std_logic_vector(C_GRAY_SIZE - 1 downto 0) := (others => '0');
  signal   s_gray_rd_meta : std_logic_vector(C_GRAY_SIZE - 1 downto 0) := (others => '0');
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

    for i in b'left-1 downto b'right loop
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

    for i in g'left-1 downto g'right loop
      b_v(i) := b_v(i + 1) xor g(i);
    end loop;

    return b_v;
  end function gray2unsigned;

begin

  assert C_PIPE_SIZE = G_PIPE_SIZE
    report "G_PIPE_SIZE must be a power of 2";


  -----------------------------------------------------------
  -- Input flow control
  -----------------------------------------------------------

  s_ready_o <= '1' when s_gray_wr(C_GRAY_SIZE - 1) = s_gray_rd(C_GRAY_SIZE - 1) else
               '0';


  -----------------------------------------------------------
  -- Update write pointer
  -----------------------------------------------------------

  s_proc : process (s_clk_i)
    variable index_v : natural range 0 to C_PIPE_SIZE - 1;
  begin
    if rising_edge(s_clk_i) then
      if s_valid_i = '1' and s_ready_o = '1' then
        s_gray_wr <= unsigned2gray(gray2unsigned(s_gray_wr) + 1);
      end if;
    end if;
  end process s_proc;


  -----------------------------------------------------------
  -- Dual port memory: One write port, and one read port.
  -- The memory is implemented with LUTRAM. There is no
  -- need for a complete CDC circuit on the output of the LUTRAM, a simple
  -- flip-flop is sufficient. This is because the contents being read from the LUTRAM is
  -- not changing at the time it is sampled. This is due to the CDC causing a (usually) two-cycle
  -- delay between writing to and reading from a given memory location.
  -----------------------------------------------------------

  dpram_proc : process (s_clk_i, m_clk_i)
    variable index_v : natural range 0 to C_PIPE_SIZE - 1;
  begin
    -- Write to memory
    if rising_edge(s_clk_i) then
      if s_valid_i = '1' and s_ready_o = '1' then
        index_v        := to_integer(gray2unsigned(s_gray_wr)) mod C_PIPE_SIZE;
        dpram(index_v) <= s_data_i;
      end if;
    end if;

    -- Read from memory
    if rising_edge(m_clk_i) then
      if m_gray_wr /= m_gray_rd and (m_ready_i = '1' or m_valid_o = '0') then
        index_v  := to_integer(gray2unsigned(m_gray_rd)) mod C_PIPE_SIZE;
        m_data_o <= dpram(index_v);
      end if;
    end if;
  end process dpram_proc;


  -----------------------------------------------------------
  -- Handle CDC explicitly.
  -- We won't use the Xilinx XPM primitive, because that includes a set_false_path.
  -- Instead, we use a set_max_delay in the constraints.
  -----------------------------------------------------------

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


  -----------------------------------------------------------
  -- Forward data, one word at a time, as soon as the write pointer is different from
  -- the read pointer.
  -----------------------------------------------------------

  m_proc : process (m_clk_i)
    variable index_v : natural range 0 to C_PIPE_SIZE - 1;
  begin
    if rising_edge(m_clk_i) then
      if m_ready_i = '1' then
        m_valid_o <= '0';
      end if;

      if m_gray_wr /= m_gray_rd and (m_ready_i = '1' or m_valid_o = '0') then
        m_gray_rd <= unsigned2gray(gray2unsigned(m_gray_rd) + 1);
        m_valid_o <= '1';
      end if;
    end if;
  end process m_proc;

end architecture synthesis;

