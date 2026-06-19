-- ---------------------------------------------------------------------------------------
-- Description: Verify avm_readahead
-- ---------------------------------------------------------------------------------------

library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std.all;

library work;
  use work.avm_scoreboard_pkg.all;

entity avm_scoreboard is
  generic (
    G_BURST_WIDTH  : positive;
    G_ADDRESS_SIZE : positive;
    G_DATA_SIZE    : positive
  );
  port (
    clk_i                 : in    std_logic;
    rst_i                 : in    std_logic;

    -- Avalon-MM slave interface (client-facing)
    s_avm_waitrequest_i   : in    std_logic;
    s_avm_write_i         : in    std_logic;
    s_avm_read_i          : in    std_logic;
    s_avm_address_i       : in    std_logic_vector(G_ADDRESS_SIZE - 1 downto 0);
    s_avm_writedata_i     : in    std_logic_vector(G_DATA_SIZE - 1 downto 0);
    s_avm_byteenable_i    : in    std_logic_vector(G_DATA_SIZE / 8 - 1 downto 0);
    s_avm_burstcount_i    : in    std_logic_vector(G_BURST_WIDTH - 1 downto 0);
    s_avm_readdata_i      : in    std_logic_vector(G_DATA_SIZE - 1 downto 0);
    s_avm_readdatavalid_i : in    std_logic
  );
end entity avm_scoreboard;

architecture simulation of avm_scoreboard is

  shared variable sb_v : avm_scoreboard_type;

begin

  ---------------------------------------------------------------------------
  -- Scoreboard setup
  ---------------------------------------------------------------------------
  tb_init_proc : process
  begin
    sb_v.configure(
                   data_width     => G_DATA_SIZE,
                   address_modulo => 2 ** G_ADDRESS_SIZE,
                   verbose        => false
                 );

    sb_v.init_pattern;

    wait;
  end process tb_init_proc;


  ---------------------------------------------------------------------------
  -- Client-side accepted transaction monitor.
  --
  -- This should observe the same acceptance event as the client BFM:
  --
  --   command accepted when read/write is high and waitrequest is low.
  ---------------------------------------------------------------------------
  client_accept_monitor_proc : process (clk_i)
    variable addr_v       : natural;
    variable burstcount_v : natural;
  begin
    if rising_edge(clk_i) then
      if rst_i = '1' then
        -- Usually no scoreboard reset is needed here if your testbench
        -- configures and initializes it outside reset. If you want reset
        -- to clear the expected queue, expose a dedicated testbench reset
        -- phase and call sb_v.reset/init_pattern there.
        null;
      else
        addr_v       := to_integer(unsigned(s_avm_address_i));
        burstcount_v := to_integer(unsigned(s_avm_burstcount_i));

        if s_avm_write_i = '1' and s_avm_waitrequest_i = '0' then
          sb_v.accept_write(
                            addr       => addr_v,
                            writedata  => s_avm_writedata_i,
                            byteenable => s_avm_byteenable_i
                          );
        end if;

        if s_avm_read_i = '1' and s_avm_waitrequest_i = '0' then
          sb_v.accept_read(
                           addr       => addr_v,
                           burstcount => burstcount_v
                         );
        end if;
      end if;
    end if;
  end process client_accept_monitor_proc;


  ---------------------------------------------------------------------------
  -- Client-side read data monitor.
  ---------------------------------------------------------------------------
  client_readdata_monitor_proc : process (clk_i)
  begin
    if rising_edge(clk_i) then
      if rst_i = '0' then
        if s_avm_readdatavalid_i = '1' then
          sb_v.check_readdata(s_avm_readdata_i);
        end if;
      end if;
    end if;
  end process client_readdata_monitor_proc;

end architecture simulation;

