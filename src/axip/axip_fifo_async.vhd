library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std_unsigned.all;

library xpm;
  use xpm.vcomponents.all;

entity axip_fifo_async is
  generic (
    G_DEPTH      : positive;
    G_FILL_SIZE  : positive;
    G_DATA_BYTES : positive
  );
  port (
    s_clk_i   : in    std_logic;
    s_rst_i   : in    std_logic;
    s_ready_o : out   std_logic;
    s_valid_i : in    std_logic;
    s_data_i  : in    std_logic_vector(G_DATA_BYTES * 8 - 1 downto 0);
    s_last_i  : in    std_logic;
    s_bytes_i : in    natural range 0 to G_DATA_BYTES;
    s_fill_o  : out   std_logic_vector(G_FILL_SIZE - 1 downto 0);
    m_clk_i   : in    std_logic;
    m_ready_i : in    std_logic;
    m_valid_o : out   std_logic;
    m_data_o  : out   std_logic_vector(G_DATA_BYTES * 8 - 1 downto 0);
    m_last_o  : out   std_logic;
    m_bytes_o : out   natural range 0 to G_DATA_BYTES;
    m_fill_o  : out   std_logic_vector(G_FILL_SIZE - 1 downto 0)
  );
end entity axip_fifo_async;

architecture synthesis of axip_fifo_async is

  pure function keep2bytes (
    keep : std_logic_vector
  ) return natural is
  begin
    for i in 0 to G_DATA_BYTES - 1 loop
      if keep(i) = '0' then
        return i;
      end if;
    end loop;
    return G_DATA_BYTES;
  end function keep2bytes;

  pure function bytes2keep (
    bytes : natural range 0 to G_DATA_BYTES
  ) return std_logic_vector is
    variable ret_v : std_logic_vector(G_DATA_BYTES - 1 downto 0);
  begin
    for i in 0 to G_DATA_BYTES - 1 loop
      if i < bytes then
        ret_v(i) := '1';
      else
        ret_v(i) := '0';
      end if;
    end loop;
    return ret_v;
  end function bytes2keep;

begin

  xpm_fifo_axis_inst : component xpm_fifo_axis
    generic map (
      CDC_SYNC_STAGES     => 2,
      CLOCKING_MODE       => "independent_clock",
      ECC_MODE            => "no_ecc",
      FIFO_DEPTH          => G_DEPTH,
      FIFO_MEMORY_TYPE    => "auto",
      PACKET_FIFO         => "false",
      PROG_EMPTY_THRESH   => 10,
      PROG_FULL_THRESH    => 10,
      RD_DATA_COUNT_WIDTH => G_FILL_SIZE,
      RELATED_CLOCKS      => 0,
      SIM_ASSERT_CHK      => 0,
      TDATA_WIDTH         => G_DATA_BYTES * 8,
      TDEST_WIDTH         => 1,
      TID_WIDTH           => 1,
      TUSER_WIDTH         => 1,
      USE_ADV_FEATURES    => "1404",
      WR_DATA_COUNT_WIDTH => G_FILL_SIZE
    )
    port map (
      almost_empty_axis        => open,
      almost_full_axis         => open,
      dbiterr_axis             => open,
      injectdbiterr_axis       => '0',
      injectsbiterr_axis       => '0',
      m_aclk                   => m_clk_i,
      m_axis_tdata             => m_data_o,
      m_axis_tdest             => open,
      m_axis_tid               => open,
      keep2bytes(m_axis_tkeep) => m_bytes_o,
      m_axis_tlast             => m_last_o,
      m_axis_tready            => m_ready_i,
      m_axis_tstrb             => open,
      m_axis_tuser             => open,
      m_axis_tvalid            => m_valid_o,
      prog_empty_axis          => open,
      prog_full_axis           => open,
      rd_data_count_axis       => m_fill_o,
      s_aclk                   => s_clk_i,
      s_aresetn                => not s_rst_i,
      s_axis_tdata             => s_data_i,
      s_axis_tdest             => (others => '0'),
      s_axis_tid               => (others => '0'),
      s_axis_tkeep             => bytes2keep(s_bytes_i),
      s_axis_tlast             => s_last_i,
      s_axis_tready            => s_ready_o,
      s_axis_tstrb             => (others => '0'),
      s_axis_tuser             => s_user_i,
      s_axis_tvalid            => s_valid_i,
      sbiterr_axis             => open,
      wr_data_count_axis       => s_fill_o
    ); -- xpm_fifo_axis_inst

end architecture synthesis;

