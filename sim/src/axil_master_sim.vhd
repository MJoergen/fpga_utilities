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

library work;
  use work.axil_pkg.all;

entity axil_master_sim is
  generic (
    G_NAME   : string                        := "";
    G_SEED   : std_logic_vector(63 downto 0) := x"DEADBEEFC007BABE";
    G_OFFSET : natural;
    G_DEBUG  : boolean;
    G_RANDOM : boolean;
    G_FIRST  : std_logic := 'U';
    G_FAST   : boolean
  );
  port (
    clk_i  : in    std_logic;
    rst_i  : in    std_logic;
    m_axil : view  axil_master_view
  );
end entity axil_master_sim;

architecture simulation of axil_master_sim is

  constant C_DATA_SIZE : positive := m_axil.wdata'length;

  signal   random_s : std_logic_vector(63 downto 0);

  subtype  R_DO_WRITE is natural range 16 downto 15;

  subtype  R_DO_READ is natural range 6 downto 5;

  subtype  R_BREADY is natural range 26 downto 35;

  subtype  R_RREADY is natural range 36 downto 35;

  signal   do_write : std_logic;
  signal   do_read  : std_logic;

  signal   write_req_cnt : natural range 0 to 100;
  signal   read_req_cnt  : natural range 0 to 100;

  signal   wr_ptr_stim : std_logic_vector(m_axil.awaddr'range);
  signal   rd_ptr_stim : std_logic_vector(m_axil.awaddr'range);
  signal   wr_ptr_resp : std_logic_vector(m_axil.awaddr'range);
  signal   rd_ptr_resp : std_logic_vector(m_axil.awaddr'range);

  pure function addr_to_data (
    addr : std_logic_vector
  ) return std_logic_vector is
  begin
    return to_stdlogicvector(2 ** (C_DATA_SIZE - 1) + G_OFFSET - to_integer(addr), C_DATA_SIZE);
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

  do_write      <= and(random_s(R_DO_WRITE)) when G_RANDOM else
                   '1';
  do_read       <= and(random_s(R_DO_READ)) when G_RANDOM else
                   '1';
  m_axil.bready <= and(random_s(R_BREADY)) when G_RANDOM else
                   '1';
  m_axil.rready <= and(random_s(R_RREADY)) when G_RANDOM else
                   '1';

  stimuli_proc : process (clk_i)
    variable new_write_req_cnt_v : natural;
    variable new_read_req_cnt_v  : natural;
    variable first_v             : boolean := true;
  begin
    if rising_edge(clk_i) then
      if first_v and rst_i = '0' then
        report "axil_master_sim: " & G_NAME & " Test started";
        first_v := false;
      end if;

      if m_axil.awready = '1' then
        m_axil.awvalid <= '0';
      end if;
      if m_axil.wready = '1' then
        m_axil.wvalid <= '0';
      end if;
      if m_axil.arready = '1' then
        m_axil.arvalid <= '0';
      end if;

      new_write_req_cnt_v := write_req_cnt;
      new_read_req_cnt_v  := read_req_cnt;

      -- Issue write request
      if do_write = '1'
         and ((G_FAST and m_axil.awready = '1') or m_axil.awvalid = '0')
         and ((G_FAST and m_axil.wready = '1') or m_axil.wvalid = '0') then
        if wr_ptr_stim + 1 = 0 then
          report "axil_master_sim: " & G_NAME & " Test finished";
          stop;
        else
          new_write_req_cnt_v := new_write_req_cnt_v + 1;
          m_axil.awvalid      <= '1';
          m_axil.awaddr       <= wr_ptr_stim;
          m_axil.wvalid       <= '1';
          m_axil.wdata        <= addr_to_data(wr_ptr_stim);
          m_axil.wstrb        <= (C_DATA_SIZE / 8 - 1 downto 0 => '1');
          wr_ptr_stim         <= wr_ptr_stim + 1;
          if G_DEBUG then
            report "axil_master_sim: " & G_NAME & " STIMULI: Write: " & to_hstring(wr_ptr_stim) &
                   " <- " & to_hstring(addr_to_data(wr_ptr_stim));
          end if;
        end if;
      end if;

      -- Receive write response
      if m_axil.bvalid = '1' and m_axil.bready = '1' then
        assert write_req_cnt > 0
          report "axil_master_sim: " & G_NAME & " Write not active";
        new_write_req_cnt_v := new_write_req_cnt_v - 1;
        assert m_axil.bresp = "00"
          report "axil_master_sim: " & G_NAME & " Incorrect m_bresp_i";
        wr_ptr_resp         <= wr_ptr_resp + 1;
      end if;

      -- Issue read request
      if do_read = '1'
         and rd_ptr_stim < wr_ptr_resp
         and ((G_FAST and m_axil.arready = '1') or m_axil.arvalid = '0') then
        if G_DEBUG then
          report "axil_master_sim: " & G_NAME & " STIMULI: Read: " & to_hstring(rd_ptr_stim);
        end if;
        new_read_req_cnt_v := new_read_req_cnt_v + 1;
        m_axil.arvalid     <= '1';
        m_axil.araddr      <= rd_ptr_stim;
        rd_ptr_stim        <= rd_ptr_stim + 1;
      end if;

      -- Receive read response
      if m_axil.rvalid = '1' and m_axil.rready = '1' then
        assert read_req_cnt > 0
          report "axil_master_sim: " & G_NAME & " Read not active";
        new_read_req_cnt_v := new_read_req_cnt_v - 1;
        assert m_axil.rresp = "00"
          report "axil_master_sim: " & G_NAME & " Incorrect m_rresp_i";
        assert m_axil.rdata = addr_to_data(rd_ptr_resp)
          report "axil_master_sim: " & G_NAME & " Read failure from address " & to_hstring(rd_ptr_resp) &
                 ". Got " & to_hstring(m_axil.rdata) &
                 ", expected " & to_hstring(addr_to_data(rd_ptr_resp));
        rd_ptr_resp        <= rd_ptr_resp + 1;
      end if;

      write_req_cnt <= new_write_req_cnt_v;
      read_req_cnt  <= new_read_req_cnt_v;

      if G_FIRST /= 'U' then
        m_axil.awaddr(m_axil.awaddr'left) <= G_FIRST;
        m_axil.araddr(m_axil.araddr'left) <= G_FIRST;
      end if;

      if rst_i = '1' then
        m_axil.awvalid <= '0';
        m_axil.wvalid  <= '0';
        m_axil.arvalid <= '0';
        write_req_cnt  <= 0;
        read_req_cnt   <= 0;
        wr_ptr_stim    <= (others => '0');
        wr_ptr_resp    <= (others => '0');
        rd_ptr_stim    <= (others => '0');
        rd_ptr_resp    <= (others => '0');
      end if;
    end if;
  end process stimuli_proc;

end architecture simulation;

