-- ----------------------------------------------------------------------------
-- Author     : Michael Jørgensen
-- Platform   : simulation
-------------------------------------------------------------------------------
-- Description: Generate empty cycles in an AXI Lite interface.
-------------------------------------------------------------------------------

library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std_unsigned.all;

entity axil_pause is
  generic (
    G_SEED       : std_logic_vector(63 downto 0) := x"8765432112345678";
    G_ADDR_SIZE  : integer;
    G_DATA_SIZE  : integer;
    G_PAUSE_SIZE : integer
  );
  port (
    clk_i       : in    std_logic;
    rst_i       : in    std_logic;

    -- Input
    s_awready_o : out   std_logic;
    s_awvalid_i : in    std_logic;
    s_awaddr_i  : in    std_logic_vector(G_ADDR_SIZE - 1 downto 0);
    s_wready_o  : out   std_logic;
    s_wvalid_i  : in    std_logic;
    s_wdata_i   : in    std_logic_vector(G_DATA_SIZE - 1 downto 0);
    s_wstrb_i   : in    std_logic_vector(G_DATA_SIZE / 8 - 1 downto 0);
    s_bready_i  : in    std_logic;
    s_bvalid_o  : out   std_logic;
    s_bresp_o   : out   std_logic_vector(1 downto 0);
    s_arready_o : out   std_logic;
    s_arvalid_i : in    std_logic;
    s_araddr_i  : in    std_logic_vector(G_ADDR_SIZE - 1 downto 0);
    s_rready_i  : in    std_logic;
    s_rvalid_o  : out   std_logic;
    s_rdata_o   : out   std_logic_vector(G_DATA_SIZE - 1 downto 0);
    s_rresp_o   : out   std_logic_vector(1 downto 0);

    -- Output
    m_awready_i : in    std_logic;
    m_awvalid_o : out   std_logic;
    m_awaddr_o  : out   std_logic_vector(G_ADDR_SIZE - 1 downto 0);
    m_wready_i  : in    std_logic;
    m_wvalid_o  : out   std_logic;
    m_wdata_o   : out   std_logic_vector(G_DATA_SIZE - 1 downto 0);
    m_wstrb_o   : out   std_logic_vector(G_DATA_SIZE / 8 - 1 downto 0);
    m_bready_o  : out   std_logic;
    m_bvalid_i  : in    std_logic;
    m_bresp_i   : in    std_logic_vector(1 downto 0);
    m_arready_i : in    std_logic;
    m_arvalid_o : out   std_logic;
    m_araddr_o  : out   std_logic_vector(G_ADDR_SIZE - 1 downto 0);
    m_rready_o  : out   std_logic;
    m_rvalid_i  : in    std_logic;
    m_rdata_i   : in    std_logic_vector(G_DATA_SIZE - 1 downto 0);
    m_rresp_i   : in    std_logic_vector(1 downto 0)
  );
end entity axil_pause;

architecture simulation of axil_pause is

  signal s_w_in  : std_logic_vector(G_DATA_SIZE + G_DATA_SIZE / 8 - 1 downto 0);
  signal m_w_out : std_logic_vector(G_DATA_SIZE + G_DATA_SIZE / 8 - 1 downto 0);

  signal m_r_in  : std_logic_vector(G_DATA_SIZE + 1 downto 0);
  signal s_r_out : std_logic_vector(G_DATA_SIZE + 1 downto 0);

begin

  axis_pause_aw_inst : entity work.axis_pause
    generic map (
      G_SEED       => G_SEED xor X"1234BABECAFEDEAD",
      G_DATA_SIZE  => G_ADDR_SIZE,
      G_PAUSE_SIZE => G_PAUSE_SIZE
    )
    port map (
      clk_i     => clk_i,
      rst_i     => rst_i,
      s_valid_i => s_awvalid_i,
      s_ready_o => s_awready_o,
      s_data_i  => s_awaddr_i,
      m_valid_o => m_awvalid_o,
      m_ready_i => m_awready_i,
      m_data_o  => m_awaddr_o
    ); -- axis_pause_aw_inst : entity work.axis_pause


  axis_pause_ar_inst : entity work.axis_pause
    generic map (
      G_SEED       => G_SEED xor X"234BABECAFEDEAD2",
      G_DATA_SIZE  => G_ADDR_SIZE,
      G_PAUSE_SIZE => G_PAUSE_SIZE
    )
    port map (
      clk_i     => clk_i,
      rst_i     => rst_i,
      s_valid_i => s_arvalid_i,
      s_ready_o => s_arready_o,
      s_data_i  => s_araddr_i,
      m_valid_o => m_arvalid_o,
      m_ready_i => m_arready_i,
      m_data_o  => m_araddr_o
    ); -- axis_pause_aw_inst : entity work.axis_pause


  axis_pause_w_inst : entity work.axis_pause
    generic map (
      G_SEED       => G_SEED xor X"34BABECAFEDEAD23",
      G_DATA_SIZE  => G_DATA_SIZE + G_DATA_SIZE / 8,
      G_PAUSE_SIZE => G_PAUSE_SIZE
    )
    port map (
      clk_i     => clk_i,
      rst_i     => rst_i,
      s_valid_i => s_wvalid_i,
      s_ready_o => s_wready_o,
      s_data_i  => s_w_in,
      m_valid_o => m_wvalid_o,
      m_ready_i => m_wready_i,
      m_data_o  => m_w_out
    ); -- axis_pause_w_inst : entity work.axis_pause

  s_w_in                  <= s_wstrb_i & s_wdata_i;
  (m_wstrb_o , m_wdata_o) <= m_w_out;


  axis_pause_b_inst : entity work.axis_pause
    generic map (
      G_SEED       => G_SEED xor X"4BABECAFEDEAD234",
      G_DATA_SIZE  => 2,
      G_PAUSE_SIZE => G_PAUSE_SIZE
    )
    port map (
      clk_i     => clk_i,
      rst_i     => rst_i,
      s_valid_i => m_bvalid_i,
      s_ready_o => m_bready_o,
      s_data_i  => m_bresp_i,
      m_valid_o => s_bvalid_o,
      m_ready_i => s_bready_i,
      m_data_o  => s_bresp_o
    ); -- axis_pause_b_inst : entity work.axis_pause

  axis_pause_r_inst : entity work.axis_pause
    generic map (
      G_SEED       => G_SEED xor X"BABECAFEDEAD2345",
      G_DATA_SIZE  => G_DATA_SIZE + 2,
      G_PAUSE_SIZE => G_PAUSE_SIZE
    )
    port map (
      clk_i     => clk_i,
      rst_i     => rst_i,
      s_valid_i => m_rvalid_i,
      s_ready_o => m_rready_o,
      s_data_i  => m_r_in,
      m_valid_o => s_rvalid_o,
      m_ready_i => s_rready_i,
      m_data_o  => s_r_out
    ); -- axis_pause_r_inst : entity work.axis_pause

  m_r_in                 <= m_rresp_i & m_rdata_i;
  (s_rresp_o, s_rdata_o) <= s_r_out;

end architecture simulation;

