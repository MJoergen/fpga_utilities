-- ---------------------------------------------------------------------------------------
-- Description: Verify axis_arbiter
-- ---------------------------------------------------------------------------------------

library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std.all;

library work;
  use work.axis_pkg.all;

entity tb_axis_arbiter is
  generic (
    G_RANDOM     : boolean;
    G_FAST       : boolean;
    G_CNT_SIZE   : natural;
    G_DATA_BYTES : natural
  );
end entity tb_axis_arbiter;

architecture simulation of tb_axis_arbiter is

  signal clk : std_logic := '1';
  signal rst : std_logic := '1';

  signal s0_axis : axis_rec_type (
    data(G_DATA_BYTES * 8 - 1 downto 0)
  );
  signal s1_axis : axis_rec_type (
    data(G_DATA_BYTES * 8 - 1 downto 0)
  );
  signal d_axis  : axis_rec_type (
    data(G_DATA_BYTES * 8 - 1 downto 0)
  );
  signal m0_axis : axis_rec_type (
    data(G_DATA_BYTES * 8 - 1 downto 0)
  );
  signal m1_axis : axis_rec_type (
    data(G_DATA_BYTES * 8 - 1 downto 0)
  );

begin

  --------------------------------
  -- Clock and Reset
  --------------------------------

  clk <= not clk after 5 ns;
  rst <= '1', '0' after 100 ns;


  --------------------------------
  -- Instantiate DUT
  --------------------------------

  axis_arbiter_inst : entity work.axis_arbiter
    port map (
      clk_i      => clk,
      rst_i      => rst,
      s0_axis    => s0_axis,
      s1_axis    => s1_axis,
      m_axis     => d_axis
    ); -- axis_arbiter_inst : entity work.axis_arbiter


  --------------------------------
  -- Instantiate AXI distributor
  --------------------------------

  axis_distributor_inst : entity work.axis_distributor
    port map (
      clk_i   => clk,
      rst_i   => rst,
      s_dst_i => d_axis.data(d_axis.data'left),
      s_axis  => d_axis,
      m0_axis => m0_axis,
      m1_axis => m1_axis
    ); -- axis_distributor_inst : entity work.axis_distributor


  --------------------------------
  -- Instantiate AXI streaming stimulus
  --------------------------------

  axis_sim_0_inst : entity work.axis_sim
    generic map (
      G_SEED       => X"1122334455667788",
      G_RANDOM     => G_RANDOM,
      G_FAST       => G_FAST,
      G_FIRST      => '0',
      G_CNT_SIZE   => G_CNT_SIZE
    )
    port map (
      clk_i  => clk,
      rst_i  => rst,
      m_axis => s0_axis,
      s_axis => m0_axis
    ); -- axis_sim_0_inst : entity work.axis_sim

  axis_sim_1_inst : entity work.axis_sim
    generic map (
      G_SEED       => X"1234567812345678",
      G_RANDOM     => G_RANDOM,
      G_FAST       => G_FAST,
      G_FIRST      => '1',
      G_CNT_SIZE   => G_CNT_SIZE
    )
    port map (
      clk_i  => clk,
      rst_i  => rst,
      m_axis => s1_axis,
      s_axis => m1_axis
    ); -- axis_sim_1_inst : entity work.axis_sim

end architecture simulation;

