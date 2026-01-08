-- ----------------------------------------------------------------------------
-- Author     : Michael Jørgensen
-- Platform   : simulation
-- ----------------------------------------------------------------------------
-- Description:
-- This allows a Wishbone Slave to be connected to an Avalon Master
-- ----------------------------------------------------------------------------

library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std_unsigned.all;

entity wbus_slave_sim is
  generic (
    G_SEED      : std_logic_vector(63 downto 0) := X"C007BABEDEADBEEF";
    G_DEBUG     : boolean                       := false;
    G_TIMEOUT   : boolean                       := true;
    G_LATENCY   : natural;
    G_ADDR_SIZE : natural;
    G_DATA_SIZE : natural
  );
  port (
    clk_i     : in    std_logic;
    rst_i     : in    std_logic;
    s_cyc_i   : in    std_logic;
    s_stall_o : out   std_logic;
    s_stb_i   : in    std_logic;
    s_addr_i  : in    std_logic_vector(G_ADDR_SIZE - 1 downto 0);
    s_we_i    : in    std_logic;
    s_wrdat_i : in    std_logic_vector(G_DATA_SIZE - 1 downto 0);
    s_ack_o   : out   std_logic;
    s_rddat_o : out   std_logic_vector(G_DATA_SIZE - 1 downto 0)
  );
end entity wbus_slave_sim;

architecture simulation of wbus_slave_sim is

  type    ram_type is array (natural range <>) of std_logic_vector(G_DATA_SIZE - 1 downto 0);
  signal  ram : ram_type(0 to 2 ** G_ADDR_SIZE - 1);

  signal  random_s : std_logic_vector(63 downto 0);

  subtype R_STALL is natural range 16 downto 15;

  subtype R_LATENCY is natural range 10 downto 0;

  signal  do_latency : natural range 0 to G_LATENCY;
  signal  do_stall   : std_logic;

  signal  s_ack : std_logic_vector(G_LATENCY downto 0);

  signal  req_active : std_logic := '0';

begin

  --------------------------------
  -- Instantiate random number generator
  --------------------------------

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

  do_stall   <= and(random_s(R_STALL));
  do_latency <= to_integer(random_s(R_LATENCY)) mod (G_LATENCY + 1);


  -- Introduce extra stall
  s_stall_o  <= req_active or do_stall;


  --------------------------------
  -- Generate RAM
  --------------------------------

  ram_proc : process (clk_i)
  begin
    if rising_edge(clk_i) then
      s_ack <= s_ack(s_ack'left - 1 downto 0) & '0';
      if s_cyc_i = '1' and s_stall_o = '0' and s_stb_i = '1' and s_we_i = '1' then
        ram(to_integer(s_addr_i)) <= s_wrdat_i;
        s_ack                     <= (others => '0');
        s_ack(do_latency)         <= '1';
        if G_DEBUG then
          report "WBUS SLAVE : Write " & to_hstring(s_wrdat_i) &
                 "   to address " & to_hstring(s_addr_i);
        end if;
      end if;
      if s_cyc_i = '1' and s_stall_o = '0' and s_stb_i = '1' and s_we_i = '0' then
        s_rddat_o         <= ram(to_integer(s_addr_i));
        s_ack             <= (others => '0');
        s_ack(do_latency) <= '1';
        if G_DEBUG then
          report "WBUS SLAVE : Read  " & to_hstring(ram(to_integer(s_addr_i))) &
                 " from address " & to_hstring(s_addr_i);
        end if;
      end if;
      -- Special case: Address zero leads to timeout
      if s_cyc_i = '1' and s_stb_i = '1' and s_addr_i = 0 and G_TIMEOUT then
        s_ack <= (others => '0');
      end if;

      if rst_i = '1' or s_cyc_i = '0' then
        s_ack <= (others => '0');
      end if;
    end if;
  end process ram_proc;

  s_ack_o    <= s_ack(s_ack'left);


  --------------------------------
  -- Monitor requests
  --------------------------------

  assert_proc : process (clk_i)
  begin
    if rising_edge(clk_i) then
      if s_cyc_i = '1' and s_stall_o = '0' and s_stb_i = '1' then
        assert req_active = '0'
          report "wbus_mem_sim: Repeated access received";
        req_active <= '1';
      end if;

      if s_ack_o = '1' then
        assert req_active = '1'
          report "wbus_mem_sim: Missing access";
        req_active <= '0';
      end if;

      if rst_i = '1' or s_cyc_i = '0' then
        req_active <= '0';
      end if;
    end if;
  end process assert_proc;

end architecture simulation;

