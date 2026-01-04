-- ----------------------------------------------------------------------------
-- Author     : Michael Jørgensen
-- Platform   : AMD Artix 7
-- ----------------------------------------------------------------------------
-- Description: Determine whether we are waiting on one of AW and W data.
-- ----------------------------------------------------------------------------

library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std.all;

entity axil_busy is
  port (
    clk_i     : in    std_logic;
    rst_i     : in    std_logic;

    -- Input
    awready_i : in    std_logic;
    awvalid_i : in    std_logic;
    wready_i  : in    std_logic;
    wvalid_i  : in    std_logic;

    busy_o    : out   std_logic
  );
end entity axil_busy;

architecture synthesis of axil_busy is

  signal aw_accept : std_logic;
  signal w_accept  : std_logic;

  type   state_type is (IDLE_ST, AW_BUSY_ST, W_BUSY_ST);
  signal state : state_type := IDLE_ST;

begin

  busy_o    <= '0' when state = IDLE_ST else
               '1';

  aw_accept <= awvalid_i and awready_i;
  w_accept  <= wvalid_i and wready_i;

  state_proc : process (clk_i)
  begin
    if rising_edge(clk_i) then

      case state is

        when IDLE_ST =>
          if aw_accept = '1' and w_accept = '0' then
            state <= AW_BUSY_ST;
          end if;

          if aw_accept = '0' and w_accept = '1' then
            state <= W_BUSY_ST;
          end if;

        when AW_BUSY_ST =>
          if aw_accept = '0' and w_accept = '1' then
            state <= IDLE_ST;
          end if;

        when W_BUSY_ST =>
          if aw_accept = '1' and w_accept = '0' then
            state <= IDLE_ST;
          end if;

      end case;

      if rst_i = '1' then
        state <= IDLE_ST;
      end if;
    end if;
  end process state_proc;

end architecture synthesis;

