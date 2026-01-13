-- ---------------------------------------------------------------------------------------
-- Description: This simulates an Avalon Master.  It generates a sequence of Writes and
-- Reads, and verifies that the values returned from Read matches the corresponding values
-- during Write.
-- ---------------------------------------------------------------------------------------

library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std_unsigned.all;
  use std.env.stop;

entity avm_master_sim is
  generic (
    G_SEED        : std_logic_vector(63 downto 0) := X"DEADBEEFC007BABE";
    G_NAME        : string                        := "";
    G_TIMEOUT_MAX : natural                       := 200;
    G_DEBUG       : boolean                       := false;
    G_OFFSET      : natural                       := 1234;
    G_ADDR_SIZE   : natural;
    G_DATA_SIZE   : natural
  );
  port (
    clk_i             : in    std_logic;
    rst_i             : in    std_logic;
    m_waitrequest_i   : in    std_logic;
    m_write_o         : out   std_logic;
    m_read_o          : out   std_logic;
    m_address_o       : out   std_logic_vector(G_ADDR_SIZE - 1 downto 0);
    m_writedata_o     : out   std_logic_vector(G_DATA_SIZE - 1 downto 0);
    m_byteenable_o    : out   std_logic_vector(G_DATA_SIZE / 8 - 1 downto 0);
    m_burstcount_o    : out   std_logic_vector(7 downto 0);
    m_readdatavalid_i : in    std_logic;
    m_readdata_i      : in    std_logic_vector(G_DATA_SIZE - 1 downto 0)
  );
end entity avm_master_sim;

architecture simulation of avm_master_sim is

  signal   random_s : std_logic_vector(63 downto 0);

  subtype  R_REQUEST is natural range 15 downto 15;
  constant C_WRITE : natural  := 1;

  signal   do_request : std_logic;
  signal   do_read    : std_logic;
  signal   do_write   : std_logic;

  type     state_type is (IDLE_ST, WRITING_ST, READING_ST, DONE_ST);
  signal   state : state_type := IDLE_ST;

  signal   wr_ptr   : std_logic_vector(G_ADDR_SIZE - 1 downto 0);
  signal   rd_ptr   : std_logic_vector(G_ADDR_SIZE - 1 downto 0);
  signal   diff_ptr : std_logic_vector(G_ADDR_SIZE - 1 downto 0);

  pure function addr_to_data (
    addr : std_logic_vector
  ) return std_logic_vector is
    variable addr_v : std_logic_vector(G_ADDR_SIZE - 1 downto 0);
    variable data_v : std_logic_vector(G_DATA_SIZE - 1 downto 0);
  begin
    return resize(addr, G_DATA_SIZE) + G_OFFSET;
  end function addr_to_data;

begin

  -- Used for debugging
  diff_ptr <= wr_ptr - rd_ptr;


  --------------------------------
  -- Instantiate random number generator
  --------------------------------

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

  do_request <= and(random_s(R_REQUEST)) and not rst_i;
  do_write   <= do_request and random_s(C_WRITE);
  do_read    <= do_request and not random_s(C_WRITE);

  avm_proc : process (clk_i)
    variable first_v : boolean := true;
  begin
    if rising_edge(clk_i) then
      if rst_i = '0' and first_v then
        report "Avalon MASTER " & G_NAME &
               ": Test started";
        first_v := false;
      end if;

      if m_waitrequest_i = '0' then
        m_write_o <= '0';
        m_read_o  <= '0';
      end if;

      case state is

        when IDLE_ST =>
          if do_write = '1' then
            if wr_ptr + 1 = 0 then
              state <= DONE_ST;
            else
              assert m_read_o = '0';
              m_write_o      <= '1';
              m_address_o    <= wr_ptr;
              m_writedata_o  <= addr_to_data(wr_ptr);
              m_byteenable_o <= (others => '1');
              m_burstcount_o <= X"01";
              if G_DEBUG then
                report "Avalon MASTER " & G_NAME &
                       ": Write to address " & to_hstring(wr_ptr) &
                       " with data " & to_hstring(addr_to_data(wr_ptr));
              end if;
              state <= WRITING_ST;
            end if;
          elsif do_read = '1' and rd_ptr < wr_ptr then
            assert m_write_o = '0';
            m_read_o       <= '1';
            m_address_o    <= rd_ptr;
            m_burstcount_o <= X"01";
            if G_DEBUG then
              report "Avalon MASTER " & G_NAME &
                     ": Read from address " & to_hstring(rd_ptr);
            end if;
            state <= READING_ST;
          end if;

        when WRITING_ST =>
          if m_waitrequest_i = '0' and m_write_o = '1' then
            wr_ptr <= wr_ptr + 1;

            if do_write = '1' then
              if wr_ptr + 1 = 0 then
                state <= DONE_ST;
              else
                assert m_read_o = '0' or m_waitrequest_i = '0';
                m_write_o      <= '1';
                m_address_o    <= wr_ptr + 1;
                m_writedata_o  <= addr_to_data(wr_ptr + 1);
                m_byteenable_o <= (others => '1');
                m_burstcount_o <= X"01";
                if G_DEBUG then
                  report "Avalon MASTER " & G_NAME &
                         ": Write to address " & to_hstring(wr_ptr + 1) &
                         " with data " & to_hstring(addr_to_data(wr_ptr + 1));
                end if;
                state <= WRITING_ST;
              end if;
            elsif do_read = '1' and rd_ptr < wr_ptr + 1 then
              assert m_write_o = '0' or m_waitrequest_i = '0';
              m_read_o       <= '1';
              m_address_o    <= rd_ptr;
              m_burstcount_o <= X"01";
              if G_DEBUG then
                report "Avalon MASTER " & G_NAME &
                       ": Read from address " & to_hstring(rd_ptr);
              end if;
              state <= READING_ST;
            else
              state <= IDLE_ST;
            end if;
          end if;

        when READING_ST =>
          if m_readdatavalid_i = '1' then
            assert m_readdata_i = addr_to_data(rd_ptr)
              report "Avalon MASTER " & G_NAME &
                     ": Read failure from address " & to_hstring(rd_ptr) &
                     ". Got " & to_hstring(m_readdata_i) &
                     ", expected " & to_hstring(addr_to_data(rd_ptr));
            rd_ptr <= rd_ptr + 1;

            if do_write = '1' then
              if wr_ptr + 1 = 0 then
                state <= DONE_ST;
              else
                assert m_read_o = '0' or m_waitrequest_i = '0';
                m_write_o      <= '1';
                m_address_o    <= wr_ptr;
                m_writedata_o  <= addr_to_data(wr_ptr);
                m_byteenable_o <= (others => '1');
                m_burstcount_o <= X"01";
                if G_DEBUG then
                  report "Avalon MASTER " & G_NAME &
                         ": Write to address " & to_hstring(wr_ptr) &
                         " with data " & to_hstring(addr_to_data(wr_ptr));
                end if;
                state <= WRITING_ST;
              end if;
            elsif do_read = '1' and rd_ptr + 1 < wr_ptr then
              assert m_write_o = '0' or m_waitrequest_i = '0';
              m_read_o       <= '1';
              m_address_o    <= rd_ptr + 1;
              m_burstcount_o <= X"01";
              if G_DEBUG then
                report "Avalon MASTER " & G_NAME &
                       ": Read from address " & to_hstring(rd_ptr + 1);
              end if;
              state <= READING_ST;
            else
              state <= IDLE_ST;
            end if;
          end if;

        when DONE_ST =>
          report "Avalon MASTER " & G_NAME &
                 ": Test finished";
          stop;

      end case;

      if rst_i = '1' then
        m_write_o <= '0';
        m_read_o  <= '0';
        wr_ptr    <= (others => '0');
        rd_ptr    <= (others => '0');
        state     <= IDLE_ST;
      end if;
    end if;
  end process avm_proc;

end architecture simulation;

