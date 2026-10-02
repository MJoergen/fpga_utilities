-- ---------------------------------------------------------------------------------------
-- Description: Verify axip_dropper
--
-- Uses a generic AXIP MASTER and SLAVE module to interact with the DUT.
--
-- The DROP input is asserted at random. The slave BFM runs with G_RESYNC, i.e.
-- it verifies the contents of each packet it receives but tolerates missing
-- packets. A scoreboard checks which packets are received: exactly those that
-- were not dropped, in order. Packets are identified by their first payload
-- byte.
--
-- SPDX-License-Identifier: MIT
-- ---------------------------------------------------------------------------------------

library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std.all;

entity tb_axip_dropper is
  generic (
    G_DEBUG      : boolean;
    G_RANDOM     : boolean;
    G_FAST       : boolean;
    G_MIN_LENGTH : natural;
    G_MAX_LENGTH : natural;
    G_CNT_SIZE   : natural;
    G_ADDR_BITS  : natural;
    G_DATA_BYTES : natural
  );
end entity tb_axip_dropper;

architecture tb of tb_axip_dropper is

  signal clk : std_logic := '1';
  signal rst : std_logic := '1';

  signal s_ready : std_logic;
  signal s_valid : std_logic;
  signal s_data  : std_logic_vector(G_DATA_BYTES * 8 - 1 downto 0);
  signal s_last  : std_logic;
  signal s_bytes : natural range 0 to G_DATA_BYTES;

  signal m_ready : std_logic;
  signal m_valid : std_logic;
  signal m_data  : std_logic_vector(G_DATA_BYTES * 8 - 1 downto 0);
  signal m_last  : std_logic;
  signal m_bytes : natural range 0 to G_DATA_BYTES;

  signal s_drop : std_logic;
  signal rand   : std_logic_vector(63 downto 0);

  -- Byte lane holding the first payload byte (the top lane holds the length byte).
  subtype R_FIRST_BYTE is natural range (G_DATA_BYTES - 2) * 8 + 7 downto (G_DATA_BYTES - 2) * 8;

  -- Scoreboard: first payload byte of every packet that is not dropped.
  type    sb_type is array (0 to 63) of std_logic_vector(7 downto 0);
  signal  sb       : sb_type;
  signal  sb_wr    : natural range 0 to 63;
  signal  sb_rd    : natural range 0 to 63;
  signal  in_first  : std_logic;
  signal  in_byte   : std_logic_vector(7 downto 0);
  signal  out_first : std_logic;

begin

  ----------------------------------------------
  -- Clock and Reset
  ----------------------------------------------

  clk <= not clk after 5 ns;
  rst <= '1', '0' after 100 ns;


  ----------------------------------------------
  -- Instantiate DUT
  ----------------------------------------------

  axip_dropper_inst : entity work.axip_dropper
    generic map (
      G_ADDR_BITS  => G_ADDR_BITS,
      G_DATA_BYTES => G_DATA_BYTES
    )
    port map (
      clk_i     => clk,
      rst_i     => rst,
      s_ready_o => s_ready,
      s_valid_i => s_valid,
      s_data_i  => s_data,
      s_last_i  => s_last,
      s_bytes_i => s_bytes,
      s_drop_i  => s_drop,
      m_ready_i => m_ready,
      m_valid_o => m_valid,
      m_data_o  => m_data,
      m_last_o  => m_last,
      m_bytes_o => m_bytes
    ); -- axip_dropper_inst : entity work.axip_dropper


  ----------------------------------------------
  -- Generate stimulus and verify response
  ----------------------------------------------

  axip_sim_inst : entity work.axip_sim
    generic map (
      G_DEBUG      => G_DEBUG,
      G_RANDOM     => G_RANDOM,
      G_FAST       => G_FAST,
      G_RESYNC     => true,
      G_MIN_LENGTH => G_MIN_LENGTH,
      G_MAX_LENGTH => G_MAX_LENGTH,
      G_CNT_SIZE   => G_CNT_SIZE,
      G_DATA_BYTES => G_DATA_BYTES
    )
    port map (
      clk_i     => clk,
      rst_i     => rst,
      m_ready_i => s_ready,
      m_valid_o => s_valid,
      m_data_o  => s_data,
      m_last_o  => s_last,
      m_bytes_o => s_bytes,
      s_ready_o => m_ready,
      s_valid_i => m_valid,
      s_data_i  => m_data,
      s_last_i  => m_last,
      s_bytes_i => m_bytes
    ); -- axip_sim_inst : entity work.axip_sim


  ----------------------------------------------
  -- Random drop requests (about 1 in 4 packets)
  ----------------------------------------------

  random_inst : entity work.random
    generic map (
      G_SEED => X"0F1E2D3C4B5A6978"
    )
    port map (
      clk_i    => clk,
      rst_i    => rst,
      update_i => '1',
      output_o => rand
    ); -- random_inst : entity work.random

  s_drop <= rand(7) and rand(13);


  ----------------------------------------------
  -- Scoreboard
  ----------------------------------------------

  sb_in_proc : process (clk)
    variable byte_v : std_logic_vector(7 downto 0);
  begin
    if rising_edge(clk) then
      if s_valid = '1' and s_ready = '1' then
        byte_v := in_byte;
        if in_first = '1' then
          byte_v := s_data(R_FIRST_BYTE);
        end if;
        in_byte  <= byte_v;
        in_first <= s_last;

        if s_last = '1' and s_drop = '0' then
          assert (sb_wr + 1) mod 64 /= sb_rd
            report "tb_axip_dropper: scoreboard overflow"
            severity failure;
          sb(sb_wr) <= byte_v;
          sb_wr     <= (sb_wr + 1) mod 64;
        end if;
      end if;

      if rst = '1' then
        in_first <= '1';
        sb_wr    <= 0;
      end if;
    end if;
  end process sb_in_proc;

  sb_out_proc : process (clk)
  begin
    if rising_edge(clk) then
      if m_valid = '1' and m_ready = '1' then
        if out_first = '1' then
          assert sb_rd /= sb_wr
            report "tb_axip_dropper: received a packet that should have been dropped"
            severity failure;
          assert m_data(R_FIRST_BYTE) = sb(sb_rd)
            report "tb_axip_dropper: received packet starting with " & to_hstring(m_data(R_FIRST_BYTE)) &
                   ", expected packet starting with " & to_hstring(sb(sb_rd))
            severity failure;
          sb_rd <= (sb_rd + 1) mod 64;
        end if;
        out_first <= m_last;
      end if;

      if rst = '1' then
        out_first <= '1';
        sb_rd     <= 0;
      end if;
    end if;
  end process sb_out_proc;

end architecture tb;

