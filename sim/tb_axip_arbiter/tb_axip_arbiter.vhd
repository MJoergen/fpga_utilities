-- ---------------------------------------------------------------------------------------
-- Description: Verify axis_arbiter
-- ---------------------------------------------------------------------------------------

library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std.all;

library work;
  use work.axis_pkg.all;
  use work.axip_pkg.all;

entity tb_axip_arbiter is
  generic (
    G_RANDOM     : boolean;
    G_DEBUG      : boolean;
    G_MIN_LENGTH : natural;
    G_MAX_LENGTH : natural;
    G_FAST       : boolean;
    G_CNT_SIZE   : natural;
    G_DATA_BYTES : natural
  );
end entity tb_axip_arbiter;

architecture simulation of tb_axip_arbiter is

  signal clk : std_logic := '1';
  signal rst : std_logic := '1';

  signal s0_axip : axip_rec_type (
                                  data(G_DATA_BYTES * 8 - 1 downto 0)
                                 );

  signal s1_axip : axip_rec_type (
                                  data(G_DATA_BYTES * 8 - 1 downto 0)
                                 );

  signal d_axip : axip_rec_type (
                                 data(G_DATA_BYTES * 8 - 1 downto 0)
                                );

  signal sh0_axip : axip_rec_type (
                                   data(G_DATA_BYTES * 8 - 1 downto 0)
                                  );

  signal sh1_axip : axip_rec_type (
                                   data(G_DATA_BYTES * 8 - 1 downto 0)
                                  );

  signal dh_axip : axip_rec_type (
                                  data(G_DATA_BYTES * 8 - 1 downto 0)
                                 );

  signal m0_axip : axip_rec_type (
                                  data(G_DATA_BYTES * 8 - 1 downto 0)
                                 );

  signal m1_axip : axip_rec_type (
                                  data(G_DATA_BYTES * 8 - 1 downto 0)
                                 );

  signal h_axis : axis_rec_type (
                                 data(7 downto 0)
                                );

  signal h0_axis : axis_rec_type (
                                  data(7 downto 0)
                                 );

  signal h1_axis : axis_rec_type (
                                  data(7 downto 0)
                                 );

begin

  --------------------------------
  -- Clock and Reset
  --------------------------------

  clk           <= not clk after 5 ns;
  rst           <= '1', '0' after 100 ns;

  h_axis.ready  <= '1';

  h0_axis.valid <= '1';
  h0_axis.data  <= x"00";

  h1_axis.valid <= '1';
  h1_axis.data  <= x"FF";


  --------------------------------
  -- Instantiate DUT
  --------------------------------

  axip_arbiter_inst : entity work.axip_arbiter
    port map (
      clk_i   => clk,
      rst_i   => rst,
      s0_axip => sh0_axip,
      s1_axip => sh1_axip,
      m_axip  => d_axip
    ); -- axip_arbiter_inst : entity work.axip_arbiter

  axip_remove_fixed_header_inst : entity work.axip_remove_fixed_header
    port map (
      clk_i  => clk,
      rst_i  => rst,
      s_axip => d_axip,
      m_axip => dh_axip,
      h_axis => h_axis
    ); -- axip_remove_fixed_header_inst : entity work.axip_remove_fixed_header


  --------------------------------
  -- Instantiate AXI distributor
  --------------------------------

  axip_distributor_inst : entity work.axip_distributor
    port map (
      clk_i   => clk,
      rst_i   => rst,
      s_dst_i => h_axis.data(0),
      s_axip  => dh_axip,
      m0_axip => m0_axip,
      m1_axip => m1_axip
    ); -- axis_distributor_inst : entity work.axis_distributor


  --------------------------------
  -- Instantiate AXI streaming stimulus
  --------------------------------

  axip_sim_0_inst : entity work.axip_sim
    generic map (
      G_SEED       => X"1122334455667788",
      G_NAME       => "0",
      G_DEBUG      => G_DEBUG,
      G_MIN_LENGTH => G_MIN_LENGTH,
      G_MAX_LENGTH => G_MAX_LENGTH,
      G_RANDOM     => G_RANDOM,
      G_FAST       => G_FAST,
      G_CNT_SIZE   => G_CNT_SIZE
    )
    port map (
      clk_i  => clk,
      rst_i  => rst,
      m_axip => s0_axip,
      s_axip => m0_axip
    ); -- axip_sim_0_inst : entity work.axip_sim

  axip_insert_fixed_header_0_inst : entity work.axip_insert_fixed_header
    port map (
      clk_i  => clk,
      rst_i  => rst,
      h_axis => h0_axis,
      s_axip => s0_axip,
      m_axip => sh0_axip
    ); -- axip_insert_fixed_header_0_inst : entity work.axip_insert_fixed_header


  axip_sim_1_inst : entity work.axip_sim
    generic map (
      G_SEED       => X"1234567812345678",
      G_NAME       => "1",
      G_DEBUG      => G_DEBUG,
      G_MIN_LENGTH => G_MIN_LENGTH,
      G_MAX_LENGTH => G_MAX_LENGTH,
      G_RANDOM     => G_RANDOM,
      G_FAST       => G_FAST,
      G_CNT_SIZE   => G_CNT_SIZE
    )
    port map (
      clk_i  => clk,
      rst_i  => rst,
      m_axip => s1_axip,
      s_axip => m1_axip
    ); -- axip_sim_1_inst : entity work.axip_sim

  axip_insert_fixed_header_1_inst : entity work.axip_insert_fixed_header
    port map (
      clk_i  => clk,
      rst_i  => rst,
      h_axis => h1_axis,
      s_axip => s1_axip,
      m_axip => sh1_axip
    ); -- axip_insert_fixed_header_1_inst : entity work.axip_insert_fixed_header

end architecture simulation;

