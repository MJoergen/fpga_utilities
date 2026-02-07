-- ---------------------------------------------------------------------------------------
-- Description: Arbitrate between two different AXI Lite masters. If both Masters request
-- simultaneously, then they are granted access alternately.
--
-- This is similar to the 2-1 AXI crossbar, see:
-- https://www.xilinx.com/support/documents/ip_documentation/axi_interconnect/v2_1/pg059-axi-interconnect.pdf
--
-- The implementation is split into writing and reading, each of which is handled
-- separately and (almost) independently.
-- ---------------------------------------------------------------------------------------

library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std.all;

library work;
  use work.axil_pkg.all;

entity axil_arbiter is
  port (
    clk_i   : in    std_logic;
    rst_i   : in    std_logic;
    s0_axil : view  axil_slave_view;
    s1_axil : view  axil_slave_view;
    m_axil  : view  axil_master_view
  );
end entity axil_arbiter;

architecture synthesis of axil_arbiter is

begin

  write_block : block is

    type   write_state_type is (
      WRITE_INPUT_0_IDLE_ST, WRITE_INPUT_0_AW_BUSY_ST, WRITE_INPUT_0_W_BUSY_ST, WRITE_INPUT_0_WRITING_ST,
      WRITE_INPUT_1_IDLE_ST, WRITE_INPUT_1_AW_BUSY_ST, WRITE_INPUT_1_W_BUSY_ST, WRITE_INPUT_1_WRITING_ST
    );
    signal write_state    : write_state_type := WRITE_INPUT_0_IDLE_ST;

    signal s0_awactive    : std_logic;
    signal s0_wactive     : std_logic;
    signal s1_awactive    : std_logic;
    signal s1_wactive     : std_logic;
    signal m_bactive      : std_logic;
    signal write_select_0 : std_logic;
    signal accept_aw_0    : std_logic;
    signal accept_w_0     : std_logic;
    signal accept_aw_1    : std_logic;
    signal accept_w_1     : std_logic;

  begin

    s0_awactive     <= s0_axil.awvalid and s0_axil.awready;
    s0_wactive      <= s0_axil.wvalid and s0_axil.wready;

    s1_awactive     <= s1_axil.awvalid and s1_axil.awready;
    s1_wactive      <= s1_axil.wvalid and s1_axil.wready;

    m_bactive       <= m_axil.bvalid and m_axil.bready;

    write_select_0  <= '1' when write_state = WRITE_INPUT_0_IDLE_ST or
                                write_state = WRITE_INPUT_0_AW_BUSY_ST or
                                write_state = WRITE_INPUT_0_W_BUSY_ST or
                                write_state = WRITE_INPUT_0_WRITING_ST else
                       '0';

    accept_aw_0     <= '1' when write_state = WRITE_INPUT_0_IDLE_ST or
                                write_state = WRITE_INPUT_0_W_BUSY_ST else
                       '0';

    accept_w_0      <= '1' when write_state = WRITE_INPUT_0_IDLE_ST or
                                write_state = WRITE_INPUT_0_AW_BUSY_ST else
                       '0';

    accept_aw_1     <= '1' when write_state = WRITE_INPUT_1_IDLE_ST or
                                write_state = WRITE_INPUT_1_W_BUSY_ST else
                       '0';

    accept_w_1      <= '1' when write_state = WRITE_INPUT_1_IDLE_ST or
                                write_state = WRITE_INPUT_1_AW_BUSY_ST else
                       '0';

    write_state_proc : process (clk_i)
    begin
      if rising_edge(clk_i) then

        case write_state is

          when WRITE_INPUT_0_IDLE_ST =>
            if (s1_axil.awvalid = '1' or s1_axil.wvalid = '1') and
               (s0_axil.awvalid = '0' and s0_axil.wvalid = '0') then
              write_state <= WRITE_INPUT_1_IDLE_ST;
            end if;

            if s0_awactive = '1' and s0_wactive = '0' then
              write_state <= WRITE_INPUT_0_AW_BUSY_ST;
            end if;

            if s0_awactive = '0' and s0_wactive = '1' then
              write_state <= WRITE_INPUT_0_W_BUSY_ST;
            end if;

            if s0_awactive = '1' and s0_wactive = '1' then
              write_state <= WRITE_INPUT_0_WRITING_ST;
            end if;

          when WRITE_INPUT_0_AW_BUSY_ST =>
            if s0_wactive = '1' then
              write_state <= WRITE_INPUT_0_WRITING_ST;
            end if;

          when WRITE_INPUT_0_W_BUSY_ST =>
            if s0_awactive = '1' then
              write_state <= WRITE_INPUT_0_WRITING_ST;
            end if;

          when WRITE_INPUT_0_WRITING_ST =>
            if m_bactive = '1' then
              write_state <= WRITE_INPUT_1_IDLE_ST;
            end if;

          when WRITE_INPUT_1_IDLE_ST =>
            if (s0_axil.awvalid = '1' or s0_axil.wvalid = '1') and
               (s1_axil.awvalid = '0' and s1_axil.wvalid = '0') then
              write_state <= WRITE_INPUT_0_IDLE_ST;
            end if;

            if s1_awactive = '1' and s1_wactive = '0' then
              write_state <= WRITE_INPUT_1_AW_BUSY_ST;
            end if;

            if s1_awactive = '0' and s1_wactive = '1' then
              write_state <= WRITE_INPUT_1_W_BUSY_ST;
            end if;

            if s1_awactive = '1' and s1_wactive = '1' then
              write_state <= WRITE_INPUT_1_WRITING_ST;
            end if;

          when WRITE_INPUT_1_AW_BUSY_ST =>
            if s1_wactive = '1' then
              write_state <= WRITE_INPUT_1_WRITING_ST;
            end if;

          when WRITE_INPUT_1_W_BUSY_ST =>
            if s1_awactive = '1' then
              write_state <= WRITE_INPUT_1_WRITING_ST;
            end if;

          when WRITE_INPUT_1_WRITING_ST =>
            if m_bactive = '1' then
              write_state <= WRITE_INPUT_0_IDLE_ST;
            end if;

        end case;

        if rst_i = '1' then
          write_state <= WRITE_INPUT_0_IDLE_ST;
        end if;
      end if;
    end process write_state_proc;


    m_axil.awvalid  <= (s0_axil.awvalid and accept_aw_0) or (s1_axil.awvalid and accept_aw_1);
    m_axil.awaddr   <= s0_axil.awaddr when write_select_0 = '1' else
                       s1_axil.awaddr;
    m_axil.wvalid   <= (s0_axil.wvalid and accept_w_0) or (s1_axil.wvalid and accept_w_1);
    m_axil.wdata    <= s0_axil.wdata when write_select_0 = '1' else
                       s1_axil.wdata;
    m_axil.wstrb    <= s0_axil.wstrb when write_select_0 = '1' else
                       s1_axil.wstrb;
    m_axil.bready   <= s0_axil.bready when write_select_0 = '1' else
                       s1_axil.bready;

    s0_axil.awready <= m_axil.awready and accept_aw_0;
    s1_axil.awready <= m_axil.awready and accept_aw_1;
    s0_axil.wready  <= m_axil.wready and accept_w_0;
    s1_axil.wready  <= m_axil.wready and accept_w_1;
    s0_axil.bvalid  <= m_axil.bvalid and write_select_0;
    s1_axil.bvalid  <= m_axil.bvalid and not write_select_0;
    s0_axil.bresp   <= m_axil.bresp;
    s1_axil.bresp   <= m_axil.bresp;

  end block write_block;

  read_block : block is

    type   read_state_type is (
      READ_INPUT_0_IDLE_ST, READ_INPUT_0_READING_ST,
      READ_INPUT_1_IDLE_ST, READ_INPUT_1_READING_ST
    );
    signal read_state    : read_state_type := READ_INPUT_0_IDLE_ST;

    signal s0_aractive   : std_logic;
    signal s1_aractive   : std_logic;
    signal m_ractive     : std_logic;
    signal accept_ar_0   : std_logic;
    signal accept_ar_1   : std_logic;
    signal read_select_0 : std_logic;
    signal s0_writing    : std_logic;
    signal s1_writing    : std_logic;

  begin

    s0_writing <= s0_axil.awvalid or s0_axil.wvalid;
    s1_writing <= s1_axil.awvalid or s1_axil.wvalid;

    s0_aractive     <= s0_axil.arvalid and s0_axil.arready;
    s1_aractive     <= s1_axil.arvalid and s1_axil.arready;

    m_ractive       <= m_axil.rvalid and m_axil.rready;

    accept_ar_0     <= '1' when read_state = READ_INPUT_0_IDLE_ST else
                       '0';

    accept_ar_1     <= '1' when read_state = READ_INPUT_1_IDLE_ST else
                       '0';

    read_select_0   <= '1' when read_state = READ_INPUT_0_IDLE_ST or
                                read_state = READ_INPUT_0_READING_ST else
                       '0';

    read_state_proc : process (clk_i)
    begin
      if rising_edge(clk_i) then

        case read_state is

          when READ_INPUT_0_IDLE_ST =>
            if (s1_writing = '1' or s1_axil.arvalid = '1') and
               (s0_writing = '0' and s0_axil.arvalid = '0') then
              read_state <= READ_INPUT_1_IDLE_ST;
            end if;

            if s0_aractive = '1' then
              read_state <= READ_INPUT_0_READING_ST;
            end if;

          when READ_INPUT_0_READING_ST =>
            if m_ractive = '1' then
              read_state <= READ_INPUT_1_IDLE_ST;
            end if;

          when READ_INPUT_1_IDLE_ST =>
            if (s0_writing = '1' or s0_axil.arvalid = '1') and
               (s1_writing = '0' and s1_axil.arvalid = '0') then
              read_state <= READ_INPUT_0_IDLE_ST;
            end if;

            if s1_aractive = '1' then
              read_state <= READ_INPUT_1_READING_ST;
            end if;

          when READ_INPUT_1_READING_ST =>
            if m_ractive = '1' then
              read_state <= READ_INPUT_0_IDLE_ST;
            end if;

        end case;

        if rst_i = '1' then
          read_state <= READ_INPUT_0_IDLE_ST;
        end if;
      end if;
    end process read_state_proc;

    m_axil.arvalid  <= (s0_axil.arvalid and accept_ar_0) or (s1_axil.arvalid and accept_ar_1);
    m_axil.araddr   <= s0_axil.araddr when read_select_0 = '1' else
                       s1_axil.araddr;
    m_axil.rready   <= s0_axil.rready when read_select_0 = '1' else
                       s1_axil.rready;

    s0_axil.arready <= m_axil.arready and accept_ar_0;
    s1_axil.arready <= m_axil.arready and accept_ar_1;
    s0_axil.rvalid  <= m_axil.rvalid and read_select_0;
    s1_axil.rvalid  <= m_axil.rvalid and not read_select_0;
    s0_axil.rdata   <= m_axil.rdata;
    s1_axil.rdata   <= m_axil.rdata;
    s0_axil.rresp   <= m_axil.rresp;
    s1_axil.rresp   <= m_axil.rresp;

  end block read_block;

end architecture synthesis;

