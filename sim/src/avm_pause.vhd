-- ---------------------------------------------------------------------------------------
-- Description: This module inserts empty wait cycles into an Avalon interface.
-- ---------------------------------------------------------------------------------------

library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std_unsigned.all;

entity avm_pause is
  generic (
    G_SEED       : std_logic_vector(63 downto 0) := X"12345678AABBCCDD";
    G_PAUSE_SIZE : natural;
    G_ADDR_SIZE  : natural;
    G_DATA_SIZE  : natural
  );
  port (
    clk_i             : in    std_logic;
    rst_i             : in    std_logic;
    -- Input
    s_write_i         : in    std_logic;
    s_read_i          : in    std_logic;
    s_address_i       : in    std_logic_vector(G_ADDR_SIZE - 1 downto 0);
    s_writedata_i     : in    std_logic_vector(G_DATA_SIZE - 1 downto 0);
    s_byteenable_i    : in    std_logic_vector(G_DATA_SIZE / 8 - 1 downto 0);
    s_burstcount_i    : in    std_logic_vector(7 downto 0);
    s_readdata_o      : out   std_logic_vector(G_DATA_SIZE - 1 downto 0);
    s_readdatavalid_o : out   std_logic;
    s_waitrequest_o   : out   std_logic;
    -- Output
    m_write_o         : out   std_logic;
    m_read_o          : out   std_logic;
    m_address_o       : out   std_logic_vector(G_ADDR_SIZE - 1 downto 0);
    m_writedata_o     : out   std_logic_vector(G_DATA_SIZE - 1 downto 0);
    m_byteenable_o    : out   std_logic_vector(G_DATA_SIZE / 8 - 1 downto 0);
    m_burstcount_o    : out   std_logic_vector(7 downto 0);
    m_readdata_i      : in    std_logic_vector(G_DATA_SIZE - 1 downto 0);
    m_readdatavalid_i : in    std_logic;
    m_waitrequest_i   : in    std_logic
  );
end entity avm_pause;

architecture synthesis of avm_pause is

  signal   random_s : std_logic_vector(63 downto 0);

  subtype  R_REQ_PAUSE  is natural range 20 downto 0;
  subtype  R_RESP_PAUSE is natural range 30 downto 10;

  signal   req_delay  : natural range 0 to G_PAUSE_SIZE;
  signal   resp_delay : natural range 0 to G_PAUSE_SIZE;

  signal   rd_burstcount : natural range 0 to 255;
  signal   allow         : std_logic;

  signal   s_readdatavalid : std_logic_vector(G_PAUSE_SIZE downto 0);
  constant C_ZERO          : std_logic_vector(G_PAUSE_SIZE downto 0) := (others => '0');

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
  req_delay         <= to_integer(random_s(R_REQ_PAUSE)) mod G_PAUSE_SIZE;
  resp_delay        <= to_integer(random_s(R_RESP_PAUSE)) mod G_PAUSE_SIZE;


  ---------------------------------------
  -- Handle read burst
  ---------------------------------------

  rd_burstcount_proc : process (clk_i)
  begin
    if rising_edge(clk_i) then
      if s_readdatavalid_o then
        assert rst_i = '1' or rd_burstcount /= 0
          report "avm_pause: s_readdatavalid_o asserted when rd_burstcount = 0";
        rd_burstcount <= rd_burstcount - 1;
      end if;

      if s_read_i and not s_waitrequest_o then
        rd_burstcount <= to_integer(s_burstcount_i);
      end if;

      if rst_i = '1' then
        rd_burstcount <= 0;
      end if;
    end if;
  end process rd_burstcount_proc;


  ---------------------------------------
  -- Insert random pauses in requests
  ---------------------------------------

  allow             <= '0' when req_delay = 0 else
                       '0' when rd_burstcount /= 0 else
                       '1';

  m_write_o         <= s_write_i and allow;
  m_read_o          <= s_read_i and allow;
  m_address_o       <= s_address_i;
  m_writedata_o     <= s_writedata_i;
  m_byteenable_o    <= s_byteenable_i;
  m_burstcount_o    <= s_burstcount_i;
  s_waitrequest_o   <= m_waitrequest_i or not allow;


  ---------------------------------------
  -- Handle response
  ---------------------------------------

  resp_proc : process (clk_i)
  begin
    if rising_edge(clk_i) then
      s_readdatavalid <= '0' & s_readdatavalid(s_readdatavalid'left downto 1);
      if m_readdatavalid_i = '1' then
        assert s_readdatavalid = C_ZERO
          report "avm_pause: s_readdatavalid not zero: " & to_hstring(s_readdatavalid);
        s_readdata_o                <= m_readdata_i;
        -- Insert a random delay in response
        s_readdatavalid(resp_delay) <= '1';
      end if;

      if rst_i = '1' then
        s_readdatavalid <= (others => '0');
      end if;
    end if;
  end process resp_proc;

  s_readdatavalid_o <= s_readdatavalid(0);

end architecture synthesis;

