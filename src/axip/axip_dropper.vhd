-- ---------------------------------------------------------------------------------------
-- Description: Conditional packet forwarder. Each incoming packet is buffered until
-- s_last_i = 1, at which point s_drop_i selects whether to forward (s_drop_i = 0) or
-- discard (s_drop_i = 1) the buffered packet. The buffer must be large enough to hold
-- the longest packet. End-of-frame pointers for forwarded packets are queued in a small
-- FIFO so multiple completed packets can be presented to downstream without forcing the
-- upstream to wait.
--
-- buffer size 2^G_ADDR_BITS words must fit at least the largest possible incoming frame;
-- smaller buffers will deadlock
--
-- SPDX-License-Identifier: MIT
-- ---------------------------------------------------------------------------------------

library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std.all;
  use work.axip_pkg.all;

entity axip_dropper is
  generic (
    G_ADDR_BITS  : positive; -- Controls size of frame buffer
    G_DATA_BYTES : positive  -- Number of bytes in each beat
  );
  port (
    clk_i     : in    std_logic;
    rst_i     : in    std_logic;

    -- Input interface
    s_ready_o : out   std_logic;
    s_valid_i : in    std_logic;
    s_data_i  : in    std_logic_vector(G_DATA_BYTES * 8 - 1 downto 0);
    s_last_i  : in    std_logic;
    s_bytes_i : in    natural range 0 to G_DATA_BYTES;
    s_drop_i  : in    std_logic; -- Sampled when s_last_i = 1

    -- Output interface
    m_ready_i : in    std_logic;
    m_valid_o : out   std_logic;
    m_data_o  : out   std_logic_vector(G_DATA_BYTES * 8 - 1 downto 0);
    m_last_o  : out   std_logic;
    m_bytes_o : out   natural range 0 to G_DATA_BYTES
  );
end entity axip_dropper;

architecture rtl of axip_dropper is

  constant C_BUF_BITS : natural                                := G_DATA_BYTES * 8 + 16;
  subtype  R_BUF_DATA  is natural range G_DATA_BYTES * 8 - 1 downto 0;
  subtype  R_BUF_BYTES is natural range G_DATA_BYTES * 8 + 15 downto G_DATA_BYTES * 8;

  -- Buffer containing the packet data
  -- This is not a regular FIFO, because the data may be intentionally overwritten (in case s_drop_i = 1).
  type     buf_type is array (0 to 2 ** G_ADDR_BITS - 1) of std_logic_vector(C_BUF_BITS - 1 downto 0);
  signal   rx_buf : buf_type                                   := (others => (others => '0'));

  -- Current write pointer.
  signal   wrptr : natural range 0 to 2 ** G_ADDR_BITS - 1     := 0;

  -- Current read pointer.
  signal   rdptr : natural range 0 to 2 ** G_ADDR_BITS - 1     := 0;

  -- Pointer to first word of current frame.
  signal   first_ptr : natural range 0 to 2 ** G_ADDR_BITS - 1 := 0;

  -- Pointer to last word of current frame (s_last_i = '1').
  signal   last_ptr : natural range 0 to 2 ** G_ADDR_BITS - 1  := 0;


  signal   fifo_wr_ready : std_logic;
  signal   fifo_wr_valid : std_logic;
  signal   fifo_wr_data  : std_logic_vector(G_ADDR_BITS - 1 downto 0);
  signal   fifo_rd_ready : std_logic;
  signal   fifo_rd_data  : std_logic_vector(G_ADDR_BITS - 1 downto 0);
  signal   fifo_rd_valid : std_logic;

  type     fsm_state_type is (IDLE_ST, FWD_ST);
  signal   fsm_state : fsm_state_type                          := IDLE_ST;

begin

  s_ready_o <= '1' when wrptr + 1 /= rdptr and fifo_wr_ready = '1' else
               '0';

  ----------------------------------------------------
  -- Store incoming frame in buffer
  ----------------------------------------------------

  input_proc : process (clk_i)
  begin
    if rising_edge(clk_i) then
      fifo_wr_valid <= '0';

      assert not (s_valid_i = '1' and s_bytes_i = 0 and rst_i = '0')
        report "axip_dropper: BYTES = 0 is not allowed"
        severity failure;

      if s_valid_i = '1' and s_ready_o = '1' then
        -- Store word in frame buffer
        rx_buf(wrptr)(R_BUF_BYTES) <= bytes_to_slv(s_bytes_i);
        rx_buf(wrptr)(R_BUF_DATA)  <= s_data_i;
        wrptr                      <= (wrptr + 1) mod 2 ** G_ADDR_BITS;

        if s_last_i = '1' then
          if s_drop_i = '1' then
            -- Discard this frame.
            -- This is done simply be overwriting the "write pointer" with the start of this dropped frame.
            wrptr <= first_ptr;
          else
            -- Store current "end pointer" in FIFO
            fifo_wr_data  <= std_logic_vector(to_unsigned(wrptr, G_ADDR_BITS));
            fifo_wr_valid <= '1';
            -- Prepare for next frame
            first_ptr     <= (wrptr + 1) mod 2 ** G_ADDR_BITS;
          end if;
        end if;
      end if;

      if rst_i = '1' then
        fifo_wr_valid <= '0';
        first_ptr     <= 0;
        wrptr         <= 0;
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
    ); -- axis_fifo_inst : entity work.axis_fifo


  ----------------------------------------------------
  -- Read frame from buffer
  ----------------------------------------------------

  fifo_rd_ready <= '1' when fsm_state = IDLE_ST and (m_ready_i = '1' or m_valid_o = '0') else
                   '0';

  output_proc : process (clk_i)
  begin
    if rising_edge(clk_i) then
      if m_ready_i = '1' then
        m_valid_o <= '0';
      end if;

      case fsm_state is

        when IDLE_ST =>
          if fifo_rd_valid = '1' and fifo_rd_ready = '1' then
            last_ptr  <= to_integer(unsigned(fifo_rd_data));
            m_valid_o <= '1';
            m_last_o  <= '0';
            m_bytes_o <= slv_to_bytes(rx_buf(rdptr)(R_BUF_BYTES));
            m_data_o  <= rx_buf(rdptr)(R_BUF_DATA);
            rdptr     <= (rdptr + 1) mod (2 ** G_ADDR_BITS);
            if rdptr = to_integer(unsigned(fifo_rd_data)) then
              m_last_o  <= '1';
              fsm_state <= IDLE_ST;
            else
              fsm_state <= FWD_ST;
            end if;
          end if;

        when FWD_ST =>
          if m_ready_i = '1' then
            m_valid_o <= '1';
            m_last_o  <= '0';
            m_bytes_o <= slv_to_bytes(rx_buf(rdptr)(R_BUF_BYTES));
            m_data_o  <= rx_buf(rdptr)(R_BUF_DATA);
            rdptr     <= (rdptr + 1) mod (2 ** G_ADDR_BITS);
            if rdptr = last_ptr then
              m_last_o  <= '1';
              fsm_state <= IDLE_ST;
            else
              fsm_state <= FWD_ST;
            end if;
          end if;

      end case;

      if rst_i = '1' then
        m_valid_o <= '0';
        rdptr     <= 0;
        fsm_state <= IDLE_ST;
      end if;
    end if;
  end process output_proc;

end architecture rtl;

