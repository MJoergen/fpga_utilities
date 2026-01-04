-- ----------------------------------------------------------------------------
-- Author     : Michael Jørgensen
-- Platform   : simulation
-- ----------------------------------------------------------------------------
-- Description: This provides stimulus to and verifies response from an AXI lite interface.
-- It generates a sequence of Writes and Reads, and verifies that the values
-- returned from Read matches the corresponding values during Write.
-- ----------------------------------------------------------------------------

library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std_unsigned.all;
  use std.env.stop;

entity axil_master_sim is
  generic (
    G_SEED      : std_logic_vector(63 downto 0) := x"DEADBEEFC007BABE";
    G_OFFSET    : natural;
    G_DEBUG     : boolean;
    G_RANDOM    : boolean;
    G_FAST      : boolean;
    G_ID_SIZE   : natural;
    G_ADDR_SIZE : natural;
    G_DATA_SIZE : natural
  );
  port (
    clk_i       : in    std_logic;
    rst_i       : in    std_logic;

    m_awready_i : in    std_logic;
    m_awvalid_o : out   std_logic;
    m_awaddr_o  : out   std_logic_vector(G_ADDR_SIZE - 1 downto 0);
    m_awid_o    : out   std_logic_vector(G_ID_SIZE - 1 downto 0);
    m_wready_i  : in    std_logic;
    m_wvalid_o  : out   std_logic;
    m_wdata_o   : out   std_logic_vector(G_DATA_SIZE - 1 downto 0);
    m_wstrb_o   : out   std_logic_vector(G_DATA_SIZE / 8 - 1 downto 0);
    m_bready_o  : out   std_logic;
    m_bvalid_i  : in    std_logic;
    m_bresp_i   : in    std_logic_vector(1 downto 0);
    m_bid_i     : in    std_logic_vector(G_ID_SIZE - 1 downto 0);
    m_arready_i : in    std_logic;
    m_arvalid_o : out   std_logic;
    m_araddr_o  : out   std_logic_vector(G_ADDR_SIZE - 1 downto 0);
    m_arid_o    : out   std_logic_vector(G_ID_SIZE - 1 downto 0);
    m_rready_o  : out   std_logic;
    m_rvalid_i  : in    std_logic;
    m_rdata_i   : in    std_logic_vector(G_DATA_SIZE - 1 downto 0);
    m_rresp_i   : in    std_logic_vector(1 downto 0);
    m_rid_i     : in    std_logic_vector(G_ID_SIZE - 1 downto 0)
  );
end entity axil_master_sim;

architecture simulation of axil_master_sim is

  signal  random_s : std_logic_vector(63 downto 0);

  subtype R_DO_WRITE is natural range 16 downto 15;

  subtype R_DO_READ is natural range 6 downto 5;

  subtype R_BREADY is natural range 26 downto 35;

  subtype R_RREADY is natural range 36 downto 35;

  signal  do_write : std_logic;
  signal  do_read  : std_logic;

  signal  wr_ptr_stim : std_logic_vector(G_ADDR_SIZE - 1 downto 0);
  signal  rd_ptr_stim : std_logic_vector(G_ADDR_SIZE - 1 downto 0);
  signal  wr_ptr_resp : std_logic_vector(G_ADDR_SIZE - 1 downto 0);
  signal  rd_ptr_resp : std_logic_vector(G_ADDR_SIZE - 1 downto 0);

  pure function addr_to_data (
    addr : std_logic_vector
  ) return std_logic_vector is
  begin
    return to_stdlogicvector(2 ** (G_DATA_SIZE - 1) + G_OFFSET - to_integer(addr), G_DATA_SIZE);
  end function addr_to_data;

  pure function addr_to_id (
    addr : std_logic_vector
  ) return std_logic_vector is
  begin
    return to_stdlogicvector((G_OFFSET + to_integer(addr)) mod (2 ** G_ID_SIZE), G_ID_SIZE);
  end function addr_to_id;

begin

  -----------------------------------------------
  -- Instantiate random number generator
  -----------------------------------------------

  random_inst : entity work.random
    generic map (
      G_SEED => G_SEED
    )
    port map (
      clk_i    => clk_i,
      rst_i    => rst_i,
      update_i => '1',
      output_o => random_s
    ); -- random_inst : entity work.random


  -----------------------------------------------
  -- Generate stimulus
  -----------------------------------------------

  do_write   <= and(random_s(R_DO_WRITE)) when G_RANDOM else
                '1';
  do_read    <= and(random_s(R_DO_READ)) when G_RANDOM else
                '1';
  m_bready_o <= and(random_s(R_BREADY)) when G_RANDOM else
                '1';
  m_rready_o <= and(random_s(R_RREADY)) when G_RANDOM else
                '1';

  stimuli_proc : process (clk_i)
  begin
    if rising_edge(clk_i) then
      if m_awready_i = '1' then
        m_awvalid_o <= '0';
      end if;
      if m_wready_i = '1' then
        m_wvalid_o <= '0';
      end if;
      if m_arready_i = '1' then
        m_arvalid_o <= '0';
      end if;

      -- Issue write request
      if do_write = '1'
         and ((G_FAST and m_awready_i = '1') or m_awvalid_o = '0')
         and ((G_FAST and m_wready_i = '1') or m_wvalid_o = '0') then
        if wr_ptr_stim + 1 = 0 then
          report "Test finished";
          stop;
        else
          m_awvalid_o <= '1';
          m_awaddr_o  <= wr_ptr_stim;
          m_awid_o    <= addr_to_id(wr_ptr_stim);
          m_wvalid_o  <= '1';
          m_wdata_o   <= addr_to_data(wr_ptr_stim);
          m_wstrb_o   <= (others => '1');
          wr_ptr_stim <= wr_ptr_stim + 1;
          if G_DEBUG then
            report "axil_master_sim: STIMULI: Write: " & to_hstring(wr_ptr_stim) & " (" & to_hstring(addr_to_id(wr_ptr_stim)) &
                   ") <- " & to_hstring(addr_to_data(wr_ptr_stim));
          end if;
        end if;
      end if;

      -- Receive write response
      if m_bvalid_i = '1' and m_bready_o = '1' then
        assert m_bresp_i = "00"
          report "axil_master_sim: Incorrect m_bresp_i";
        assert m_bid_i = addr_to_id(wr_ptr_resp)
          report "axil_master_sim: Write response failure from address " & to_hstring(wr_ptr_resp) &
                 ". Got " & to_hstring(m_bid_i) &
                 ", expected " & to_hstring(addr_to_id(wr_ptr_resp));
        wr_ptr_resp <= wr_ptr_resp + 1;
      end if;

      -- Issue read request
      if do_read = '1'
         and rd_ptr_stim < wr_ptr_resp
         and ((G_FAST and m_arready_i = '1') or m_arvalid_o = '0') then
        if G_DEBUG then
          report "axil_master_sim: STIMULI: Read: " & to_hstring(rd_ptr_stim) & " (" & to_hstring(not addr_to_id(rd_ptr_stim)) & ")";
        end if;
        m_arvalid_o <= '1';
        m_araddr_o  <= rd_ptr_stim;
        m_arid_o    <= not addr_to_id(rd_ptr_stim);
        rd_ptr_stim <= rd_ptr_stim + 1;
      end if;

      -- Receive read response
      if m_rvalid_i = '1' and m_rready_o = '1' then
        assert m_rresp_i = "00"
          report "axil_master_sim: Incorrect m_rresp_i";
        assert m_rdata_i = addr_to_data(rd_ptr_resp)
          report "axil_master_sim: Read failure from address " & to_hstring(rd_ptr_resp) &
                 ". Got " & to_hstring(m_rdata_i) &
                 ", expected " & to_hstring(addr_to_data(rd_ptr_resp));
        assert m_rid_i = not addr_to_id(rd_ptr_resp)
          report "axil_master_sim: Read response failure from address " & to_hstring(rd_ptr_resp) &
                 ". Got " & to_hstring(m_rid_i) &
                 ", expected " & to_hstring(not addr_to_id(rd_ptr_resp));
        rd_ptr_resp <= rd_ptr_resp + 1;
      end if;

      if rst_i = '1' then
        m_awvalid_o <= '0';
        m_wvalid_o  <= '0';
        m_arvalid_o <= '0';
        wr_ptr_stim <= (others => '0');
        wr_ptr_resp <= (others => '0');
        rd_ptr_stim <= (others => '0');
        rd_ptr_resp <= (others => '0');
      end if;
    end if;
  end process stimuli_proc;

end architecture simulation;

