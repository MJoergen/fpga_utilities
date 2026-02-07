-- ---------------------------------------------------------------------------------------
-- Description: Verify axip_remove_fixed_header and axip_insert_fixed_header
-- ---------------------------------------------------------------------------------------

library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std_unsigned.all;

library work;
  use work.axis_pkg.all;
  use work.axip_pkg.all;

entity tb_axip_fixed_header is
  generic (
    G_PAUSE_SIZE   : natural;
    G_DEBUG        : boolean;
    G_MAX_LENGTH   : natural;
    G_CNT_SIZE     : natural;
    G_FAST         : boolean;
    G_RANDOM       : boolean;
    G_DATA_BYTES   : natural;
    G_HEADER_BYTES : natural
  );
end entity tb_axip_fixed_header;

architecture simulation of tb_axip_fixed_header is

  signal   clk : std_logic  := '1';
  signal   rst : std_logic  := '1';

  signal tb_m_axip : axip_rec_type (
    data(G_DATA_BYTES * 8 - 1 downto 0)
  );

  signal tb_s_axip : axip_rec_type (
    data(G_DATA_BYTES * 8 - 1 downto 0)
  );

  signal h_axis : axis_rec_type (
    data(G_HEADER_BYTES * 8 - 1 downto 0)
  );

  signal d_axip : axip_rec_type (
    data(G_DATA_BYTES * 8 - 1 downto 0)
  );

  signal h_pause_axis : axis_rec_type (
    data(G_HEADER_BYTES * 8 - 1 downto 0)
  );

  signal d_pause_axip : axip_rec_type (
    data(G_DATA_BYTES * 8 - 1 downto 0)
  );

begin

  --------------------------------------------
  -- Clock and reset
  --------------------------------------------

  clk <= not clk after 5 ns;
  rst <= '1', '0' after 100 ns;


  --------------------------------------------
  -- Instantiate first DUT
  --------------------------------------------

  axip_remove_fixed_header_inst : entity work.axip_remove_fixed_header
    port map (
      clk_i  => clk,
      rst_i  => rst,
      s_axip => tb_m_axip,
      m_axip => d_axip,
      h_axis => h_axis
    ); -- axip_remove_fixed_header_inst : entity work.axip_remove_fixed_header


  --------------------------------------------
  -- Instantiate random breaks in stream
  --------------------------------------------

  axis_pause_h_inst : entity work.axis_pause
    generic map (
      G_SEED       => X"0011223344556677",
      G_PAUSE_SIZE => G_PAUSE_SIZE
    )
    port map (
      clk_i  => clk,
      rst_i  => rst,
      s_axis => h_axis,
      m_axis => h_pause_axis
    ); -- axis_pause_h_inst : entity work.axis_pause

  axip_pause_d_inst : entity work.axip_pause
    generic map (
      G_SEED       => X"0123456701234567",
      G_PAUSE_SIZE => G_PAUSE_SIZE
    )
    port map (
      clk_i  => clk,
      rst_i  => rst,
      s_axip => d_axip,
      m_axip => d_pause_axip
    ); -- axis_pause_d_inst : entity work.axis_pause


  --------------------------------------------
  -- Instantiate second DUT
  --------------------------------------------

  axip_insert_fixed_header_inst : entity work.axip_insert_fixed_header
    port map (
      clk_i  => clk,
      rst_i  => rst,
      h_axis => h_pause_axis,
      s_axip => d_pause_axip,
      m_axip => tb_s_axip
    ); -- axip_insert_fixed_header_inst : entity work.axip_insert_fixed_header


  --------------------------------------------
  -- Generate stimuli and verify response
  --------------------------------------------

  axip_sim_inst : entity work.axip_sim
    generic map (
      G_DEBUG      => G_DEBUG,
      G_RANDOM     => G_RANDOM,
      G_FAST       => G_FAST,
      G_MIN_LENGTH => G_HEADER_BYTES,
      G_MAX_LENGTH => G_MAX_LENGTH,
      G_CNT_SIZE   => G_CNT_SIZE
    )
    port map (
      clk_i  => clk,
      rst_i  => rst,
      m_axip => tb_m_axip,
      s_axip => tb_s_axip
    ); -- axip_sim_inst : entity work.axip_sim

end architecture simulation;

