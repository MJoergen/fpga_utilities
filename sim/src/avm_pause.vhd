-- ---------------------------------------------------------------------------------------
-- Description: This module inserts empty wait cycles into an Avalon interface.
--
-- SPDX-License-Identifier: MIT
-- ---------------------------------------------------------------------------------------

library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std_unsigned.all;

entity avm_pause is
  generic (
    G_BURST_BITS : natural                       := 8;
    G_MAX_BURST   : natural                       := 8;
    G_SEED        : std_logic_vector(63 downto 0) := X"12345678AABBCCDD";
    G_PAUSE_SIZE  : natural;
    G_ADDR_BITS   : natural;
    G_DATA_BITS   : natural
  );
  port (
    clk_i             : in    std_logic;
    rst_i             : in    std_logic;
    -- Input
    s_waitrequest_o   : out   std_logic;
    s_write_i         : in    std_logic;
    s_read_i          : in    std_logic;
    s_address_i       : in    std_logic_vector(G_ADDR_BITS - 1 downto 0);
    s_writedata_i     : in    std_logic_vector(G_DATA_BITS - 1 downto 0);
    s_byteenable_i    : in    std_logic_vector(G_DATA_BITS / 8 - 1 downto 0);
    s_burstcount_i    : in    std_logic_vector(G_BURST_BITS - 1 downto 0);
    s_readdatavalid_o : out   std_logic;
    s_readdata_o      : out   std_logic_vector(G_DATA_BITS - 1 downto 0);
    -- Output
    m_waitrequest_i   : in    std_logic;
    m_write_o         : out   std_logic;
    m_read_o          : out   std_logic;
    m_address_o       : out   std_logic_vector(G_ADDR_BITS - 1 downto 0);
    m_writedata_o     : out   std_logic_vector(G_DATA_BITS - 1 downto 0);
    m_byteenable_o    : out   std_logic_vector(G_DATA_BITS / 8 - 1 downto 0);
    m_burstcount_o    : out   std_logic_vector(G_BURST_BITS - 1 downto 0);
    m_readdatavalid_i : in    std_logic;
    m_readdata_i      : in    std_logic_vector(G_DATA_BITS - 1 downto 0)
  );
end entity avm_pause;

architecture rtl of avm_pause is

  signal  random_s : std_logic_vector(63 downto 0);

  subtype R_REQ_PAUSE  is natural range 20 downto 0;
  subtype R_RESP_PAUSE is natural range 30 downto 10;

  signal  req_delay  : natural range 0 to G_PAUSE_SIZE;
  signal  resp_delay : natural range 0 to G_PAUSE_SIZE;

  signal  wr_burstcount : std_logic_vector(G_BURST_BITS - 1 downto 0) := (others => '0');
  signal  rd_burstcount : std_logic_vector(G_BURST_BITS - 1 downto 0) := (others => '0');
  signal  allow         : std_logic;

  signal  axis_s_ready : std_logic;
  signal  axis_s_valid : std_logic;
  signal  axis_s_data  : std_logic_vector(G_DATA_BITS - 1 downto 0);
  signal  axis_m_ready : std_logic;
  signal  axis_m_valid : std_logic;
  signal  axis_m_data  : std_logic_vector(G_DATA_BITS - 1 downto 0);
  signal  axis_fill    : natural range 0 to G_MAX_BURST;

begin

  ---------------------------------------
  -- Instantiate randon number generator
  ---------------------------------------

  random_inst : entity work.random
    generic map (
      G_SEED => G_SEED
    )
    port map (
      clk_i    => clk_i,
      rst_i    => rst_i,
      update_i => '1',
      output_o => random_s
    ); -- random_inst : entity work.random

  -- Calculate random delays
  req_delay       <= to_integer(random_s(R_REQ_PAUSE)) mod (G_PAUSE_SIZE + 1);
  resp_delay      <= to_integer(random_s(R_RESP_PAUSE)) mod (G_PAUSE_SIZE + 1);


  ---------------------------------------
  -- Handle write burst
  ---------------------------------------

  wr_burstcount_proc : process (clk_i)
  begin
    if rising_edge(clk_i) then
      if s_write_i = '1' and s_waitrequest_o = '0' then
        if wr_burstcount > 0 then
          wr_burstcount <= wr_burstcount - 1;
        else
          assert s_burstcount_i > 0;
          wr_burstcount <= s_burstcount_i - 1;
        end if;
      end if;

      if rst_i = '1' then
        wr_burstcount <= (others => '0');
      end if;
    end if;
  end process wr_burstcount_proc;


  ---------------------------------------
  -- Handle read burst
  ---------------------------------------

  rd_burstcount_proc : process (clk_i)
  begin
    if rising_edge(clk_i) then
      if s_readdatavalid_o = '1' then
        assert rst_i = '1' or rd_burstcount /= 0
          report "avm_pause: s_readdatavalid_o asserted when rd_burstcount = 0";
        rd_burstcount <= rd_burstcount - 1;
      end if;

      if s_read_i = '1' and s_waitrequest_o = '0' then
        assert s_burstcount_i > 0;
        rd_burstcount <= s_burstcount_i;
      end if;

      if rst_i = '1' then
        rd_burstcount <= (others => '0');
      end if;
    end if;
  end process rd_burstcount_proc;


  ---------------------------------------
  -- Insert random pauses in requests
  ---------------------------------------

  allow           <= '1' when wr_burstcount /= 0 else
                     '0' when req_delay /= 0 else
                     '0' when rd_burstcount /= 0 else
                     '1';

  m_write_o       <= s_write_i and allow;
  m_read_o        <= s_read_i and allow;
  m_address_o     <= s_address_i;
  m_writedata_o   <= s_writedata_i;
  m_byteenable_o  <= s_byteenable_i;
  m_burstcount_o  <= s_burstcount_i;
  s_waitrequest_o <= m_waitrequest_i or not allow;


  ---------------------------------------
  -- Handle response
  ---------------------------------------

  pause_gen : if G_PAUSE_SIZE > 0 generate

    assert s_waitrequest_o = '1' or axis_fill = 0;

    axis_fifo_inst : entity work.axis_fifo
      generic map (
        G_RAM_DEPTH => G_MAX_BURST + 1,
        G_DATA_BITS => G_DATA_BITS
      )
      port map (
        clk_i     => clk_i,
        rst_i     => rst_i,
        fill_o    => axis_fill,
        s_ready_o => axis_s_ready,
        s_valid_i => axis_s_valid,
        s_data_i  => axis_s_data,
        m_ready_i => axis_m_ready,
        m_valid_o => axis_m_valid,
        m_data_o  => axis_m_data
      );

    axis_s_valid      <= m_readdatavalid_i;
    axis_s_data       <= m_readdata_i;

    axis_m_ready      <= '1' when resp_delay = 0 else
                         '0';

    resp_proc : process (clk_i)
    begin
      if rising_edge(clk_i) then
        if m_readdatavalid_i = '1' then
          assert axis_s_ready = '1'
            report "avm_pause: read fifo full"
              severity failure;
        end if;

        s_readdatavalid_o <= '0';

        if axis_m_valid = '1' and axis_m_ready = '1' then
          s_readdata_o      <= axis_m_data;
          s_readdatavalid_o <= '1';
        end if;

        if rst_i = '1' then
          s_readdatavalid_o <= '0';
        end if;
      end if;
    end process resp_proc;

  else generate
    s_readdata_o      <= m_readdata_i;
    s_readdatavalid_o <= m_readdatavalid_i;

  end generate pause_gen;

end architecture rtl;

