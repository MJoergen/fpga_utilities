-- ---------------------------------------------------------------------------------------
-- Description: Generate empty cycles in an AXI Lite interface.
-- ---------------------------------------------------------------------------------------

library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std.all;

library work;
  use work.axis_pkg.all;
  use work.axil_pkg.all;

entity axil_pause is
  generic (
    G_SEED       : std_logic_vector(63 downto 0) := x"8765432112345678";
    G_PAUSE_SIZE : integer
  );
  port (
    clk_i  : in    std_logic;
    rst_i  : in    std_logic;
    s_axil : view axil_slave_view;
    m_axil : view axil_master_view
  );
end entity axil_pause;

architecture simulation of axil_pause is

  constant C_DATA_SIZE : positive := s_axil.wdata'length;

  signal   s_w_in  : std_logic_vector(C_DATA_SIZE + C_DATA_SIZE / 8 - 1 downto 0);
  signal   m_w_out : std_logic_vector(C_DATA_SIZE + C_DATA_SIZE / 8 - 1 downto 0);

  signal   m_r_in  : std_logic_vector(C_DATA_SIZE + 1 downto 0);
  signal   s_r_out : std_logic_vector(C_DATA_SIZE + 1 downto 0);

  signal   s_axis_aw : axis_rec_type (
                                      data(s_axil.awaddr'range)
                                     );
  signal   m_axis_aw : axis_rec_type (
                                      data(m_axil.awaddr'range)
                                     );

  signal   s_axis_ar : axis_rec_type (
                                      data(s_axil.araddr'range)
                                     );
  signal   m_axis_ar : axis_rec_type (
                                      data(m_axil.araddr'range)
                                     );

  signal   s_axis_w : axis_rec_type (
                                     data(C_DATA_SIZE + C_DATA_SIZE / 8 - 1 downto 0)
                                    );
  signal   m_axis_w : axis_rec_type (
                                     data(C_DATA_SIZE + C_DATA_SIZE / 8 - 1 downto 0)
                                    );

  signal   s_axis_b : axis_rec_type (
                                     data(1 downto 0)
                                    );
  signal   m_axis_b : axis_rec_type (
                                     data(1 downto 0)
                                    );

  signal   s_axis_r : axis_rec_type (
                                     data(C_DATA_SIZE + 1 downto 0)
                                    );
  signal   m_axis_r : axis_rec_type (
                                     data(C_DATA_SIZE + 1 downto 0)
                                    );

begin

  s_axis_aw.valid <= s_axil.awvalid;
  s_axis_aw.data  <= s_axil.awaddr;
  s_axil.awready  <= s_axis_aw.ready;
  m_axil.awvalid  <= m_axis_aw.valid;
  m_axil.awaddr   <= m_axis_aw.data;
  m_axis_aw.ready <= m_axil.awready;

  axis_pause_aw_inst : entity work.axis_pause
    generic map (
      G_SEED       => G_SEED xor X"1234BABECAFEDEAD",
      G_PAUSE_SIZE => G_PAUSE_SIZE
    )
    port map (
      clk_i  => clk_i,
      rst_i  => rst_i,
      s_axis => s_axis_aw,
      m_axis => m_axis_aw
    ); -- axis_pause_aw_inst : entity work.axis_pause


  s_axis_ar.valid <= s_axil.arvalid;
  s_axis_ar.data  <= s_axil.araddr;
  s_axil.arready  <= s_axis_ar.ready;
  m_axil.arvalid  <= m_axis_ar.valid;
  m_axil.araddr   <= m_axis_ar.data;
  m_axis_ar.ready <= m_axil.arready;

  axis_pause_ar_inst : entity work.axis_pause
    generic map (
      G_SEED       => G_SEED xor X"234BABECAFEDEAD2",
      G_PAUSE_SIZE => G_PAUSE_SIZE
    )
    port map (
      clk_i  => clk_i,
      rst_i  => rst_i,
      s_axis => s_axis_ar,
      m_axis => m_axis_ar
    ); -- axis_pause_ar_inst : entity work.axis_pause


  s_axis_w.valid                <= s_axil.wvalid;
  s_axis_w.data                 <= s_axil.wstrb & s_axil.wdata;
  s_axil.wready                 <= s_axis_w.ready;
  m_axil.wvalid                 <= m_axis_w.valid;
  (m_axil.wstrb , m_axil.wdata) <= m_axis_w.data;
  m_axis_w.ready                <= m_axil.wready;

  axis_pause_w_inst : entity work.axis_pause
    generic map (
      G_SEED       => G_SEED xor X"34BABECAFEDEAD23",
      G_PAUSE_SIZE => G_PAUSE_SIZE
    )
    port map (
      clk_i  => clk_i,
      rst_i  => rst_i,
      s_axis => s_axis_w,
      m_axis => m_axis_w
    ); -- axis_pause_w_inst : entity work.axis_pause


  m_axil.bready  <= s_axis_b.ready;
  s_axis_b.valid <= m_axil.bvalid;
  s_axis_b.data  <= m_axil.bresp;
  m_axis_b.ready <= s_axil.bready;
  s_axil.bvalid  <= m_axis_b.valid;
  s_axil.bresp   <= m_axis_b.data;

  axis_pause_b_inst : entity work.axis_pause
    generic map (
      G_SEED       => G_SEED xor X"4BABECAFEDEAD234",
      G_PAUSE_SIZE => G_PAUSE_SIZE
    )
    port map (
      clk_i  => clk_i,
      rst_i  => rst_i,
      s_axis => s_axis_b,
      m_axis => m_axis_b
    ); -- axis_pause_b_inst : entity work.axis_pause


  m_axil.rready                <= s_axis_r.ready;
  s_axis_r.valid               <= m_axil.rvalid;
  s_axis_r.data                <= m_axil.rresp & m_axil.rdata;
  m_axis_r.ready               <= s_axil.rready;
  s_axil.rvalid                <= m_axis_r.valid;
  (s_axil.rresp, s_axil.rdata) <= m_axis_r.data;

  axis_pause_r_inst : entity work.axis_pause
    generic map (
      G_SEED       => G_SEED xor X"BABECAFEDEAD2345",
      G_PAUSE_SIZE => G_PAUSE_SIZE
    )
    port map (
      clk_i  => clk_i,
      rst_i  => rst_i,
      s_axis => s_axis_r,
      m_axis => m_axis_r
    ); -- axis_pause_r_inst : entity work.axis_pause

end architecture simulation;

