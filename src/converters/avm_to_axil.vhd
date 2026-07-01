library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std.all;

-- This allows a Avalon Master to be connected to an AXI Slave

entity avm_to_axil is
  generic (
    G_ADDR_BITS  : positive;
    G_DATA_BITS  : positive;
    G_BURST_BITS : positive := 8
  );
  port (
    clk_i             : in    std_logic;
    rst_i             : in    std_logic;

    -- Avalon Memory Map interface (slave)
    s_waitrequest_o   : out   std_logic;
    s_write_i         : in    std_logic;
    s_read_i          : in    std_logic;
    s_address_i       : in    std_logic_vector(G_ADDR_BITS - 1 downto 0);
    s_writedata_i     : in    std_logic_vector(G_DATA_BITS - 1 downto 0);
    s_byteenable_i    : in    std_logic_vector(G_DATA_BITS / 8 - 1 downto 0);
    s_burstcount_i    : in    std_logic_vector(G_BURST_BITS - 1 downto 0);
    s_readdatavalid_o : out   std_logic;
    s_readdata_o      : out   std_logic_vector(G_DATA_BITS - 1 downto 0);

    -- AXI Lite interface (master)
    m_awready_i       : in    std_logic;
    m_awvalid_o       : out   std_logic;
    m_awaddr_o        : out   std_logic_vector(G_ADDR_BITS - 1 downto 0);
    m_wready_i        : in    std_logic;
    m_wvalid_o        : out   std_logic;
    m_wdata_o         : out   std_logic_vector(G_DATA_BITS - 1 downto 0);
    m_wstrb_o         : out   std_logic_vector(G_DATA_BITS / 8 - 1 downto 0);
    m_bready_o        : out   std_logic;
    m_bvalid_i        : in    std_logic;
    m_bresp_i         : in    std_logic_vector(1 downto 0);
    m_arready_i       : in    std_logic;
    m_arvalid_o       : out   std_logic;
    m_araddr_o        : out   std_logic_vector(G_ADDR_BITS - 1 downto 0);
    m_rready_o        : out   std_logic;
    m_rvalid_i        : in    std_logic;
    m_rdata_i         : in    std_logic_vector(G_DATA_BITS - 1 downto 0);
    m_rresp_i         : in    std_logic_vector(1 downto 0)
  );
end entity avm_to_axil;

architecture rtl of avm_to_axil is

  signal alm_awvalid  : std_logic;
  signal alm_awaddr   : std_logic_vector(G_ADDR_BITS - 1 downto 0);
  signal alm_wvalid   : std_logic;
  signal alm_wdata    : std_logic_vector(G_DATA_BITS - 1 downto 0);
  signal alm_wstrb    : std_logic_vector(G_DATA_BITS / 8 - 1 downto 0);

  signal avs_readdata      : std_logic_vector(G_DATA_BITS - 1 downto 0);
  signal avs_readdatavalid : std_logic;
  signal alm_arvalid       : std_logic;
  signal alm_araddr        : std_logic_vector(G_ADDR_BITS - 1 downto 0);

begin

  s_waitrequest_o   <= '1' when m_awvalid_o = '1' and m_awready_i = '0' else
                       '1' when m_wvalid_o = '1' and m_wready_i = '0' else
                       '0';

  -- Handle write

  m_awvalid_o       <= alm_awvalid;
  m_awaddr_o        <= alm_awaddr;
  m_wvalid_o        <= alm_wvalid;
  m_wdata_o         <= alm_wdata;
  m_wstrb_o         <= alm_wstrb;
  m_bready_o        <= '1';

  write_proc : process (clk_i)
  begin
    if rising_edge(clk_i) then
      if m_awready_i = '1' then
        alm_awvalid <= '0';
      end if;

      if m_wready_i = '1' then
        alm_wvalid <= '0';
      end if;

      if m_wready_i = '1' then
        alm_wvalid <= '0';
      end if;

      if s_write_i = '1' and s_waitrequest_o = '0' then
        alm_awaddr  <= s_address_i;
        alm_awvalid <= '1';
        alm_wdata   <= s_writedata_i;
        alm_wvalid  <= '1';
        alm_wstrb   <= s_byteenable_i;
      end if;
    end if;
  end process write_proc;


  -- Handle read

  s_readdata_o      <= avs_readdata;
  s_readdatavalid_o <= avs_readdatavalid;
  m_rready_o        <= '1';
  m_arvalid_o       <= alm_arvalid;
  m_araddr_o        <= alm_araddr;

  r_proc : process (clk_i)
  begin
    if rising_edge(clk_i) then
      if m_arready_i = '1' then
        alm_arvalid <= '0';
      end if;

      if s_read_i = '1' and s_waitrequest_o = '0' then
        alm_araddr  <= s_address_i;
        alm_arvalid <= '1';
      end if;
    end if;
  end process r_proc;

  read_proc : process (clk_i)
  begin
    if rising_edge(clk_i) then
      avs_readdatavalid <= '0';

      if m_rvalid_i = '1' and m_rready_o = '1' then
        avs_readdata      <= m_rdata_i;
        avs_readdatavalid <= '1';
      end if;
    end if;
  end process read_proc;

end architecture rtl;

