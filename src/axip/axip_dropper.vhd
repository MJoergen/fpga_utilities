-- ---------------------------------------------------------------------------------------
-- Description: Drops packets from an AXI Stream.  It stores input packets until the last
-- word, before deciding whether to forward the packet.  Since multiple (short) packets
-- may be received while forwarding a single (long) frame, the "end pointer" of each
-- received valid frame must be stored in a separate FIFO.
-- ---------------------------------------------------------------------------------------

library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std.all;

entity axip_dropper is
  generic (
    G_DATA_SIZE : positive; -- Size of each byte
    G_ADDR_SIZE : positive; -- Controls size of frame buffer
    G_RAM_DEPTH : positive  -- Set to ratio between longest and shortest frame length possible
  );
  port (
    clk_i     : in    std_logic;
    rst_i     : in    std_logic;

    -- Input interface
    s_ready_o : out   std_logic;
    s_valid_i : in    std_logic;
    s_data_i  : in    std_logic_vector(G_DATA_SIZE - 1 downto 0);
    s_last_i  : in    std_logic;
    s_drop_i  : in    std_logic; -- Sampled when s_last_i = 1

    -- Output interface
    m_ready_i : in    std_logic;
    m_valid_o : out   std_logic;
    m_data_o  : out   std_logic_vector(G_DATA_SIZE - 1 downto 0);
    m_last_o  : out   std_logic
  );
end entity axip_dropper;

architecture synthesis of axip_dropper is

  -- Buffer containing the packet data
  -- This is not a regular FIFO, because the data may be intentionally overwritten (in case s_drop_i = 1).
  type   buf_type is array (0 to 2 ** G_ADDR_SIZE - 1) of std_logic_vector(G_DATA_SIZE - 1 downto 0);
  signal rx_buf : buf_type                                   := (others => (others => '0'));

  -- Current write pointer.
  signal wrptr : natural range 0 to 2 ** G_ADDR_SIZE - 1     := 0;

  -- Current read pointer.
  signal rdptr : natural range 0 to 2 ** G_ADDR_SIZE - 1     := 0;

  -- Pointer to first word of current frame.
  signal first_ptr : natural range 0 to 2 ** G_ADDR_SIZE - 1 := 0;

  -- Pointer to last word of current frame (s_last_i = '1').
  signal last_ptr : natural range 0 to 2 ** G_ADDR_SIZE - 1  := 0;

  signal fifo_wr_ready : std_logic;
  signal fifo_wr_valid : std_logic;
  signal fifo_wr_data  : std_logic_vector(G_ADDR_SIZE - 1 downto 0);
  signal fifo_rd_ready : std_logic;
  signal fifo_rd_data  : std_logic_vector(G_ADDR_SIZE - 1 downto 0);
  signal fifo_rd_valid : std_logic;

  type   fsm_state_type is (IDLE_ST, FWD_ST);
  signal fsm_state : fsm_state_type                          := IDLE_ST;

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

      if s_valid_i = '1' and s_ready_o = '1' then
        -- Store word in frame buffer
        rx_buf(wrptr) <= s_data_i;
        wrptr         <= wrptr + 1;

        if s_last_i = '1' then
          if s_drop_i = '1' then
            -- Discard this frame.
            -- This is done simply be overwriting the "write pointer" with the start of this dropped frame.
            wrptr <= first_ptr;
          else
            -- Store current "end pointer" in FIFO
            fifo_wr_data  <= std_logic_vector(to_unsigned(wrptr, G_ADDR_SIZE));
            fifo_wr_valid <= '1';
            -- Prepare for next frame
            first_ptr     <= wrptr + 1;
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

  axis_fifo_sync_inst : entity work.axis_fifo_sync
    generic map (
      G_DATA_SIZE => G_ADDR_SIZE,
      G_RAM_DEPTH => G_RAM_DEPTH
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
    ); -- axis_fifo_sync_inst : entity work.axis_fifo_sync


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
            m_data_o  <= rx_buf(rdptr);
            rdptr     <= rdptr + 1;
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
            m_data_o  <= rx_buf(rdptr);
            rdptr     <= rdptr + 1;
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

end architecture synthesis;

