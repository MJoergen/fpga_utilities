-- ---------------------------------------------------------------------------------------
-- Description: Arbitrate between two different Avalon masters
-- ---------------------------------------------------------------------------------------

library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std.all;

entity avm_arbit is
  generic (
    G_PREFER_SWAP : boolean;
    G_ADDR_SIZE   : positive;
    G_DATA_SIZE   : positive
  );
  port (
    clk_i              : in    std_logic;
    rst_i              : in    std_logic;

    -- Slave interface 0 (input)
    s0_waitrequest_o   : out   std_logic;
    s0_write_i         : in    std_logic;
    s0_read_i          : in    std_logic;
    s0_address_i       : in    std_logic_vector(G_ADDR_SIZE - 1 downto 0);
    s0_writedata_i     : in    std_logic_vector(G_DATA_SIZE - 1 downto 0);
    s0_byteenable_i    : in    std_logic_vector(G_DATA_SIZE / 8 - 1 downto 0);
    s0_burstcount_i    : in    std_logic_vector(7 downto 0);
    s0_readdatavalid_o : out   std_logic;
    s0_readdata_o      : out   std_logic_vector(G_DATA_SIZE - 1 downto 0);

    -- Slave interface 1 (input)
    s1_waitrequest_o   : out   std_logic;
    s1_write_i         : in    std_logic;
    s1_read_i          : in    std_logic;
    s1_address_i       : in    std_logic_vector(G_ADDR_SIZE - 1 downto 0);
    s1_writedata_i     : in    std_logic_vector(G_DATA_SIZE - 1 downto 0);
    s1_byteenable_i    : in    std_logic_vector(G_DATA_SIZE / 8 - 1 downto 0);
    s1_burstcount_i    : in    std_logic_vector(7 downto 0);
    s1_readdatavalid_o : out   std_logic;
    s1_readdata_o      : out   std_logic_vector(G_DATA_SIZE - 1 downto 0);

    -- Master interface (output)
    m_waitrequest_i    : in    std_logic;
    m_write_o          : out   std_logic;
    m_read_o           : out   std_logic;
    m_address_o        : out   std_logic_vector(G_ADDR_SIZE - 1 downto 0);
    m_writedata_o      : out   std_logic_vector(G_DATA_SIZE - 1 downto 0);
    m_byteenable_o     : out   std_logic_vector(G_DATA_SIZE / 8 - 1 downto 0);
    m_burstcount_o     : out   std_logic_vector(7 downto 0);
    m_readdatavalid_i  : in    std_logic;
    m_readdata_i       : in    std_logic_vector(G_DATA_SIZE - 1 downto 0)
  );
end entity avm_arbit;

architecture synthesis of avm_arbit is

  signal s0_active_req : std_logic;
  signal s1_active_req : std_logic;

  signal s0_active_grant : std_logic := '0';
  signal s1_active_grant : std_logic := '0';
  signal active_grants   : std_logic_vector(1 downto 0);

  signal s0_last : std_logic;
  signal s1_last : std_logic;

  signal last_grant : std_logic      := '0';
  signal swapped    : std_logic      := '0';

  signal burstcount : std_logic_vector(7 downto 0);

begin

  -- Validation check that the two Masters are not granted access at the same time.
  assert not (s0_active_grant and s1_active_grant);

  s0_waitrequest_o   <= m_waitrequest_i or not s0_active_grant;
  s1_waitrequest_o   <= m_waitrequest_i or not s1_active_grant;

  s0_active_req      <= s0_write_i or s0_read_i;
  s1_active_req      <= s1_write_i or s1_read_i;

  -- Determine remaining length of current transaction.
  burstcount_proc : process (clk_i)
  begin
    if rising_edge(clk_i) then
      if s0_write_i = '1' and s0_waitrequest_o = '0' and unsigned(burstcount) = 0 then
        burstcount <= std_logic_vector(unsigned(s0_burstcount_i) - 1);
      elsif s0_read_i and not s0_waitrequest_o then
        burstcount <= s0_burstcount_i;
      elsif s1_write_i = '1' and s1_waitrequest_o = '0' and unsigned(burstcount) = 0 then
        burstcount <= std_logic_vector(unsigned(s1_burstcount_i) - 1);
      elsif s1_read_i and not s1_waitrequest_o then
        burstcount <= s1_burstcount_i;
      else
        if (s0_write_i and not s0_waitrequest_o) or
           s0_readdatavalid_o or
           (s1_write_i and not s1_waitrequest_o) or
           s1_readdatavalid_o then
          burstcount <= std_logic_vector(unsigned(burstcount) - 1);
        end if;
      end if;

      if rst_i = '1' then
        burstcount <= X"00";
      end if;
    end if;
  end process burstcount_proc;

  -- Determine whether the current access is finished and no new transaction has begun.
  last_proc : process (all)
  begin
    s0_last <= '0';
    s1_last <= '0';

    if s0_active_grant = '1' then
      if burstcount = X"00" or (burstcount = X"01" and s0_readdatavalid_o = '1')
         or (burstcount = X"01" and s0_write_i = '1') then
        if s0_active_req = '0'
           or (burstcount = X"01"  and s0_readdatavalid_o = '1' and s0_waitrequest_o = '1')
           or (burstcount = X"01"          and s0_write_i = '1' and s0_waitrequest_o = '0')
           or (s0_burstcount_i = X"01" and s0_write_i = '1' and s0_waitrequest_o = '0') then
          s0_last <= '1';
        end if;
      end if;
    end if;

    if s1_active_grant = '1' then
      if burstcount = X"00" or (burstcount = X"01" and s1_readdatavalid_o = '1')
         or (burstcount = X"01" and s1_write_i = '1') then
        if s1_active_req = '0'
           or (burstcount = X"01"  and s1_readdatavalid_o = '1' and s1_waitrequest_o = '1')
           or (burstcount = X"01"          and s1_write_i = '1' and s1_waitrequest_o = '0')
           or (s1_burstcount_i = X"01" and s1_write_i = '1' and s1_waitrequest_o = '0') then
          s1_last <= '1';
        end if;
      end if;
    end if;
  end process last_proc;

  -- Determine who to grant access next.
  active_grants      <= s1_active_grant & s0_active_grant;

  grant_proc : process (clk_i)
  begin
    if rising_edge(clk_i) then
      -- Last clock cycle in a burst transfer
      if s0_last = '1' then
        s0_active_grant <= '0';
      end if;
      if s1_last = '1' then
        s1_active_grant <= '0';
      end if;

      case active_grants is

        when "00" =>
          if s0_active_req = '1' and (last_grant = '1' or s1_active_req = '0') then
            s0_active_grant <= '1';
            last_grant      <= '0';
          end if;
          if s1_active_req = '1' and (last_grant = '0' or s0_active_req = '0') then
            s1_active_grant <= '1';
            last_grant      <= '1';
          end if;

        when "01" =>
          if s0_last = '1' then
            if s0_active_req = '1' and not (last_grant = '0' and s1_active_req = '1') then
              s0_active_grant <= '1';
              last_grant      <= '0';
            elsif s1_active_req = '1' and not (last_grant = '1' and s0_active_req = '1') then
              s1_active_grant <= '1';
              s0_active_grant <= '0';
              last_grant      <= '1';
            end if;

            if G_PREFER_SWAP then
              -- If no pending requests, pre-emptively give grant to other
              if s1_active_req = '0' and s0_active_req = '0' and swapped = '0' then
                s1_active_grant <= '1';
                last_grant      <= '1';
                swapped         <= '1';
              end if;
              if s1_active_req = '0' and s0_active_req = '0' and swapped = '1' then
                s0_active_grant <= '1';
                last_grant      <= '0';
              end if;
            else
              -- If no pending requests, keep the existing grant
              if s1_active_req = '0' and s0_active_req = '0' then
                s0_active_grant <= '1';
                last_grant      <= '0';
              end if;
            end if;
          end if;

        when "10" =>
          if s1_last = '1' then
            if s1_active_req = '1' and not (last_grant = '1' and s0_active_req = '1') then
              s1_active_grant <= '1';
              last_grant      <= '1';
            elsif s0_active_req = '1' and not (last_grant = '0' and s1_active_req = '1') then
              s0_active_grant <= '1';
              s1_active_grant <= '0';
              last_grant      <= '0';
            end if;

            if G_PREFER_SWAP then
              -- If no pending requests, pre-emptively give grant to other
              if s1_active_req = '0' and s0_active_req = '0' and swapped = '0' then
                s0_active_grant <= '1';
                last_grant      <= '0';
                swapped         <= '1';
              end if;
              if s1_active_req = '0' and s0_active_req = '0' and swapped = '1' then
                s1_active_grant <= '1';
                last_grant      <= '1';
              end if;
            else
              -- If no pending requests, keep the existing grant
              if s1_active_req = '0' and s0_active_req = '0' then
                s1_active_grant <= '1';
                last_grant      <= '1';
              end if;
            end if;
          end if;


        when others =>
          report "S0 and S1 both active"
            severity failure;

      end case;

      if s1_active_req = '1' or s0_active_req = '1' then
        swapped <= '0';
      end if;

      if rst_i = '1' then
        s0_active_grant <= '0';
        s1_active_grant <= '0';
        last_grant      <= '1';
      end if;
    end if;
  end process grant_proc;

  -- Generate output signals combinatorially
  m_write_o          <= s0_write_i and s0_active_grant when last_grant = '0' else
                        s1_write_i and s1_active_grant;
  m_read_o           <= s0_read_i and s0_active_grant when last_grant = '0' else
                        s1_read_i and s1_active_grant;
  m_address_o        <= s0_address_i when last_grant = '0' else
                        s1_address_i;
  m_writedata_o      <= s0_writedata_i when last_grant = '0' else
                        s1_writedata_i;
  m_byteenable_o     <= s0_byteenable_i when last_grant = '0' else
                        s1_byteenable_i;
  m_burstcount_o     <= s0_burstcount_i when last_grant = '0' else
                        s1_burstcount_i;

  s0_readdata_o      <= m_readdata_i;
  s0_readdatavalid_o <= m_readdatavalid_i when last_grant = '0' else
                        '0';

  s1_readdata_o      <= m_readdata_i;
  s1_readdatavalid_o <= m_readdatavalid_i when last_grant = '1' else
                        '0';

end architecture synthesis;

