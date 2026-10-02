-- ---------------------------------------------------------------------------------------
-- Description: This provides stimulus to and verifies response from an AXI lite
-- interface.  It generates a sequence of Writes and Reads, and verifies that the values
-- returned from Read matches the corresponding values during Write.  This module may
-- generate simultaneous read and write requests, without first waiting for a response.
--
-- With G_RANDOM_WSTRB = true, each write uses a random WSTRB (at least one lane enabled).
-- Lanes that are not enabled carry a deliberately wrong value, and the read-back check
-- verifies both that the enabled lanes were written and that the other lanes were not.
--
-- SPDX-License-Identifier: MIT
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
    G_ADDR_BITS : natural;
    G_DATA_BITS : natural;
    G_RANDOM_WSTRB : boolean := false
  );
  port (
    clk_i       : in    std_logic;
    rst_i       : in    std_logic;

    m_awready_i : in    std_logic;
    m_awvalid_o : out   std_logic;
    m_awaddr_o  : out   std_logic_vector(G_ADDR_BITS - 1 downto 0);
    m_wready_i  : in    std_logic;
    m_wvalid_o  : out   std_logic;
    m_wdata_o   : out   std_logic_vector(G_DATA_BITS - 1 downto 0);
    m_wstrb_o   : out   std_logic_vector(G_DATA_BITS / 8 - 1 downto 0);
    m_bready_o  : out   std_logic;
    m_bvalid_i  : in    std_logic;
    m_bresp_i   : in    std_logic_vector(1 downto 0);
    m_arready_i : in    std_logic;
    m_arvalid_o : out   std_logic;
    m_araddr_o  : out   std_logic_vector(G_ADDR_BITS - 1 downto 0);
    m_rready_o  : out   std_logic;
    m_rvalid_i  : in    std_logic;
    m_rdata_i   : in    std_logic_vector(G_DATA_BITS - 1 downto 0);
    m_rresp_i   : in    std_logic_vector(1 downto 0)
  );
end entity axil_master_sim;

architecture simulation of axil_master_sim is

  signal  random_s : std_logic_vector(63 downto 0);

  subtype R_DO_WRITE is natural range 16 downto 15;

  subtype R_DO_READ is natural range 6 downto 5;

  subtype R_BREADY is natural range 26 downto 25;

  subtype R_RREADY is natural range 36 downto 35;

  signal  do_write : std_logic;
  signal  do_read  : std_logic;

  signal  write_req_cnt : natural range 0 to 100;
  signal  read_req_cnt  : natural range 0 to 100;

  signal  wr_ptr_stim : std_logic_vector(G_ADDR_BITS - 1 downto 0);
  signal  rd_ptr_stim : std_logic_vector(G_ADDR_BITS - 1 downto 0);
  signal  wr_ptr_resp : std_logic_vector(G_ADDR_BITS - 1 downto 0);
  signal  rd_ptr_resp : std_logic_vector(G_ADDR_BITS - 1 downto 0);

  pure function addr_to_data (
    addr : std_logic_vector
  ) return std_logic_vector is
  begin
    return to_stdlogicvector(2 ** (G_DATA_BITS - 1) + G_OFFSET - to_integer(addr),
    G_DATA_BITS);
  end function addr_to_data;

  constant C_STRB_BITS : natural := G_DATA_BITS / 8;

  -- Bit-field selector within random_s used for a random WSTRB.
  subtype  R_WSTRB is natural range 48 + C_STRB_BITS - 1 downto 48;

  -- WSTRB used for the write to each address.
  type     strb_mem_type is array (natural range <>) of std_logic_vector(C_STRB_BITS - 1 downto 0);
  signal   strb_mem : strb_mem_type(0 to 2 ** G_ADDR_BITS - 1);

  -- Value driven on a byte lane that is not enabled. It differs from the expected
  -- byte, and is never zero, so it can be told apart both from the expected data and
  -- from memory that was never written (zero or 'U').
  pure function garbage_byte (
    b : std_logic_vector(7 downto 0)
  ) return std_logic_vector is
    variable res_v : std_logic_vector(7 downto 0);
  begin
    res_v := b xor X"A5";
    if res_v = X"00" then
      res_v := X"5A";
    end if;
    return res_v;
  end function garbage_byte;

  -- Write data: the expected data on enabled lanes, and garbage elsewhere.
  pure function strb_data (
    data : std_logic_vector(G_DATA_BITS - 1 downto 0);
    strb : std_logic_vector(C_STRB_BITS - 1 downto 0)
  ) return std_logic_vector is
    variable res_v : std_logic_vector(G_DATA_BITS - 1 downto 0);
  begin
    for i in 0 to C_STRB_BITS - 1 loop
      if strb(i) = '1' then
        res_v(8 * i + 7 downto 8 * i) := data(8 * i + 7 downto 8 * i);
      else
        res_v(8 * i + 7 downto 8 * i) := garbage_byte(data(8 * i + 7 downto 8 * i));
      end if;
    end loop;
    return res_v;
  end function strb_data;

begin

  assert C_STRB_BITS <= 16
    report "AxiLite MASTER: " & G_NAME & " G_DATA_BITS must be at most 128"
    severity failure;

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
    variable strb_v              : std_logic_vector(C_STRB_BITS - 1 downto 0);
    variable exp_v               : std_logic_vector(G_DATA_BITS - 1 downto 0);
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
      if do_write = '1' and rst_i = '0'
         and ((G_FAST and m_awready_i = '1') or m_awvalid_o = '0')
         and ((G_FAST and m_wready_i = '1') or m_wvalid_o = '0') then
        if wr_ptr_stim + 1 = 0 then
          report "AxiLite MASTER: " & G_NAME & " Test finished";
          stop;
        else
          strb_v := (others => '1');
          if G_RANDOM_WSTRB then
            strb_v := random_s(R_WSTRB);
            if strb_v = 0 then
              strb_v(0) := '1';
            end if;
          end if;
          new_write_req_cnt_v                := new_write_req_cnt_v + 1;
          m_awvalid_o                        <= '1';
          m_awaddr_o                         <= wr_ptr_stim;
          m_wvalid_o                         <= '1';
          m_wdata_o                          <= strb_data(addr_to_data(wr_ptr_stim), strb_v);
          m_wstrb_o                          <= strb_v;
          strb_mem(to_integer(wr_ptr_stim))  <= strb_v;
          wr_ptr_stim                        <= wr_ptr_stim + 1;
          if G_DEBUG then
            report "AxiLite MASTER: " & G_NAME & " Write: " & to_hstring(wr_ptr_stim) &
                   " <- " & to_hstring(strb_data(addr_to_data(wr_ptr_stim), strb_v)) &
                   " strb " & to_hstring(strb_v);
          end if;
        end if;
      end if;

      -- Receive write response
      if m_bvalid_i = '1' and m_bready_o = '1' then
        assert write_req_cnt > 0
          report "AxiLite MASTER: " & G_NAME & " Write not active";
        new_write_req_cnt_v := new_write_req_cnt_v - 1;
        assert m_bresp_i = "00"
          report "AxiLite MASTER: " & G_NAME & " Incorrect m_bresp_i";
        wr_ptr_resp         <= wr_ptr_resp + 1;
      end if;

      -- Issue read request
      if do_read = '1'
         and rd_ptr_stim < wr_ptr_resp
         and ((G_FAST and m_arready_i = '1') or m_arvalid_o = '0') then
        if G_DEBUG then
          report "AxiLite MASTER: " & G_NAME & " Read: " & to_hstring(rd_ptr_stim);
        end if;
        new_read_req_cnt_v := new_read_req_cnt_v + 1;
        m_arvalid_o        <= '1';
        m_araddr_o         <= rd_ptr_stim;
        rd_ptr_stim        <= rd_ptr_stim + 1;
      end if;

      -- Receive read response
      if m_rvalid_i = '1' and m_rready_o = '1' then
        assert read_req_cnt > 0
          report "AxiLite MASTER: " & G_NAME & " Read not active";
        new_read_req_cnt_v := new_read_req_cnt_v - 1;
        assert m_rresp_i = "00"
          report "AxiLite MASTER: " & G_NAME & " Incorrect m_rresp_i";
        -- Enabled lanes must hold the expected data, and the other lanes must
        -- not hold the garbage that was written to them.
        exp_v  := addr_to_data(rd_ptr_resp);
        strb_v := strb_mem(to_integer(rd_ptr_resp));
        for i in 0 to C_STRB_BITS - 1 loop
          if strb_v(i) = '1' then
            assert m_rdata_i(8 * i + 7 downto 8 * i) = exp_v(8 * i + 7 downto 8 * i)
              report "AxiLite MASTER: " & G_NAME & " Read failure from address " & to_hstring(rd_ptr_resp) &
                     ". Got " & to_hstring(m_rdata_i) &
                     ", expected " & to_hstring(exp_v) &
                     " in byte lane " & integer'image(i);
          else
            assert m_rdata_i(8 * i + 7 downto 8 * i) /= garbage_byte(exp_v(8 * i + 7 downto 8 * i))
              report "AxiLite MASTER: " & G_NAME & " Byte lane " & integer'image(i) &
                     " of address " & to_hstring(rd_ptr_resp) &
                     " was written although WSTRB was low. Got " & to_hstring(m_rdata_i);
          end if;
        end loop;
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

