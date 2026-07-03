-- ---------------------------------------------------------------------------------------
-- Description : Converts a single-outstanding AXI-Lite slave interface into
--               single-beat Avalon-MM master transactions. Supports one
--               write and one read outstanding at a time; each Avalon
--               transfer has burstcount = 1.
--
-- Constraints :
--   * m_waitrequest_i must be registered by the Avalon slave for tight
--     timing closure; the bridge propagates it combinationally into
--     s_*ready_o.
--   * G_DATA_BITS must be a multiple of 8.
--
-- Responses   : s_bresp_o and s_rresp_o are always driven to OKAY ("00").
--               Avalon-MM does not surface error responses in this variant.
--
-- Reset       : Synchronous, active-high (rst_i).
-- payload outputs are 'U' until the first transaction; they are guaranteed
-- meaningful whenever the corresponding valid strobe is high
--
-- SPDX-License-Identifier: MIT
-- ---------------------------------------------------------------------------------------

library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std.all;

entity axil_to_avm is
  generic (
    G_ADDR_BITS  : positive;     -- Width of address bus (bits)
    G_DATA_BITS  : positive;     -- Width of data bus (bits, multiple of 8)
    G_BURST_BITS : positive := 8 -- Width of m_burstcount_o (bridge always uses 1)
  );
  port (
    clk_i             : in    std_logic;
    rst_i             : in    std_logic;

    -- AXI Lite interface (slave)
    s_awready_o       : out   std_logic;
    s_awvalid_i       : in    std_logic;
    s_awaddr_i        : in    std_logic_vector(G_ADDR_BITS - 1 downto 0);
    s_wready_o        : out   std_logic;
    s_wvalid_i        : in    std_logic;
    s_wdata_i         : in    std_logic_vector(G_DATA_BITS - 1 downto 0);
    s_wstrb_i         : in    std_logic_vector(G_DATA_BITS / 8 - 1 downto 0);
    s_bready_i        : in    std_logic;
    s_bvalid_o        : out   std_logic;
    s_bresp_o         : out   std_logic_vector(1 downto 0);
    s_arready_o       : out   std_logic;
    s_arvalid_i       : in    std_logic;
    s_araddr_i        : in    std_logic_vector(G_ADDR_BITS - 1 downto 0);
    s_rready_i        : in    std_logic;
    s_rvalid_o        : out   std_logic;
    s_rdata_o         : out   std_logic_vector(G_DATA_BITS - 1 downto 0);
    s_rresp_o         : out   std_logic_vector(1 downto 0);

    -- Avalon-MM master interface
    m_waitrequest_i   : in    std_logic;                                      -- Slave back-pressure.
    m_write_o         : out   std_logic;                                      -- Write request strobe.
    m_read_o          : out   std_logic;                                      -- Read request strobe.
    m_address_o       : out   std_logic_vector(G_ADDR_BITS - 1 downto 0);     -- Burst start address.
    m_writedata_o     : out   std_logic_vector(G_DATA_BITS - 1 downto 0);     -- Write data (per beat).
    m_byteenable_o    : out   std_logic_vector(G_DATA_BITS / 8 - 1 downto 0); -- Byte-lane enables (all-ones for reads).
    m_burstcount_o    : out   std_logic_vector(G_BURST_BITS - 1 downto 0);    -- Burst length in beats.
    m_readdatavalid_i : in    std_logic;                                      -- Read-data valid strobe (per beat).
    m_readdata_i      : in    std_logic_vector(G_DATA_BITS - 1 downto 0)      -- Read-data return (per beat).
  );
end entity axil_to_avm;

architecture rtl of axil_to_avm is

  -- Avalon burstcount = 1 (single-beat transfer, matches AXI-Lite semantics).
  constant C_BURST_ONE : std_logic_vector(G_BURST_BITS - 1 downto 0) := (0 => '1', others => '0');

  type     state_type is (
    IDLE_ST,      -- Ready to accept write, read, or both
    ISSUE_READ_ST -- Write is forwarded, waiting to forward read.
  );
  signal   state : state_type                                        := IDLE_ST;

  -- The following represent a completed handshake this cycle
  signal   aw_active : std_logic;
  signal   w_active  : std_logic;
  signal   ar_active : std_logic;

  -- '1' from the cycle the Avalon write is accepted (waitrequest went low with
  -- m_write_o high) until s_bvalid_o has been accepted by the AXI master.
  -- Used to gate s_awready_o / s_wready_o so at most one write is outstanding.
  signal   write_in_flight : std_logic;

  -- '1' from the cycle the Avalon read is accepted until m_readdatavalid_i
  -- fires (and the response is latched into s_rdata_o / s_rvalid_o). Gates
  -- s_arready_o so at most one read is outstanding.
  signal   read_in_flight : std_logic;

  -- Latched AR address for the "simultaneous AW+W+AR" case: the write is
  -- issued in the same cycle as the AR handshake, and the read is issued
  -- one cycle later from ISSUE_READ_ST.
  signal   pending_rd_addr : std_logic_vector(G_ADDR_BITS - 1 downto 0);

begin

  assert G_DATA_BITS mod 8 = 0
    report "axil_to_avm: G_DATA_BITS must be a multiple of 8"
    severity failure;

  aw_active   <= s_awvalid_i and s_awready_o;
  w_active    <= s_wvalid_i  and s_wready_o;
  ar_active   <= s_arvalid_i and s_arready_o;

  -- Main state machine

  s_awready_o <= s_wvalid_i and not m_waitrequest_i when state = IDLE_ST
                                                         and s_bvalid_o = '0'
                                                         and write_in_flight = '0' else
                 '0';
  s_wready_o  <= s_awvalid_i and not m_waitrequest_i when state = IDLE_ST
                                                          and s_bvalid_o = '0'
                                                          and write_in_flight = '0' else
                 '0';
  s_arready_o <= not m_waitrequest_i when state = IDLE_ST
                                          and s_rvalid_o = '0'
                                          and read_in_flight = '0' else
                 '0';

  fsm_proc : process (clk_i)
  begin
    if rising_edge(clk_i) then
      -- register the response to the previous cycle's accepted transaction
      if s_bready_i = '1' then
        s_bvalid_o <= '0';
      end if;
      if s_rready_i = '1' then
        s_rvalid_o <= '0';
      end if;
      if m_waitrequest_i = '0' then
        m_write_o <= '0';
        m_read_o  <= '0';
        if m_write_o = '1' then
          s_bvalid_o      <= '1';
          s_bresp_o       <= (others => '0');
          write_in_flight <= '0';
        end if;
      end if;
      if m_readdatavalid_i = '1' then
        s_rvalid_o     <= '1';
        s_rdata_o      <= m_readdata_i;
        s_rresp_o      <= (others => '0');
        read_in_flight <= '0';
      end if;

      case state is

        when IDLE_ST =>
          if aw_active = '1' and w_active = '1' then
            m_write_o       <= '1';
            m_read_o        <= '0';
            m_address_o     <= s_awaddr_i;
            m_writedata_o   <= s_wdata_i;
            m_byteenable_o  <= s_wstrb_i;
            m_burstcount_o  <= C_BURST_ONE;
            write_in_flight <= '1';
            -- Stay in IDLE_ST, unless a read is simultaneous
            if ar_active = '1' then
              pending_rd_addr <= s_araddr_i;
              state           <= ISSUE_READ_ST;
            end if;
          elsif ar_active = '1' then
            m_write_o      <= '0';
            m_read_o       <= '1';
            m_address_o    <= s_araddr_i;
            m_byteenable_o <= (others => '1');
            m_burstcount_o <= C_BURST_ONE;
            read_in_flight <= '1';
          end if;

        when ISSUE_READ_ST =>
          if m_waitrequest_i = '0' then
            -- m_write_o is already '0' by this point (cleared by the top-of-process
            -- write-completion block, since the pending write's waitrequest fell in
            -- the previous cycle). Only drive the new read here.
            m_read_o       <= '1';
            m_address_o    <= pending_rd_addr;
            m_byteenable_o <= (others => '1');
            m_burstcount_o <= C_BURST_ONE;
            read_in_flight <= '1';
            state          <= IDLE_ST;
          end if;

      end case;

      -- synchronous reset overrides above.
      if rst_i = '1' then
        s_bvalid_o      <= '0';
        s_rvalid_o      <= '0';
        m_write_o       <= '0';
        m_read_o        <= '0';
        read_in_flight  <= '0';
        write_in_flight <= '0';
        state           <= IDLE_ST;
      end if;
    end if;
  end process fsm_proc;

end architecture rtl;

