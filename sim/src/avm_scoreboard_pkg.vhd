library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std.all;
  use ieee.numeric_std_unsigned.all;

package avm_scoreboard_pkg is

  ---------------------------------------------------------------------------
  -- Scoreboard sizing.
  --
  -- These are simulation limits, not DUT generics.
  -- Increase if your testbench needs a larger model memory, deeper expected
  -- data queue, or wider data words.
  ---------------------------------------------------------------------------
  constant C_SB_MAX_DATA_BITS : natural := 64;
  constant C_SB_MAX_BYTES     : natural := C_SB_MAX_DATA_BITS / 8;
  constant C_SB_MEM_WORDS     : natural := 65536;
  constant C_SB_QUEUE_DEPTH   : natural := 65536;

  subtype  SB_WORD_TYPE is std_logic_vector(C_SB_MAX_DATA_BITS - 1 downto 0);
  subtype  SB_BE_TYPE   is std_logic_vector(C_SB_MAX_BYTES - 1 downto 0);

  type     avm_scoreboard_type is protected

    ------------------------------------------------------------------------
    -- Configure scoreboard.
    --
    -- data_width:
    --   Active data width in bits. Must be <= C_SB_MAX_DATA_BITS and a
    --   multiple of 8.
    --
    -- address_modulo:
    --   Number of word addresses in the simulated memory model. This may be
    --   smaller than C_SB_MEM_WORDS if you want address wraparound.
    --
    -- verbose:
    --   Enables extra notes for accepted transactions and matched data.
    ------------------------------------------------------------------------

    procedure configure (
      constant data_width     : in natural;
      constant address_modulo : in natural := C_SB_MEM_WORDS;
      constant verbose        : in boolean := false
    );

    ------------------------------------------------------------------------
    -- Clear memory, queue, counters and error state.
    ------------------------------------------------------------------------

    procedure reset;

    ------------------------------------------------------------------------
    -- Initialize memory with a deterministic address-based pattern.
    --
    -- This is useful because wrong-address bugs are easy to spot.
    ------------------------------------------------------------------------

    procedure init_pattern;

    ------------------------------------------------------------------------
    -- Initialize one memory word.
    --
    -- Only the active data-width LSBs are used.
    ------------------------------------------------------------------------

    procedure poke (
      constant addr : in natural;
      constant data : in std_logic_vector
    );

    ------------------------------------------------------------------------
    -- Read one memory word from the model, mainly for debug or directed
    -- tests.
    ------------------------------------------------------------------------

    procedure peek (
      constant addr : in  natural;
      variable data : out std_logic_vector
    );

    ------------------------------------------------------------------------
    -- Record an accepted client-side write.
    --
    -- This updates the architectural golden memory immediately when the
    -- upstream transaction is accepted by the DUT.
    ------------------------------------------------------------------------

    procedure accept_write (
      constant addr       : in natural;
      constant writedata  : in std_logic_vector;
      constant byteenable : in std_logic_vector
    );

    ------------------------------------------------------------------------
    -- Record an accepted client-side read.
    --
    -- This pushes burstcount expected words into the expected-read FIFO.
    ------------------------------------------------------------------------

    procedure accept_read (
      constant addr       : in natural;
      constant burstcount : in natural
    );

    ------------------------------------------------------------------------
    -- Check one client-side returned read word.
    --
    -- Call this once for every s_avm_readdatavalid_o = '1'.
    ------------------------------------------------------------------------

    procedure check_readdata (
      constant actual : in std_logic_vector
    );

    ------------------------------------------------------------------------
    -- End-of-test check. Fails if expected read words remain unreturned or
    -- if any previous mismatch/underflow occurred.
    ------------------------------------------------------------------------

    procedure final_check;

    ------------------------------------------------------------------------
    -- Print statistics.
    ------------------------------------------------------------------------

    procedure report_status;

    ------------------------------------------------------------------------
    -- Query functions.
    ------------------------------------------------------------------------

    impure function pending_count return natural;

    impure function error_count return natural;

   end protected avm_scoreboard_type;

end package avm_scoreboard_pkg;


library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std.all;
  use ieee.numeric_std_unsigned.all;

package body avm_scoreboard_pkg is

  type       avm_scoreboard_type is protected body

    type     mem_type is array (0 to C_SB_MEM_WORDS - 1) of sb_word_type;

    type     queue_type is array (0 to C_SB_QUEUE_DEPTH - 1) of sb_word_type;

    variable mem_v             : mem_type;
    variable exp_q_v           : queue_type;

    variable data_width_v      : natural := 32;
    variable byte_lanes_v      : natural := 4;
    variable address_modulo_v  : natural := C_SB_MEM_WORDS;
    variable verbose_v         : boolean := false;

    variable q_head_v          : natural := 0;
    variable q_tail_v          : natural := 0;
    variable q_count_v         : natural := 0;

    variable accepted_reads_v  : natural := 0;
    variable accepted_writes_v : natural := 0;
    variable expected_words_v  : natural := 0;
    variable checked_words_v   : natural := 0;
    variable errors_v          : natural := 0;


    ------------------------------------------------------------------------
    -- Local helper: active data mask.
    ------------------------------------------------------------------------

    impure function active_mask return sb_word_type is
      variable mask_v : sb_word_type := (others => '0');
    begin
      for i in 0 to data_width_v - 1 loop
        mask_v(i) := '1';
      end loop;

      return mask_v;
    end function active_mask;


    ------------------------------------------------------------------------
    -- Local helper: normalize std_logic_vector into scoreboard word.
    --
    -- Input is assumed to use normal VHDL indexing. Only the low data_width_v
    -- bits are relevant. Missing upper bits are zero-filled.
    ------------------------------------------------------------------------

    impure function normalize_data (
      constant data : std_logic_vector
    ) return sb_word_type is
      variable result_v : sb_word_type := (others => '0');
      variable n_v      : natural;
    begin
      if data'length < data_width_v then
        n_v := data'length;
      else
        n_v := data_width_v;
      end if;

      for i in 0 to n_v - 1 loop
        result_v(i) := data(data'right + i);
      end loop;

      return result_v;
    end function normalize_data;


    ------------------------------------------------------------------------
    -- Local helper: normalize byteenable.
    ------------------------------------------------------------------------

    impure function normalize_be (
      constant be : std_logic_vector
    ) return sb_be_type is
      variable result_v : sb_be_type := (others => '0');
      variable n_v      : natural;
    begin
      if be'length < byte_lanes_v then
        n_v := be'length;
      else
        n_v := byte_lanes_v;
      end if;

      for i in 0 to n_v - 1 loop
        result_v(i) := be(be'right + i);
      end loop;

      return result_v;
    end function normalize_be;


    ------------------------------------------------------------------------
    -- Local helper: wrap address into model-memory range.
    ------------------------------------------------------------------------

    impure function norm_addr (
      constant addr : natural
    ) return natural is
    begin
      return addr mod address_modulo_v;
    end function norm_addr;


    ------------------------------------------------------------------------
    -- Local helper: deterministic memory pattern.
    --
    -- Pattern is intentionally address-dependent and byte-lane-dependent.
    -- For 32-bit data, address A produces:
    --
    --   byte0 = A + 0x11
    --   byte1 = A + 0x22
    --   byte2 = A + 0x33
    --   byte3 = A + 0x44
    --
    -- modulo 256.
    ------------------------------------------------------------------------

    impure function pattern_for_addr (
      constant addr : natural
    ) return sb_word_type is
      variable result_v : sb_word_type := (others => '0');
      variable b_v      : natural;
    begin
      for i in 0 to byte_lanes_v - 1 loop
        b_v                              := (addr + ((i + 1) * 16#11#)) mod 256;
        result_v(8 * i + 7 downto 8 * i) := std_logic_vector(to_unsigned(b_v, 8));
      end loop;

      return result_v;
    end function pattern_for_addr;


    ------------------------------------------------------------------------
    -- Local helper: push expected word.
    ------------------------------------------------------------------------

    procedure push_expected (
      constant data : in sb_word_type
    ) is
    begin
      assert q_count_v < C_SB_QUEUE_DEPTH
        report "AVM scoreboard expected-data FIFO overflow"
        severity failure;

      exp_q_v(q_tail_v) := data and active_mask;

      if q_tail_v = C_SB_QUEUE_DEPTH - 1 then
        q_tail_v := 0;
      else
        q_tail_v := q_tail_v + 1;
      end if;

      q_count_v        := q_count_v + 1;
      expected_words_v := expected_words_v + 1;
    end procedure push_expected;


    ------------------------------------------------------------------------
    -- Local helper: pop expected word.
    ------------------------------------------------------------------------

    procedure pop_expected (
      variable data : out sb_word_type
    ) is
    begin
      assert q_count_v > 0
        report "AVM scoreboard expected-data FIFO underflow: DUT returned unexpected read data"
        severity error;

      if q_count_v = 0 then
        data     := (others => 'X');
        errors_v := errors_v + 1;
        return;
      end if;

      data := exp_q_v(q_head_v);

      if q_head_v = C_SB_QUEUE_DEPTH - 1 then
        q_head_v := 0;
      else
        q_head_v := q_head_v + 1;
      end if;

      q_count_v := q_count_v - 1;
    end procedure pop_expected;


    ------------------------------------------------------------------------
    -- Public methods
    ------------------------------------------------------------------------

    procedure configure (
      constant data_width     : in natural;
      constant address_modulo : in natural := C_SB_MEM_WORDS;
      constant verbose        : in boolean := false
    ) is
    begin
      assert data_width >= 8
        report "AVM scoreboard: data_width must be >= 8"
        severity failure;

      assert data_width <= C_SB_MAX_DATA_BITS
        report "AVM scoreboard: data_width exceeds C_SB_MAX_DATA_BITS"
        severity failure;

      assert data_width mod 8 = 0
        report "AVM scoreboard: data_width must be a multiple of 8"
        severity failure;

      assert address_modulo >= 1
        report "AVM scoreboard: address_modulo must be >= 1"
        severity failure;

      assert address_modulo <= C_SB_MEM_WORDS
        report "AVM scoreboard: address_modulo exceeds C_SB_MEM_WORDS"
        severity failure;

      data_width_v     := data_width;
      byte_lanes_v     := data_width / 8;
      address_modulo_v := address_modulo;
      verbose_v        := verbose;

      reset;
    end procedure configure;


    procedure reset is
    begin
      for i in 0 to C_SB_MEM_WORDS - 1 loop
        mem_v(i) := (others => '0');
      end loop;

      q_head_v          := 0;
      q_tail_v          := 0;
      q_count_v         := 0;

      accepted_reads_v  := 0;
      accepted_writes_v := 0;
      expected_words_v  := 0;
      checked_words_v   := 0;
      errors_v          := 0;
    end procedure reset;


    procedure init_pattern is
    begin
      for i in 0 to address_modulo_v - 1 loop
        mem_v(i) := pattern_for_addr(i);
      end loop;

      if verbose_v then
        report "AVM scoreboard: memory initialized with deterministic pattern"
          severity note;
      end if;
    end procedure init_pattern;


    procedure poke (
      constant addr : in natural;
      constant data : in std_logic_vector
    ) is
      variable a_v : natural;
    begin
      a_v        := norm_addr(addr);
      mem_v(a_v) := normalize_data(data) and active_mask;
    end procedure poke;


    procedure peek (
      constant addr : in  natural;
      variable data : out std_logic_vector
    ) is
      variable a_v : natural;
      variable d_v : sb_word_type;
      variable n_v : natural;
    begin
      a_v := norm_addr(addr);
      d_v := mem_v(a_v) and active_mask;

      if data'length < data_width_v then
        n_v := data'length;
      else
        n_v := data_width_v;
      end if;

      data := (data'range => '0');

      for i in 0 to n_v - 1 loop
        data(data'right + i) := d_v(i);
      end loop;
    end procedure peek;


    procedure accept_write (
      constant addr       : in natural;
      constant writedata  : in std_logic_vector;
      constant byteenable : in std_logic_vector
    ) is
      variable a_v  : natural;
      variable wd_v : sb_word_type;
      variable be_v : sb_be_type;
    begin
      a_v  := norm_addr(addr);
      wd_v := normalize_data(writedata);
      be_v := normalize_be(byteenable);

      for i in 0 to byte_lanes_v - 1 loop
        if be_v(i) = '1' then
          mem_v(a_v)(8 * i + 7 downto 8 * i) := wd_v(8 * i + 7 downto 8 * i);
        end if;
      end loop;

      accepted_writes_v := accepted_writes_v + 1;

      if verbose_v then
        report "AVM scoreboard: accepted write addr=" &
               integer'image(addr) &
               " model_addr=" &
               integer'image(a_v) &
               " data=0x" &
               to_hstring(wd_v(data_width_v - 1 downto 0)) &
               " be=0x" &
               to_hstring(be_v(byte_lanes_v - 1 downto 0))
          severity note;
      end if;
    end procedure accept_write;


    procedure accept_read (
      constant addr       : in natural;
      constant burstcount : in natural
    ) is
      variable a_v : natural;
    begin
      assert burstcount > 0
        report "AVM scoreboard: accepted read with burstcount = 0"
        severity error;

      if burstcount = 0 then
        errors_v := errors_v + 1;
        return;
      end if;

      for i in 0 to burstcount - 1 loop
        a_v := norm_addr(addr + i);
        push_expected(mem_v(a_v));
      end loop;

      accepted_reads_v := accepted_reads_v + 1;

      if verbose_v then
        report "AVM scoreboard: accepted read addr=" &
               integer'image(addr) &
               " burstcount=" &
               integer'image(burstcount) &
               " pending=" &
               integer'image(q_count_v)
          severity note;
      end if;
    end procedure accept_read;


    procedure check_readdata (
      constant actual : in std_logic_vector
    ) is
      variable actual_v   : sb_word_type;
      variable expected_v : sb_word_type;
    begin
      actual_v        := normalize_data(actual) and active_mask;

      pop_expected(expected_v);

      checked_words_v := checked_words_v + 1;

      if q_count_v = 0 and expected_v = (expected_v'range => 'X') then
        -- Underflow already reported by pop_expected.
        return;
      end if;

      if actual_v(data_width_v - 1 downto 0) /=
         expected_v(data_width_v - 1 downto 0) then
        errors_v := errors_v + 1;

        assert false
          report "AVM scoreboard mismatch. Expected 0x" &
                 to_hstring(expected_v(data_width_v - 1 downto 0)) &
                 ", got 0x" &
                 to_hstring(actual_v(data_width_v - 1 downto 0)) &
                 ". Checked word index=" &
                 integer'image(checked_words_v)
          severity error;
      else
        if verbose_v then
          report "AVM scoreboard: matched read data 0x" &
                 to_hstring(actual_v(data_width_v - 1 downto 0)) &
                 " pending=" &
                 integer'image(q_count_v)
            severity note;
        end if;
      end if;
    end procedure check_readdata;


    procedure final_check is
    begin
      if q_count_v /= 0 then
        errors_v := errors_v + 1;

        assert false
          report "AVM scoreboard final check failed: " &
                 integer'image(q_count_v) &
                 " expected read word(s) were never returned"
          severity error;
      end if;

      if errors_v /= 0 then
        assert false
          report "AVM scoreboard final check failed with " &
                 integer'image(errors_v) &
                 " error(s)"
          severity failure;
      else
        report "AVM scoreboard final check passed"
          severity note;
      end if;
    end procedure final_check;


    procedure report_status is
    begin
      report "AVM scoreboard status:" &
             " accepted_reads=" & integer'image(accepted_reads_v) &
             " accepted_writes=" & integer'image(accepted_writes_v) &
             " expected_words=" & integer'image(expected_words_v) &
             " checked_words=" & integer'image(checked_words_v) &
             " pending_words=" & integer'image(q_count_v) &
             " errors=" & integer'image(errors_v)
        severity note;
    end procedure report_status;


    impure function pending_count return natural is
    begin
      return q_count_v;
    end function pending_count;


    impure function error_count return natural is
    begin
      return errors_v;
    end function error_count;

   end protected body avm_scoreboard_type;

end package body avm_scoreboard_pkg;

