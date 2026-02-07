-- ---------------------------------------------------------------------------------------
-- Description: This module inserts empty wait cycles into an Avalon interface.
-- ---------------------------------------------------------------------------------------

library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std_unsigned.all;

library work;
  use work.avm_pkg.all;

entity avm_pause is
  generic (
    G_SEED       : std_logic_vector(63 downto 0) := x"12345678AABBCCDD";
    G_PAUSE_SIZE : natural
  );
  port (
    clk_i : in    std_logic;
    rst_i : in    std_logic;
    s_avm : view avm_slave_view;
    m_avm : view avm_master_view
  );
end entity avm_pause;

architecture synthesis of avm_pause is

  signal   random_s : std_logic_vector(63 downto 0);

  subtype  R_REQ_PAUSE is natural range 20 downto 0;

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
  req_delay           <= to_integer(random_s(R_REQ_PAUSE)) mod (G_PAUSE_SIZE + 1);
  resp_delay          <= to_integer(random_s(R_RESP_PAUSE)) mod (G_PAUSE_SIZE + 1);


  ---------------------------------------
  -- Handle read burst
  ---------------------------------------

  rd_burstcount_proc : process (clk_i)
  begin
    if rising_edge(clk_i) then
      if s_avm.readdatavalid then
        assert rst_i = '1' or rd_burstcount /= 0
          report "avm_pause: s_readdatavalid_o asserted when rd_burstcount = 0";
        rd_burstcount <= rd_burstcount - 1;
      end if;

      if s_avm.read and not s_avm.waitrequest then
        rd_burstcount <= to_integer(s_avm.burstcount);
      end if;

      if rst_i = '1' then
        rd_burstcount <= 0;
      end if;
    end if;
  end process rd_burstcount_proc;


  ---------------------------------------
  -- Insert random pauses in requests
  ---------------------------------------

  allow               <= '0' when req_delay /= 0 else
                         '0' when rd_burstcount /= 0 else
                         '1';

  m_avm.write         <= s_avm.write and allow;
  m_avm.read          <= s_avm.read and allow;
  m_avm.address       <= s_avm.address;
  m_avm.writedata     <= s_avm.writedata;
  m_avm.byteenable    <= s_avm.byteenable;
  m_avm.burstcount    <= s_avm.burstcount;
  s_avm.waitrequest   <= m_avm.waitrequest or not allow;


  ---------------------------------------
  -- Handle response
  ---------------------------------------

  resp_proc : process (clk_i)
  begin
    if rising_edge(clk_i) then
      s_readdatavalid <= '0' & s_readdatavalid(s_readdatavalid'left downto 1);
      if m_avm.readdatavalid = '1' then
        assert s_readdatavalid = C_ZERO
          report "avm_pause: s_readdatavalid not zero: " & to_hstring(s_readdatavalid);
        s_avm.readdata              <= m_avm.readdata;
        -- Insert a random delay in response
        s_readdatavalid(resp_delay) <= '1';
      end if;

      if rst_i = '1' then
        s_readdatavalid <= (others => '0');
      end if;
    end if;
  end process resp_proc;

  s_avm.readdatavalid <= s_readdatavalid(0);

end architecture synthesis;

