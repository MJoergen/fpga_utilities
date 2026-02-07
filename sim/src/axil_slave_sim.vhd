-- ---------------------------------------------------------------------------------------
-- Description: This simulates an AXI lite slave.  It emulates a simple RAM and responds
-- to Write and Read requests.
-- ---------------------------------------------------------------------------------------

library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std_unsigned.all;

library work;
  use work.axil_pkg.all;

entity axil_slave_sim is
  generic (
    G_DEBUG : boolean;
    G_FAST  : boolean
  );
  port (
    clk_i  : in    std_logic;
    rst_i  : in    std_logic;
    s_axil : view  axil_slave_view
  );
end entity axil_slave_sim;

architecture simulation of axil_slave_sim is

  signal s_awvalid : std_logic;
  signal s_awaddr  : std_logic_vector(s_axil.awaddr'range);
  signal s_wvalid  : std_logic;
  signal s_wdata   : std_logic_vector(s_axil.wdata'range);
  signal s_wstrb   : std_logic_vector(s_axil.wstrb'range);

  type   ram_type is array (natural range <>) of std_logic_vector(s_axil.wdata'range);

begin

  s_axil.bresp   <= "00";
  s_axil.rresp   <= "00";

  -- Only receive one write address and/or write data at a time
  s_axil.awready <= not s_awvalid;
  s_axil.wready  <= not s_wvalid;

  -- Only accept one read request at a time
  s_axil.arready <= (not s_axil.rvalid) or s_axil.rready when G_FAST else
                    (not s_axil.rvalid);

  verify_proc : process (clk_i)
    variable ram_v : ram_type(0 to 2 ** s_axil.awaddr'length - 1);
  begin
    if rising_edge(clk_i) then
      if s_axil.bready = '1' then
        s_axil.bvalid <= '0';
      end if;
      if s_axil.rready = '1' then
        s_axil.rvalid <= '0';
      end if;

      -- Wait for write address
      if s_axil.awready = '1' and s_axil.awvalid = '1' then
        s_awvalid <= '1';
        s_awaddr  <= s_axil.awaddr;
      end if;

      -- Wait for write data
      if s_axil.wready = '1' and s_axil.wvalid = '1' then
        s_wvalid <= '1';
        s_wdata  <= s_axil.wdata;
        s_wstrb  <= s_axil.wstrb;
      end if;

      -- Handle write
      if s_awvalid = '1' and s_wvalid = '1' and ((s_axil.bready = '1' and G_FAST) or s_axil.bvalid = '0') then
        if G_DEBUG then
          report "axil_sim: VERIFY: Write " & to_hstring(s_wdata) & " to " & to_hstring(s_awaddr);
        end if;
        ram_v(to_integer(s_awaddr)) := s_wdata;
        s_awvalid                   <= '0';
        s_wvalid                    <= '0';
        s_axil.bvalid               <= '1';
      end if;

      -- Handle read
      if s_axil.arready = '1' and s_axil.arvalid = '1' then
        if G_DEBUG then
          report "axil_sim: VERIFY: Reading " & to_hstring(ram_v(to_integer(s_axil.araddr))) &
                 " from " & to_hstring(s_axil.araddr);
        end if;
        s_axil.rdata  <= ram_v(to_integer(s_axil.araddr));
        s_axil.rvalid <= '1';
      end if;

      if rst_i = '1' then
        ram_v         := (others => (others => 'U'));
        s_awvalid     <= '0';
        s_wvalid      <= '0';
        s_axil.bvalid <= '0';
        s_axil.rvalid <= '0';
      end if;
    end if;
  end process verify_proc;

end architecture simulation;

