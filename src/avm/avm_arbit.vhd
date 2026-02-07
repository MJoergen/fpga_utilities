-- ---------------------------------------------------------------------------------------
-- Description: Arbitrate between two different Avalon masters
-- ---------------------------------------------------------------------------------------

library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std.all;

library work;
  use work.avm_pkg.all;

entity avm_arbit is
  generic (
    G_PREFER_SWAP : boolean
  );
  port (
    clk_i  : in    std_logic;
    rst_i  : in    std_logic;
    s0_avm : view  avm_slave_view;
    s1_avm : view  avm_slave_view;
    m_avm  : view  avm_master_view
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

  s0_avm.waitrequest   <= m_avm.waitrequest or not s0_active_grant;
  s1_avm.waitrequest   <= m_avm.waitrequest or not s1_active_grant;

  s0_active_req        <= s0_avm.write or s0_avm.read;
  s1_active_req        <= s1_avm.write or s1_avm.read;

  -- Determine remaining length of current transaction.
  burstcount_proc : process (clk_i)
  begin
    if rising_edge(clk_i) then
      if s0_avm.write = '1' and s0_avm.waitrequest = '0' and unsigned(burstcount) = 0 then
        burstcount <= std_logic_vector(unsigned(s0_avm.burstcount) - 1);
      elsif s0_avm.read and not s0_avm.waitrequest then
        burstcount <= s0_avm.burstcount;
      elsif s1_avm.write = '1' and s1_avm.waitrequest = '0' and unsigned(burstcount) = 0 then
        burstcount <= std_logic_vector(unsigned(s1_avm.burstcount) - 1);
      elsif s1_avm.read and not s1_avm.waitrequest then
        burstcount <= s1_avm.burstcount;
      else
        if (s0_avm.write and not s0_avm.waitrequest) or
           s0_avm.readdatavalid or
           (s1_avm.write and not s1_avm.waitrequest) or
           s1_avm.readdatavalid then
          burstcount <= std_logic_vector(unsigned(burstcount) - 1);
        end if;
      end if;

      if rst_i = '1' then
        burstcount <= x"00";
      end if;
    end if;
  end process burstcount_proc;

  -- Determine whether the current access is finished and no new transaction has begun.
  last_proc : process (all)
  begin
    s0_last <= '0';
    s1_last <= '0';

    if s0_active_grant = '1' then
      if burstcount = x"00" or (burstcount = x"01" and s0_avm.readdatavalid = '1')
         or (burstcount = x"01" and s0_avm.write = '1') then
        if s0_active_req = '0'
           or (burstcount = x"01"  and s0_avm.readdatavalid = '1' and s0_avm.waitrequest = '1')
           or (burstcount = x"01"          and s0_avm.write = '1' and s0_avm.waitrequest = '0')
           or (s0_avm.burstcount = x"01" and s0_avm.write = '1' and s0_avm.waitrequest = '0') then
          s0_last <= '1';
        end if;
      end if;
    end if;

    if s1_active_grant = '1' then
      if burstcount = x"00" or (burstcount = x"01" and s1_avm.readdatavalid = '1')
         or (burstcount = x"01" and s1_avm.write = '1') then
        if s1_active_req = '0'
           or (burstcount = x"01"  and s1_avm.readdatavalid = '1' and s1_avm.waitrequest = '1')
           or (burstcount = x"01"          and s1_avm.write = '1' and s1_avm.waitrequest = '0')
           or (s1_avm.burstcount = x"01" and s1_avm.write = '1' and s1_avm.waitrequest = '0') then
          s1_last <= '1';
        end if;
      end if;
    end if;
  end process last_proc;

  -- Determine who to grant access next.
  active_grants        <= s1_active_grant & s0_active_grant;

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
  m_avm.write          <= s0_avm.write and s0_active_grant when last_grant = '0' else
                          s1_avm.write and s1_active_grant;
  m_avm.read           <= s0_avm.read and s0_active_grant when last_grant = '0' else
                          s1_avm.read and s1_active_grant;
  m_avm.address        <= s0_avm.address when last_grant = '0' else
                          s1_avm.address;
  m_avm.writedata      <= s0_avm.writedata when last_grant = '0' else
                          s1_avm.writedata;
  m_avm.byteenable     <= s0_avm.byteenable when last_grant = '0' else
                          s1_avm.byteenable;
  m_avm.burstcount     <= s0_avm.burstcount when last_grant = '0' else
                          s1_avm.burstcount;

  s0_avm.readdata      <= m_avm.readdata;
  s0_avm.readdatavalid <= m_avm.readdatavalid when last_grant = '0' else
                          '0';

  s1_avm.readdata      <= m_avm.readdata;
  s1_avm.readdatavalid <= m_avm.readdatavalid when last_grant = '1' else
                          '0';

end architecture synthesis;

