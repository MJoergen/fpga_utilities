-- ---------------------------------------------------------------------------------------
-- Title       : axip_dropper - Conditional AXI-stream packet forwarder
-- Description : Buffers each incoming packet in full and, on the cycle where
--               s_last_i = '1', samples s_drop_i to decide its fate:
--                  s_drop_i = '0' -> packet is queued for downstream transmission
--                  s_drop_i = '1' -> packet is silently discarded (write pointer
--                                    is rewound to the start of the frame)
--
--               End-of-frame pointers for accepted packets are pushed into a
--               small auxiliary FIFO (axis_fifo) so that several completed
--               packets may be queued without back-pressuring the input while
--               the downstream consumer is slow.
--
-- Sizing      : The data buffer holds 2**G_ADDR_BITS - 1 usable words (one slot
--               is reserved by the full/empty distinction). It MUST be able to
--               hold the largest possible incoming frame; an undersized buffer
--               will deadlock because s_ready_o stays low while s_last_i never
--               arrives.
--
-- Latency     : Forwarded packets appear on the master interface no earlier
--               than two clock cycles after s_last_i = '1' is accepted (one
--               cycle to push into the pointer FIFO, one cycle for the output
--               FSM to react in IDLE_ST).
--
-- Reset       : Synchronous, active-high (rst_i).
--
-- SPDX-License-Identifier: MIT
-- ---------------------------------------------------------------------------------------

library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std.all;
  use work.axip_pkg.all;

entity axip_dropper is
  generic (
    G_ADDR_BITS  : positive; -- Buffer depth = 2**G_ADDR_BITS words (one slot reserved)
    G_DATA_BYTES : positive  -- Width of each beat in bytes; bus is 8*G_DATA_BYTES bits
  );
  port (
    clk_i     : in    std_logic;
    rst_i     : in    std_logic;                       -- Synchronous active-high reset

    -- Slave (input) AXI-stream-like interface. Standard valid/ready handshake:
    -- a transfer occurs on a rising edge of clk_i when both s_valid_i and
    -- s_ready_o are '1'. s_drop_i is only sampled in the same cycle as s_last_i.
    s_ready_o : out   std_logic;
    s_valid_i : in    std_logic;
    s_data_i  : in    std_logic_vector(G_DATA_BYTES * 8 - 1 downto 0);
    s_last_i  : in    std_logic;                       -- End-of-frame marker
    s_bytes_i : in    natural range 0 to G_DATA_BYTES; -- Valid bytes in this beat;
    -- 0 is illegal and is flagged
    -- by an assertion below
    s_drop_i  : in    std_logic;                       -- Sampled when s_last_i = '1'

    -- Master (output) AXI-stream-like interface. Only complete, accepted frames
    -- are presented; partial or dropped frames never reach this port.
    m_ready_i : in    std_logic;
    m_valid_o : out   std_logic;
    m_data_o  : out   std_logic_vector(G_DATA_BYTES * 8 - 1 downto 0);
    m_last_o  : out   std_logic;
    m_bytes_o : out   natural range 0 to G_DATA_BYTES
  );
end entity axip_dropper;

architecture rtl of axip_dropper is

  -- Each buffer slot stores one beat: the raw data word plus a 16-bit field
  -- carrying the encoded byte-valid count produced by bytes_to_slv() from
  -- axip_pkg. The constant 16 must match the width returned by bytes_to_slv.
  constant C_BUF_BITS : natural                            := G_DATA_BYTES * 8 + C_BYTES_FIELD_BITS;

  -- Bit-ranges into a single buffer slot:
  subtype  R_BUF_DATA  is natural range G_DATA_BYTES * 8 - 1 downto 0;                                     -- payload
  subtype  R_BUF_BYTES is natural range G_DATA_BYTES * 8 + C_BYTES_FIELD_BITS - 1 downto G_DATA_BYTES * 8; -- byte count

  -- Frame data buffer. Note: this is NOT a plain FIFO because the write side
  -- may rewind wrptr to first_ptr when a frame is dropped, intentionally
  -- overwriting words that have not yet been (and will never be) read.
  type     buf_type is array (0 to 2 ** G_ADDR_BITS - 1) of std_logic_vector(C_BUF_BITS - 1 downto 0);
  signal   rx_buf : buf_type                               := (others => (others => '0'));

  -- Write pointer: index of the NEXT slot to be written.
  signal   wrptr      : unsigned(G_ADDR_BITS - 1 downto 0) := (others => '0');
  -- wrptr + 1 (mod depth)
  signal   wrptr_next : unsigned(G_ADDR_BITS - 1 downto 0) := (others => '0');

  -- Read pointer: index of the NEXT slot to be read.
  signal   rdptr      : unsigned(G_ADDR_BITS - 1 downto 0) := (others => '0');
  -- rdptr + 1 (mod depth)
  signal   rdptr_next : unsigned(G_ADDR_BITS - 1 downto 0) := (others => '0');

  -- Index of the FIRST word of the frame currently being received.
  -- Used to rewind wrptr when a frame is dropped.
  --
  -- Invariant: first_ptr is the slot at which the current in-progress
  -- frame began. It advances only on an accepted end-of-frame; a dropped
  -- frame leaves it unchanged so the next frame reuses the same slo
  signal   first_ptr : unsigned(G_ADDR_BITS - 1 downto 0)  := (others => '0');

  -- Index of the LAST word of the frame currently being transmitted (read side).
  -- Latched from the pointer FIFO when leaving IDLE_ST.
  signal   last_ptr : unsigned(G_ADDR_BITS - 1 downto 0)   := (others => '0');

  -- Pointer FIFO: holds the end-of-frame index for every accepted frame that
  -- has been written into rx_buf but not yet fully read out. Sized identically
  -- to the data buffer so it can never become the throughput bottleneck.
  signal   fifo_wr_ready : std_logic;
  signal   fifo_wr_valid : std_logic;
  signal   fifo_wr_data  : std_logic_vector(G_ADDR_BITS - 1 downto 0);
  signal   fifo_rd_ready : std_logic;
  signal   fifo_rd_data  : std_logic_vector(G_ADDR_BITS - 1 downto 0);
  signal   fifo_rd_valid : std_logic;

  -- Output FSM:
  --   IDLE_ST : waiting for the next end-pointer from the FIFO; on arrival,
  --             the first word of the new frame is emitted immediately.
  --   FWD_ST  : streaming the body of the current frame until rdptr = last_ptr.
  type     fsm_state_type is (IDLE_ST, FWD_ST);
  signal   fsm_state : fsm_state_type                      := IDLE_ST;

begin

  wrptr_next <= wrptr + 1;
  rdptr_next <= rdptr + 1;

  -- Backpressure: stall the input when either the data buffer is full
  -- (wrptr_next would collide with rdptr) or the pointer FIFO cannot
  -- accept another end-of-frame entry.
  s_ready_o  <= '1' when s_valid_i = '1' and s_last_i = '1' and s_drop_i = '1' else
                '1' when wrptr_next /= rdptr and fifo_wr_ready = '1' else
                '0';


  -- ---------------------------------------------------------------
  -- Input process: writes incoming beats into rx_buf, decides at
  -- end-of-frame whether to commit (push end-pointer into FIFO) or
  -- drop (rewind wrptr) the frame, and resets the write side.
  -- ---------------------------------------------------------------

  input_proc : process (clk_i)
  begin
    if rising_edge(clk_i) then
      fifo_wr_valid <= '0';

      -- A beat with zero valid bytes carries no payload and would corrupt
      -- m_bytes_o framing downstream; treat it as a design error.
      assert not (s_valid_i = '1' and s_bytes_i = 0 and rst_i = '0')
        report "axip_dropper: BYTES = 0 is not allowed"
        severity failure;

      if s_valid_i = '1' and s_ready_o = '1' then
        -- Store word in frame buffer
        rx_buf(to_integer(wrptr))(R_BUF_BYTES) <= bytes_to_slv(s_bytes_i);
        rx_buf(to_integer(wrptr))(R_BUF_DATA)  <= s_data_i;
        wrptr                                  <= wrptr_next;

        if s_last_i = '1' then
          if s_drop_i = '1' then
            -- Drop the frame: rewind wrptr to the start of this frame so the
            -- slots it occupied are reclaimed for the next incoming frame.
            wrptr <= first_ptr;
          else
            -- Accept the frame: push the index of this (last) word into the
            -- pointer FIFO. The output FSM will stream rx_buf from rdptr up
            -- to and including this index.
            fifo_wr_data  <= std_logic_vector(wrptr);
            fifo_wr_valid <= '1';
            -- Mark the slot AFTER this last word as the start of the next frame.
            first_ptr     <= wrptr_next;
          end if;
        end if;
      end if;

      -- Synchronous reset overrides above logic.
      if rst_i = '1' then
        fifo_wr_valid <= '0';
        first_ptr     <= (others => '0');
        wrptr         <= (others => '0');
      end if;
    end if;
  end process input_proc;


  ----------------------------------------------------
  -- FIFO containing "end pointer" for each frame
  ----------------------------------------------------

  axis_fifo_inst : entity work.axis_fifo
    generic map (
      G_ADDR_BITS => G_ADDR_BITS,
      G_DATA_BITS => G_ADDR_BITS
    )
    port map (
      clk_i     => clk_i,
      rst_i     => rst_i,
      s_ready_o => fifo_wr_ready,
      s_valid_i => fifo_wr_valid,
      s_data_i  => fifo_wr_data,
      m_ready_i => fifo_rd_ready,
      m_valid_o => fifo_rd_valid,
      m_data_o  => fifo_rd_data
    ); -- axis_fifo_inst


  -- Pop the next end-pointer when we are idle and either the master is
  -- ready to accept a new beat, or no beat is currently being held on the
  -- output. This guarantees the first word of every frame is emitted in
  -- the same cycle the pointer is popped, minimising start-of-frame latency.
  fifo_rd_ready <= '1' when fsm_state = IDLE_ST and (m_ready_i = '1' or m_valid_o = '0') else
                   '0';


  -- ---------------------------------------------------------------
  -- Output process: pops end-of-frame indices from the pointer FIFO
  -- and streams each frame from rx_buf onto the master interface
  -- using a two-state FSM (IDLE_ST -> FWD_ST -> IDLE_ST).
  -- ---------------------------------------------------------------

  output_proc : process (clk_i)
  begin
    if rising_edge(clk_i) then
      if m_ready_i = '1' then
        m_valid_o <= '0';
      end if;

      case fsm_state is

        when IDLE_ST =>
          if fifo_rd_valid = '1' and fifo_rd_ready = '1' then
            -- Latch end-of-frame index and emit the first beat of the new frame.
            last_ptr  <= unsigned(fifo_rd_data);
            m_valid_o <= '1';
            m_last_o  <= '0';
            m_bytes_o <= slv_to_bytes(rx_buf(to_integer(rdptr))(R_BUF_BYTES));
            m_data_o  <= rx_buf(to_integer(rdptr))(R_BUF_DATA);
            rdptr     <= rdptr_next;
            -- Special case: single-word frame. The first beat is also the last,
            -- so assert m_last_o and stay in IDLE_ST instead of entering FWD_ST.
            if rdptr = unsigned(fifo_rd_data) then
              m_last_o  <= '1';
              fsm_state <= IDLE_ST;
            else
              fsm_state <= FWD_ST;
            end if;
          end if;

        when FWD_ST =>
          if m_ready_i = '1' then
            -- Emit the next beat of the in-flight frame; transition back to
            -- IDLE_ST when the beat we just scheduled is the final word.
            m_valid_o <= '1';
            m_last_o  <= '0';
            m_bytes_o <= slv_to_bytes(rx_buf(to_integer(rdptr))(R_BUF_BYTES));
            m_data_o  <= rx_buf(to_integer(rdptr))(R_BUF_DATA);
            rdptr     <= rdptr_next;
            if rdptr = last_ptr then
              m_last_o  <= '1';
              fsm_state <= IDLE_ST;
            else
              fsm_state <= FWD_ST;
            end if;
          end if;


      end case;

      -- Synchronous reset overrides above logic.
      if rst_i = '1' then
        m_valid_o <= '0';
        rdptr     <= (others => '0');
        fsm_state <= IDLE_ST;
      end if;
    end if;
  end process output_proc;

end architecture rtl;

