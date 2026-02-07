-- ---------------------------------------------------------------------------------------
-- Description: This adds pauses into Wishbone requests and responses
-- ---------------------------------------------------------------------------------------

library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std.all;

library work;
  use work.wbus_pkg.all;

entity wbus_pause is
  generic (
    G_SEED       : std_logic_vector(63 downto 0);
    G_PAUSE_SIZE : integer
  );
  port (
    clk_i  : in    std_logic;
    rst_i  : in    std_logic;
    s_wbus : view  wbus_slave_view;
    m_wbus : view  wbus_master_view
  );
end entity wbus_pause;

architecture simulation of wbus_pause is

  signal  random_val : std_logic_vector(63 downto 0);
  signal  cnt        : natural range 0 to abs(G_PAUSE_SIZE);
  signal  forward    : std_logic;
  signal  update     : std_logic;

  subtype R_PAUSE is natural range 27 downto 0;

  signal  s_ack : std_logic_vector(abs(G_PAUSE_SIZE) downto 0);

begin

  random_inst : entity work.random
    generic map (
      G_SEED => G_SEED
    )
    port map (
      clk_i    => clk_i,
      rst_i    => rst_i,
      update_i => update,
      output_o => random_val
    ); -- random_inst : entity work.random


  cnt    <= 0 when G_PAUSE_SIZE = 0 else
            to_integer(unsigned(random_val(R_PAUSE))) mod abs(G_PAUSE_SIZE);
  update <= '0' when forward = '1' and m_wbus.stb = '1' and m_wbus.stall = '1' else
            '1';

  no_pause_gen : if G_PAUSE_SIZE = 0 generate
    forward <= '1';
  end generate no_pause_gen;

  pause_positive_gen : if G_PAUSE_SIZE > 0 generate
    -- Insert empty cycle when cnt reaches zero.
    forward <= '0' when cnt = 0 else
               '1';
  end generate pause_positive_gen;

  pause_negative_gen : if G_PAUSE_SIZE < 0 generate
    -- Insert empty cycle except when cnt reaches zero.
    forward <= '1' when cnt = 0 else
               '0';
  end generate pause_negative_gen;

  resp_proc : process (clk_i)
  begin
    if rising_edge(clk_i) then
      s_ack <= '0' & s_ack(s_ack'left downto 1);
      if m_wbus.ack = '1' then
        assert or(s_ack) = '0';
        s_wbus.rddat <= m_wbus.rddat;
        s_ack(cnt)   <= '1';
      end if;

      if s_wbus.cyc = '0' then
        s_ack <= (others => '0');
      end if;
    end if;
  end process resp_proc;


  m_wbus.cyc   <= s_wbus.cyc;
  m_wbus.stb   <= s_wbus.stb and forward;
  m_wbus.addr  <= s_wbus.addr;
  m_wbus.we    <= s_wbus.we;
  m_wbus.wrdat <= s_wbus.wrdat;
  s_wbus.stall <= m_wbus.stall or not forward;
  s_wbus.ack   <= s_ack(0) and s_wbus.cyc;

end architecture simulation;

