# Coding style

This document records the VHDL coding conventions used in
`fpga_utilities`. It exists for two reasons:

1. To keep the modules in `src/`, `sim/`, and `formal/` internally
   consistent so a reader of one module knows what to expect from any
   other.
2. To make code review mechanical: anything that breaks a rule below is
   either a bug or a rule that needs revisiting — but not a debate to
   have in every PR.

The rules are **prescriptive**. If a rule does not yet match the
code, that means either the code is wrong (most often), or the rule is
wrong (occasionally). Please do not introduce a third interpretation.

---

## 1. Language and tooling

- **VHDL-2008** for all RTL and simulation code. Specific 2008 features
  in use:
  - `process (all)` for combinational logic.
  - Reading own `out` ports inside the architecture.
  - Generic packages where useful.
  - `to_hstring`, `to_string` for debug reporting.
- **GHDL** is the reference simulator. Code must compile and run cleanly
  under GHDL with `--std=08`.
- **SymbiYosys** + yosys (with the GHDL frontend) is the reference
  formal-verification flow. PSL property files live in `formal/`.

---

## 2. File organisation

- **One entity per file.** The file name is the entity name in lower
  case with `.vhd` extension.
- Production RTL lives in `src/<interface>/`, where `<interface>` is one
  of `avm`, `axil`, `axip`, `axis`, `wbus`, `converters`.
- Bus-functional models and shared simulation helpers live in
  `sim/src/`.
- Testbenches live in `sim/tb_<entity>/`. Each testbench directory
  contains a `Makefile`, the testbench VHDL, and optionally a `.gtkw`
  GTKWave session file.
- Formal properties live in `formal/<entity>.psl`; their SymbiYosys
  configurations live in `formal/<entity>.sby`.

Every `.vhd` file starts with:

```vhdl
-- ---------------------------------------------------------------------------------------
-- Description: <one or two sentences explaining what this module does>
--
-- SPDX-License-Identifier: MIT
-- ---------------------------------------------------------------------------------------
```

The description must convey *intent*, not just restate the entity name.

---

## 3. Library and package imports

The standard preamble for production RTL is:

```vhdl
library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std.all;
```

The standard preamble for bus-functional models and testbenches is:

```vhdl
library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std_unsigned.all;
  use std.env.stop;
```

**Rationale.** Production RTL uses `numeric_std` with explicit
`to_integer(unsigned(...))` conversions to make every type cast
visible. Simulation BFMs are pointer-arithmetic heavy and benefit
from the implicit arithmetic on `std_logic_vector` that
`numeric_std_unsigned` provides. **Do not mix the two in the same
file.**

---

## 4. Architecture names

Three architecture names, used by file type:

| File type            | Architecture name |
| -------------------- | ----------------- |
| Production RTL       | `rtl`             |
| Bus-functional model | `simulation`      |
| Top-level testbench  | `tb`              |

This trichotomy lets a reader tell at a glance whether a file is meant
to be synthesised, instantiated only in simulation, or run as a
top-level testbench.

---

## 5. Generics

### 5.1 Naming

Use the `G_` prefix and SCREAMING_SNAKE_CASE.

| Concept                          | Generic name      |
| -------------------------------- | ----------------- |
| Address width (bits)             | `G_ADDR_BITS`     |
| Data width (bits)                | `G_DATA_BITS`     |
| Data width (bytes, AXIP only)    | `G_DATA_BYTES`    |
| Burst-count field width (bits)   | `G_BURST_BITS`    |
| FIFO/RAM depth (entries)         | `G_RAM_DEPTH`     |
| RAM-style attribute              | `G_RAM_STYLE`     |
| Timeout (cycles)                 | `G_TIMEOUT_MAX`   |
| Random seed                      | `G_SEED`          |
| Name (for BFM diagnostic prints) | `G_NAME`          |
| Debug verbosity                  | `G_DEBUG`         |

**Width-naming rule.** Width generics end in `_BITS` and are measured
in bits, *except* AXIP modules which use `_BYTES` because the AXIP
interface is byte-oriented at the spec level. Document this exception
explicitly in entity headers that use `G_DATA_BYTES`.

### 5.2 Order

Generics are listed in this order:

1. Mandatory generics with no default (`G_ADDR_BITS`, `G_DATA_BITS`, …).
2. Optional generics with defaults (`G_RAM_STYLE := "auto"`, …).

Within each group, list interface widths first, then everything else.
Avoid positional `generic map` at instantiation sites.

### 5.3 Elaboration-time assertions

Non-trivial generic interactions must be checked at elaboration:

```vhdl
assert (G_DATA_BITS mod 8) = 0
  report "<entity_name>: G_DATA_BITS must be a multiple of 8"
  severity failure;
```

Use `severity failure` so the assertion stops simulation immediately.
Every entity that has interacting generics should carry at least one
such assertion documenting the contract.

---

## 6. Ports

### 6.1 Naming

- Inputs end in `_i`. Outputs end in `_o`. There are no inouts.
- Clock and reset are `clk_i` and `rst_i`. No exceptions.
- Bus role prefixes:
  - `s_*`  for the single slave-side / sender-side / sink-side of a
    point-to-point interface.
  - `m_*`  for the single master-side / receiver-side / source-side.
  - `s0_*`, `s1_*` for arbiters/distributors with two slave-side
    interfaces. (Generalise to `s2_*`, `s3_*` for `*_general` variants.)
  - `h_*`  for the header side of a header-insert/remove module.
- **Do not** add an interface qualifier to ports (no `s_axil_awvalid_i`;
  use `s_awvalid_i`). The entity name says which interface is which.
- Signal names below the role prefix follow the spec for that interface:
  - AXI streaming: `valid`, `ready`, `data`.
  - AXI packet: `valid`, `ready`, `data`, `last`, `bytes`.
  - AXI Lite: `awvalid`, `awready`, `awaddr`, `wvalid`, `wready`, `wdata`,
    `wstrb`, `bvalid`, `bready`, `bresp`, `arvalid`, `arready`, `araddr`,
    `rvalid`, `rready`, `rdata`, `rresp`.
  - Wishbone: `cyc`, `stall`, `stb`, `addr`, `we`, `wrdat`, `sel`, `ack`,
    `rddat`.
  - Avalon-MM: `waitrequest`, `write`, `read`, `address`, `writedata`,
    `byteenable`, `burstcount`, `readdata`, `readdatavalid`.

### 6.2 Port comments

Do not add per-port trailing comments. Refer to
[`interfaces.md`](interfaces.md) instead. The entity declaration is for
*shape*; the interface contract belongs in the spec.

### 6.3 Types

- `std_logic` for single-bit signals.
- `std_logic_vector(N-1 downto 0)` for multi-bit signals.
- `natural range 0 to N` for narrow integer signals that are exposed at
  the entity boundary and carry a specific natural-number meaning (e.g.
  AXIP `BYTES` or FIFO `fill`). Document the meaning in the entity
  header.

---

## 7. Reset convention

- **Synchronous, active-high, single signal `rst_i`.** No exceptions.
- The reset clause is the **last** assignment block in the clocked
  process, so it overrides any earlier case/elsif assignments:

  ```vhdl
  proc : process (clk_i)
  begin
    if rising_edge(clk_i) then
      -- ... functional logic ...

      if rst_i = '1' then
        m_valid_o <= '0';
        state     <= IDLE_ST;
      end if;
    end if;
  end process proc;
  ```
- Reset clears only **control and handshake signals** (`valid`, `cyc`,
  `stb`, `ack`, state). Data, address, and similar payload signals are
  don't-care while their corresponding `valid`/`stb` is low and need not
  be reset. Add a one-line comment to that effect if the omission is
  not obvious.
- For every clocked signal, if a signal has a declared init, that init must match the
  reset value.
  If `signal x : std_logic := '0';`, the reset clause must also drive `x <= '0';`.

---

## 8. Clocking

- All RTL is single-clock unless the module name ends in `_async`.
- `_async` entities have two clocks named `clk_a_i` / `clk_b_i` (or
  `s_clk_i` / `m_clk_i` where the master/slave distinction is clear).
  They must carry a header comment naming the CDC scheme and any
  timing constraint the user must add (e.g. `set_max_delay` on pointer
  paths).
- Combinational logic inside a clocked process is forbidden. Use a
  separate `process (all)` block, a concurrent assignment, or a pure
  function.

---

## 9. Process names and structure

- Clocked processes (FSM, datapath registers) are named with a `_proc`
  suffix.
- The single main clocked process in an FSM module is called
  `fsm_proc`. Modules with multiple state machines prefix the FSM name:
  `tx_fsm_proc`, `rx_fsm_proc`.
- Combinational processes use `_proc` as well.
- Section dividers above non-trivial processes use a single line:

  ```vhdl
  ---------------------------------------------------------------------------
  -- <one-line summary of what this process does>
  ---------------------------------------------------------------------------
  ```
- Inside a process body, the standard skeleton is:

  ```vhdl
  fsm_proc : process (clk_i)
  begin
    if rising_edge(clk_i) then
      -- defaults / self-clearing pulses
      ...

      case state is
        when ...
      end case;

      -- ... other registered assignments ...

      if rst_i = '1' then
        ...
      end if;
    end if;
  end process fsm_proc;
  ```

---

## 10. Naming for local declarations

| Kind                          | Convention              | Example                |
| ----------------------------- | ----------------------- | ---------------------- |
| Signal                        | `lower_snake_case`      | `req_active`           |
| Variable                      | `lower_snake_case`      | `handled_v`            |
| Subtype                       | `lower_snake_case_type` | `index_type`           |
| Type                          | `lower_snake_case_type` | `state_type`           |
| Constant                      | `UPPER_SNAKE_CASE`      | `C_RESP_OKAY`          |
| Function / procedure          | `lower_snake_case`      | `next_index`           |
| Process                       | `lower_snake_case_proc` | `fsm_proc`             |
| Generic                       | `G_UPPER_SNAKE_CASE`    | `G_DATA_BITS`          |
| Range subtype (slice helper)  | `R_UPPER_SNAKE_CASE`    | `R_DATA`, `R_HEADER`   |

State enum values end in `_ST`:

```vhdl
type state_type is (IDLE_ST, WRITING_ST, READING_ST, ABORTING_ST, DONE_ST);
```

State enums use names that mirror the role they represent. For arbiters
the convention is `S0_ST`/`S1_ST` (matching the `s0_*`/`s1_*` ports),
not `INPUT_0_ST`/`INPUT_1_ST`.

---

## 11. Subprograms vs duplicated branches

If two state-machine branches or two `s0_*`/`s1_*` paths are mirror
images of each other, factor them into a procedure inside the process,
parameterised by the "self" and "other" identifiers. The reference
example is `arbitrate_end_of_burst` in `avm_arbiter`. Do not allow more
than one duplicated copy of a non-trivial branch to stay in the
codebase.

---

## 12. Conditional style

Use the explicit form for `std_logic` comparisons:

```vhdl
if m_ready_i = '1' then
```

…not:

```vhdl
if m_ready_i then
```

Both are legal in VHDL-2008. The explicit form is easier to grep and
unambiguous to lint tools.

For mutually exclusive branches, always use `elsif`. Two independent
`if … if …` blocks are a frequent source of "last assignment wins"
bugs (see e.g. the IDLE_ST write/read race fixed in `axil_to_wbus`).

---

## 13. Don't-care assignments

When a signal is don't-care (e.g. data lanes outside `SEL`, or
unselected bytes on the AXIP `LAST` beat), drive a **stable** value:

- `(others => '0')` is the default — explicit, easy to spot in
  waveforms, never propagates X.
- `(others => '-')` is acceptable when the formal flow uses it to mark
  optimisable don't-care lanes.
- Driving the *previous* register value (e.g. `s_data` rather than
  `s_data_i`) is acceptable when it avoids X-propagation from a stalled
  upstream master.

Do **not** rely on upstream signals continuing to drive valid values
on cycles where they are not handshaking — they're allowed to drive
`'U'` or `'X'`.

---

## 14. Reporting / diagnostics

- Use `report "<module name> <G_NAME>: <message>"` with a leading
  identifier so logs are greppable. Example:

  ```vhdl
  report "WBUS MASTER " & G_NAME & ": Timeout waiting for response";
  ```
- Severities:
  - `note` — informational. Off by default; gated by `G_DEBUG`.
  - `warning` — recoverable anomaly (e.g. soft elaboration constraint
    breached).
  - `error` — protocol violation in simulation. Bump to `failure` if the
    test must stop.
  - `failure` — generic constraint broken at elaboration, or unrecoverable
    runtime violation. Always stops simulation.
- BFMs that produce many similar reports should factor a small
  procedure to avoid the boilerplate.

---

## 15. Assertions in production RTL

Assertions are encouraged in `rtl` files **provided** they have no
synthesis side-effect. The convention:

- Place top-of-architecture assertions in `assert` concurrent
  statements, grouped together with a comment.
- Use a `severity failure` so simulation stops on violation; do not
  rely on the default severity.
- Do not prefix assertion labels with `f_` — that prefix is reserved
  for PSL properties in `formal/`. Plain `assert` labels in `rtl/`
  should be descriptive: `assert_grant_mutex`, `assert_sel_aligned`,
  etc.

---

## 16. Packages

- `axip_pkg` and `wbus_pkg` declare records, types, and helper
  functions used by their interface family. Every consumer of an
  `axip_*` or `wbus_*` entity must `use` the corresponding package.
- Empty package bodies are not written. If a package contains only
  declarations, omit the `package body … is end;` block.
- Magic widths and packing offsets (e.g. how AXIP `LAST` and `BYTES`
  are packed into a single `std_logic_vector` for FIFO storage) belong
  in the package as functions, not as literals in each consumer.

---

## 17. Verification

Every module in `src/` is expected to have **at least one** of:

- a simulation testbench at `sim/tb_<module>/`, and/or
- a formal property file at `formal/<module>.psl`.

A module with neither is *unverified* and must be flagged as such in
`modules.md`. New unverified modules should not be merged without a
tracking issue.

Naming:

- Testbench entity: `tb_<module>`.
- Formal property file: `<module>.psl`, SymbiYosys config:
  `<module>.sby`, GTKWave session: `tb_<module>.gtkw` /
  `<module>.gtkw`.

---

## 18. License headers

Every file under `src/` and `sim/` must carry an SPDX header in its
top comment block:

```
-- SPDX-License-Identifier: MIT
```

A one-shot to check the codebase:

```sh
git grep -L 'SPDX-License-Identifier' -- 'src/**/*.vhd' 'sim/**/*.vhd'
```

The list must be empty before tagging a release.

---

## 19. Open questions

These are items where the codebase has not yet converged on a single
convention. Each will be resolved in a future revision of this
document:

- **Arbitration policy.** The arbiters in `axis`, `axip`, `wbus`, and
  `avm` use three different policies (strict alternation, two-state
  round-robin, and configurable swap-on-idle). The intent is to align
  them on a common `G_PREFER_SWAP`-style policy generic, but the
  rename and refactor are not yet done.
- **`_lite` pipeline variants.** `axis_pipe_lite` exists; the other
  families do not have a `_lite` counterpart. Whether to generalise or
  remove is undecided.

---

## 20. Quick-reference checklist for a new module

- [ ] Header block with description and SPDX license.
- [ ] `library ieee; use ieee.std_logic_1164.all; use ieee.numeric_std.all;` (or `numeric_std_unsigned` for BFMs).
- [ ] `architecture rtl of …` (or `simulation`, or `tb`).
- [ ] Generics: mandatory first, defaults last; `G_DATA_BITS` (or `G_DATA_BYTES` for AXIP).
- [ ] Ports: `clk_i`, `rst_i`, then `s_*` / `m_*` groups; no per-port comments; no interface qualifiers.
- [ ] Synchronous active-high reset, applied last in every clocked process.
- [ ] Declared signal init agrees with reset value.
- [ ] No two independent `if`s where `if … elsif` is meant.
- [ ] Elaboration-time `assert`s for non-trivial generic constraints.
- [ ] One of: testbench, formal property, or explicit "unverified" flag.
- [ ] Entry added (or kept up to date) in `modules.md`.

