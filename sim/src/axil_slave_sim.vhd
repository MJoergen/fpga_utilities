-- ----------------------------------------------------------------------------
-- Author     : Michael Jørgensen
-- Platform   : simulation
-- ----------------------------------------------------------------------------
-- Description: This simulates an AXI lite slave.
-- It emulates a simple RAM and responds to Write and Read requests.
-- ----------------------------------------------------------------------------

library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std_unsigned.all;

entity axil_slave_sim is
  generic (
    G_DEBUG     : boolean;
    G_FAST      : boolean;
    G_ADDR_SIZE : natural;
    G_DATA_SIZE : natural
  );
  port (
    clk_i       : in    std_logic;
    rst_i       : in    std_logic;

    s_awready_o : out   std_logic;
    s_awvalid_i : in    std_logic;
    s_awaddr_i  : in    std_logic_vector(G_ADDR_SIZE - 1 downto 0);
    s_awid_i    : in    std_logic_vector(7 downto 0);
    s_wready_o  : out   std_logic;
    s_wvalid_i  : in    std_logic;
    s_wdata_i   : in    std_logic_vector(G_DATA_SIZE - 1 downto 0);
    s_wstrb_i   : in    std_logic_vector(G_DATA_SIZE / 8 - 1 downto 0);
    s_bready_i  : in    std_logic;
    s_bvalid_o  : out   std_logic;
    s_bid_o     : out   std_logic_vector(7 downto 0);
    s_arready_o : out   std_logic;
    s_arvalid_i : in    std_logic;
    s_araddr_i  : in    std_logic_vector(G_ADDR_SIZE - 1 downto 0);
    s_arid_i    : in    std_logic_vector(7 downto 0);
    s_rready_i  : in    std_logic;
    s_rvalid_o  : out   std_logic;
    s_rdata_o   : out   std_logic_vector(G_DATA_SIZE - 1 downto 0);
    s_rid_o     : out   std_logic_vector(7 downto 0)
  );
end entity axil_slave_sim;

architecture simulation of axil_slave_sim is

  signal s_awaddr  : std_logic_vector(G_ADDR_SIZE - 1 downto 0);
  signal s_awid    : std_logic_vector(7 downto 0);
  signal s_awvalid : std_logic;
  signal s_wdata   : std_logic_vector(G_DATA_SIZE - 1 downto 0);
  signal s_wstrb   : std_logic_vector(G_DATA_SIZE / 8 - 1 downto 0);
  signal s_wvalid  : std_logic;

  type   ram_type is array (natural range <>) of std_logic_vector(G_DATA_SIZE - 1 downto 0);

begin

  -- Only receive one write address and/or write data at a time
  s_awready_o <= not s_awvalid;
  s_wready_o  <= not s_wvalid;

  -- Only accept one read request at a time
  s_arready_o <= (not s_rvalid_o) or s_rready_i when G_FAST else
                 (not s_rvalid_o);

  verify_proc : process (clk_i)
    variable ram_v : ram_type(0 to 2 ** G_ADDR_SIZE - 1);
  begin
    if rising_edge(clk_i) then
      if s_bready_i = '1' then
        s_bvalid_o <= '0';
      end if;
      if s_rready_i = '1' then
        s_rvalid_o <= '0';
      end if;

      -- Wait for write address
      if s_awready_o = '1' and s_awvalid_i = '1' then
        s_awaddr  <= s_awaddr_i;
        s_awid    <= s_awid_i;
        s_awvalid <= '1';
      end if;

      -- Wait for write data
      if s_wready_o = '1' and s_wvalid_i = '1' then
        s_wdata  <= s_wdata_i;
        s_wstrb  <= s_wstrb_i;
        s_wvalid <= '1';
      end if;

      -- Handle write
      if s_awvalid = '1' and s_wvalid = '1' and ((s_bready_i = '1' and G_FAST) or s_bvalid_o = '0') then
        if G_DEBUG then
          report "axil_sim: VERIFY: Write " & to_hstring(s_wdata) & " to " & to_hstring(s_awaddr);
        end if;
        ram_v(to_integer(s_awaddr)) := s_wdata;
        s_awvalid                   <= '0';
        s_wvalid                    <= '0';
        s_bvalid_o                  <= '1';
        s_bid_o                     <= s_awid;
      end if;

      -- Handle read
      if s_arready_o = '1' and s_arvalid_i = '1' then
        if G_DEBUG then
          report "axil_sim: VERIFY: Reading " & to_hstring(ram_v(to_integer(s_araddr_i))) & " from " & to_hstring(s_araddr_i);
        end if;
        s_rdata_o  <= ram_v(to_integer(s_araddr_i));
        s_rvalid_o <= '1';
        s_rid_o    <= s_arid_i;
      end if;

      if rst_i = '1' then
        ram_v      := (others => (others => 'U'));
        s_awvalid  <= '0';
        s_wvalid   <= '0';
        s_bvalid_o <= '0';
        s_rvalid_o <= '0';
      end if;
    end if;
  end process verify_proc;

end architecture simulation;

