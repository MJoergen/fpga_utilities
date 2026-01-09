-- ---------------------------------------------------------------------------------------
-- Description: This provides stimulus to and verifies response from an AXI lite
-- interface.  It generates a sequence of Writes and Reads, and verifies that the values
-- returned from Read matches the corresponding values during Write.  This module may
-- generate simultaneous read and write requests, without first waiting for a response.
-- ---------------------------------------------------------------------------------------

library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std_unsigned.all;
  use std.env.stop;

entity axil_master_sim is
  generic (
    G_NAME      : string                        := "";
    G_SEED      : std_logic_vector(63 downto 0) := x"DEADBEEFC007BABE";
    G_OFFSET    : natural;
    G_DEBUG     : boolean;
    G_RANDOM    : boolean;
    G_FAST      : boolean;
    G_ADDR_SIZE : natural;
    G_DATA_SIZE : natural
  );
  port (
    clk_i       : in    std_logic;
    rst_i       : in    std_logic;

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
end entity axil_master_sim;

architecture simulation of axil_master_sim is

  signal  random_s : std_logic_vector(63 downto 0);

  subtype R_DO_WRITE is natural range 16 downto 15;

  subtype R_DO_READ is natural range 6 downto 5;

  subtype R_BREADY is natural range 26 downto 35;

  subtype R_RREADY is natural range 36 downto 35;

  signal  do_write : std_logic;
  signal  do_read  : std_logic;

  signal  write_req_cnt : natural range 0 to 100;
  signal  read_req_cnt  : natural range 0 to 100;

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
    variable new_write_req_cnt_v : natural;
    variable new_read_req_cnt_v  : natural;
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

      new_write_req_cnt_v := write_req_cnt;
      new_read_req_cnt_v  := read_req_cnt;

      -- Issue write request
      if do_write = '1'
         and ((G_FAST and m_awready_i = '1') or m_awvalid_o = '0')
         and ((G_FAST and m_wready_i = '1') or m_wvalid_o = '0') then
        if wr_ptr_stim + 1 = 0 then
          report "axil_master_sim: " & G_NAME & " Test finished";
          stop;
        else
          new_write_req_cnt_v := new_write_req_cnt_v + 1;
          m_awvalid_o         <= '1';
          m_awaddr_o          <= wr_ptr_stim;
          m_wvalid_o          <= '1';
          m_wdata_o           <= addr_to_data(wr_ptr_stim);
          m_wstrb_o           <= (others => '1');
          wr_ptr_stim         <= wr_ptr_stim + 1;
          if G_DEBUG then
            report "axil_master_sim: " & G_NAME & " STIMULI: Write: " & to_hstring(wr_ptr_stim) &
                   " <- " & to_hstring(addr_to_data(wr_ptr_stim));
          end if;
        end if;
      end if;

      -- Receive write response
      if m_bvalid_i = '1' and m_bready_o = '1' then
        assert write_req_cnt > 0
          report "axil_master_sim: " & G_NAME & " Write not active";
        new_write_req_cnt_v := new_write_req_cnt_v - 1;
        assert m_bresp_i = "00"
          report "axil_master_sim: " & G_NAME & " Incorrect m_bresp_i";
        wr_ptr_resp         <= wr_ptr_resp + 1;
      end if;

      -- Issue read request
      if do_read = '1'
         and rd_ptr_stim < wr_ptr_resp
         and ((G_FAST and m_arready_i = '1') or m_arvalid_o = '0') then
        if G_DEBUG then
          report "axil_master_sim: " & G_NAME & " STIMULI: Read: " & to_hstring(rd_ptr_stim);
        end if;
        new_read_req_cnt_v := new_read_req_cnt_v + 1;
        m_arvalid_o        <= '1';
        m_araddr_o         <= rd_ptr_stim;
        rd_ptr_stim        <= rd_ptr_stim + 1;
      end if;

      -- Receive read response
      if m_rvalid_i = '1' and m_rready_o = '1' then
        assert read_req_cnt > 0
          report "axil_master_sim: " & G_NAME & " Read not active";
        new_read_req_cnt_v := new_read_req_cnt_v - 1;
        assert m_rresp_i = "00"
          report "axil_master_sim: " & G_NAME & " Incorrect m_rresp_i";
        assert m_rdata_i = addr_to_data(rd_ptr_resp)
          report "axil_master_sim: " & G_NAME & " Read failure from address " & to_hstring(rd_ptr_resp) &
                 ". Got " & to_hstring(m_rdata_i) &
                 ", expected " & to_hstring(addr_to_data(rd_ptr_resp));
        rd_ptr_resp        <= rd_ptr_resp + 1;
      end if;

      write_req_cnt <= new_write_req_cnt_v;
      read_req_cnt  <= new_read_req_cnt_v;

      if rst_i = '1' then
        m_awvalid_o   <= '0';
        m_wvalid_o    <= '0';
        m_arvalid_o   <= '0';
        write_req_cnt <= 0;
        read_req_cnt  <= 0;
        wr_ptr_stim   <= (others => '0');
        wr_ptr_resp   <= (others => '0');
        rd_ptr_stim   <= (others => '0');
        rd_ptr_resp   <= (others => '0');
      end if;
    end if;
  end process stimuli_proc;

end architecture simulation;

