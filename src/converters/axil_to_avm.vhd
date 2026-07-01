-- ---------------------------------------------------------------------------------------
-- Description: This allows a Avalon MM Slave to be connected to an AXI Lite Master
--
-- SPDX-License-Identifier: MIT
-- ---------------------------------------------------------------------------------------

library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std.all;

entity axil_to_avm is
  generic (
    G_ADDR_BITS  : positive;
    G_DATA_BITS  : positive;
    G_BURST_BITS : positive := 8
  );
  port (
    clk_i             : in    std_logic;
    rst_i             : in    std_logic;

    -- AXI Lite interface (slave)
    s_awready_o       : out   std_logic;
    s_awvalid_i       : in    std_logic;
    s_awaddr_i        : in    std_logic_vector(G_ADDR_BITS - 1 downto 0);
    s_wready_o        : out   std_logic;
    s_wvalid_i        : in    std_logic;
    s_wdata_i         : in    std_logic_vector(G_DATA_BITS - 1 downto 0);
    s_wstrb_i         : in    std_logic_vector(G_DATA_BITS / 8 - 1 downto 0);
    s_bready_i        : in    std_logic;
    s_bvalid_o        : out   std_logic;
    s_bresp_o         : out   std_logic_vector(1 downto 0);
    s_arready_o       : out   std_logic;
    s_arvalid_i       : in    std_logic;
    s_araddr_i        : in    std_logic_vector(G_ADDR_BITS - 1 downto 0);
    s_rready_i        : in    std_logic;
    s_rvalid_o        : out   std_logic;
    s_rdata_o         : out   std_logic_vector(G_DATA_BITS - 1 downto 0);
    s_rresp_o         : out   std_logic_vector(1 downto 0);

    -- Avalon Memory Map interface (master)
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
end entity axil_to_avm;

architecture rtl of axil_to_avm is

  signal avm_read_address  : std_logic_vector(G_ADDR_BITS - 1 downto 0);
  signal avm_write_address : std_logic_vector(G_ADDR_BITS - 1 downto 0);
  signal avm_byteenable    : std_logic_vector(G_DATA_BITS / 8 - 1 downto 0);
  signal avm_read          : std_logic;
  signal avm_write         : std_logic;
  signal avm_writedata     : std_logic_vector(G_DATA_BITS - 1 downto 0);

  signal aw_stored : std_logic;
  signal w_stored  : std_logic;

  signal s_rvalid : std_logic;
  signal s_rdata  : std_logic_vector(G_DATA_BITS - 1 downto 0);

begin

  -- Handle write

  m_address_o    <= avm_write_address when avm_write = '1' else
                    avm_read_address;
  m_byteenable_o <= avm_byteenable;
  m_read_o       <= avm_read;
  m_write_o      <= avm_write;
  m_writedata_o  <= avm_writedata;
  m_burstcount_o <= (0 => '1', others => '0');

  read_proc : process (clk_i)
  begin
    if rising_edge(clk_i) then
      avm_read <= '0';

      if s_arvalid_i = '1' and s_arready_o = '1' then
        avm_read_address <= s_araddr_i;
        avm_read         <= '1';
      end if;
    end if;
  end process read_proc;

  s_awready_o    <= not aw_stored;
  s_wready_o     <= not w_stored;
  avm_write      <= aw_stored and w_stored and not avm_read;

  stored_proc : process (clk_i)
  begin
    if rising_edge(clk_i) then
      if s_awvalid_i = '1' and s_awready_o = '1' then
        avm_write_address <= s_awaddr_i;
        aw_stored         <= '1';
      end if;

      if s_wvalid_i = '1' and s_wready_o = '1' then
        avm_writedata  <= s_wdata_i;
        avm_byteenable <= s_wstrb_i;
        w_stored       <= '1';
      end if;

      if avm_write = '1' or rst_i = '1' then
        aw_stored <= '0';
        w_stored  <= '0';
      end if;
    end if;
  end process stored_proc;

  b_proc : process (clk_i)
  begin
    if rising_edge(clk_i) then
      if s_bready_i = '1' then
        s_bvalid_o <= '0';
      end if;

      if avm_write = '1' then
        s_bresp_o  <= (others => '0');
        s_bvalid_o <= '1';
      end if;
    end if;
  end process b_proc;


  -- Handle read response

  s_rvalid_o     <= s_rvalid;
  s_rdata_o      <= s_rdata;
  s_rresp_o      <= (others => '0');
  s_arready_o    <= '1';

  r_proc : process (clk_i)
  begin
    if rising_edge(clk_i) then
      if s_rready_i = '1' then
        s_rvalid <= '0';
      end if;

      if m_readdatavalid_i = '1' then
        s_rdata  <= m_readdata_i;
        s_rvalid <= '1';
      end if;
    end if;
  end process r_proc;

end architecture rtl;

