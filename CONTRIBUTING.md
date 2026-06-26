# Contributing to fpga_utilities

Thanks for taking the time to contribute. This document covers the
workflow side of the repository: how to add modules, testbenches, and
outside WSL.

Tested on Ubuntu 22.04 LTS. Other Linux distributions and macOS
should work; please open an issue if they don't.
The build system has not been tested on Windows

---

## 2. Repository layout

```
src/         synthesisable VHDL
  avm/         Avalon-MM modules                (avm_*)
  axil/        AXI-Lite modules                 (axil_*)
  axip/        AXI packet modules               (axip_*)
  axis/        AXI streaming modules            (axis_*)
  wbus/        Wishbone modules                 (wbus_*)
  converters/  cross-interface bridges          (axil_to_wbus, …)
sim/
  src/         bus-functional models and helpers
  tb_<m>/      one testbench per module
formal/        SymbiYosys configs and PSL properties
Makefile       top-level driver: `make sim`, `make formal`
```

Every file lives in exactly one of these places. If you're not sure
where, ask in your PR description.

---

## 3. Running the regression locally

From the repo root:

```sh
make sim       # run all GHDL testbenches
make formal    # run all SymbiYosys proofs
make           # both
```

A regression run produces no output other than per-testbench progress;
any failure prints a `report ... severity failure;` line and a non-zero
exit. **All of `make sim` and `make formal` must pass on `main`.**

To run a single testbench:

```sh
make -C sim/tb_axip_fifo
```

To open the waveform of the most recent run:

```sh
gtkwave sim/tb_axip_fifo/tb_axip_fifo.gtkw
```

To run a single formal proof:

```sh
make -C formal axis_fifo
# or directly:
sby -f formal/axis_fifo.sby
```

---

## 4. Adding a new module

A new module is a four-step process. None of the steps is optional;
"I'll add the testbench later" is the most common source of unverified
modules and is a smell, not a workflow.

### 4.1 Pick a name and a home

- Decide which interface family the module belongs to. If it bridges
  two, it goes in `src/converters/`.
- Name the entity `<family>_<purpose>`, e.g. `axip_dropper`,
  `wbus_decoder`. The file name matches the entity, lower case,
  `.vhd` extension.
- Check the existing inventory in [modules.md](modules.md) before
  picking a name; reuse a pattern if one exists (`*_fifo`, `*_pipe`,
  `*_arbiter`, `*_arbiter_general`, `*_fifo_async`, `*_pipe_async`).

### 4.2 Write the RTL

Use this skeleton:

```vhdl
-- ---------------------------------------------------------------------------------------
-- Description: <what this module does, in one or two sentences>
--
-- SPDX-License-Identifier: MIT
-- ---------------------------------------------------------------------------------------

library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std.all;

entity <family>_<purpose> is
  generic (
    -- mandatory generics first
    G_DATA_BITS : positive;
    -- optional generics last
    G_DEBUG     : boolean := false
  );
  port (
    clk_i     : in    std_logic;
    rst_i     : in    std_logic;

    -- <slave / sender / sink> side
    s_ready_o : out   std_logic;
    s_valid_i : in    std_logic;
    s_data_i  : in    std_logic_vector(G_DATA_BITS - 1 downto 0);

    -- <master / receiver / source> side
    m_ready_i : in    std_logic;
    m_valid_o : out   std_logic;
    m_data_o  : out   std_logic_vector(G_DATA_BITS - 1 downto 0)
  );
end entity <family>_<purpose>;

architecture rtl of <family>_<purpose> is
  type   state_type is (IDLE_ST);
  signal state : state_type := IDLE_ST;
begin

  -- Elaboration-time constraints
  assert G_DATA_BITS > 0
    report "<family>_<purpose>: G_DATA_BITS must be positive"
    severity failure;

  fsm_proc : process (clk_i)
  begin
    if rising_edge(clk_i) then
      -- defaults / self-clearing pulses

      case state is
        when IDLE_ST =>
          null;
      end case;

      if rst_i = '1' then
        m_valid_o <= '0';
        state     <= IDLE_ST;
      end if;
    end if;
  end process fsm_proc;

end architecture rtl;
```

Then walk the checklist in [§20 of `CODING_STYLE.md`](CODING_STYLE.md).
Anything you can't tick is a reason to *not* open the PR yet.

### 4.3 Add a testbench

Create `sim/tb_<family>_<purpose>/` containing at minimum:

- `Makefile` — copy from a sibling testbench (`sim/tb_axis_fifo/Makefile`
  is a clean reference) and update the source list.
- `tb_<family>_<purpose>.vhd` — the testbench entity. Architecture name
  is `tb`. The skeleton:

  ```vhdl
  -- ---------------------------------------------------------------------------------------
  -- Description: Testbench for <family>_<purpose>.
  --
  -- SPDX-License-Identifier: MIT
  -- ---------------------------------------------------------------------------------------

  library ieee;
    use ieee.std_logic_1164.all;
    use ieee.numeric_std_unsigned.all;
    use std.env.stop;

  entity tb_<family>_<purpose> is
  end entity tb_<family>_<purpose>;

  architecture tb of tb_<family>_<purpose> is
    constant C_CLK_PERIOD : time := 10 ns;
    signal   clk          : std_logic := '0';
    signal   rst          : std_logic := '1';
    -- DUT and BFM signals
  begin

    clk <= not clk after C_CLK_PERIOD / 2;
    rst <= '1', '0' after 5 * C_CLK_PERIOD;

    -- Instantiate the relevant <family>_master_sim, <family>_slave_sim,
    -- and the DUT. Connect via <family>_pause for stress testing.

    -- ...

  end architecture tb;
  ```

- Optionally, `tb_<family>_<purpose>.gtkw` — a GTKWave session file
  with a useful default signal layout. Worth including; reviewers will
  open it.

A good testbench:

- Uses the matching `<family>_master_sim` and `<family>_slave_sim`
  BFMs from `sim/src/`. Don't roll your own request driver.
- Inserts a `<family>_pause` BFM somewhere in the path to stress
  back-pressure. Without it, your testbench is only exercising the
  happy path.
- Sets `G_DEBUG => true` on the BFMs only when interactively
  debugging. Regressions should be silent on success.
- Calls `std.env.stop` on completion (not `wait`; not `assert false`).
- Terminates **deterministically**. Random seeds come from `G_SEED`
  generics on the BFMs; pick fixed seeds in the testbench. A
  testbench that hangs indefinitely is a regression hazard.

### 4.4 Add a formal property (recommended)

For most modules, a small PSL file goes a long way:

- `formal/<module>.psl` — the properties (handshake stability,
  in-order responses, no-spurious-acks, etc.).
- `formal/<module>.sby` — the SymbiYosys driver. Copy from a sibling.

A good first property is always *"this module respects the handshake
rules of the interface specified in `interfaces.md`"*. The reference
examples are `formal/axip_arbiter.psl` and `formal/axis_fifo.psl`.

If the module is genuinely hard to formally verify in a short time
(e.g. a deeply pipelined CDC FIFO), it is acceptable to ship without a
formal proof — but the module must be flagged as *unverified* in
[modules.md](modules.md), and a tracking issue opened.

### 4.5 Update the documentation

In the same PR:

- Add the module to [modules.md](modules.md) under the appropriate
  section. Update the verification-coverage matrix at the top.
- If the module exposes a new interface variant or breaks a documented
  contract, update [interfaces.md](interfaces.md) accordingly.
- If the module is significant enough to mention in the README's
  *Modules* bullets, add it there too.

A PR that adds RTL without updating `modules.md` will not be merged.

---

## 5. Adding a testbench to an existing unverified module

The current verification gap is tracked in
[modules.md](modules.md#verification-coverage-matrix). Closing a row is
a high-value contribution.

1. Pick a row marked *unverified*.
2. Open an issue saying you're working on it, to avoid duplicate work.
3. Follow §4.3 above.
4. Update the coverage matrix in `modules.md` in the same PR.

The same applies to formal proofs.

---

## 6. Modifying an existing module

### 6.1 Behavioural changes

If your change affects the wire-level behaviour of the module:

- Update or extend the testbench so it would have caught the previous
  behaviour as a failure. *No "would have caught" → no merge.* If a
  bug escaped the existing testbench, the testbench is part of the
  bug.
- Update or extend the formal property if one exists. The property is
  the executable specification; if the spec changed, the property
  must change.
- If the change affects the interface contract documented in
  `interfaces.md`, update that file in the same PR.

### 6.2 Refactoring

Refactoring PRs (no behavioural change) are welcome and reviewed on a
different bar:

- The testbench is expected to pass unchanged. If you find yourself
  needing to modify the testbench to make a refactor pass, the
  "refactor" was actually a behavioural change — go back to §6.1.
- Refactors that close `CODING_STYLE.md` violations are particularly
  welcome. Reference the rule number in the commit message
  (`fix(axil_to_wbus): generic naming per CODING_STYLE.md §5.1`).

### 6.3 Renames

Renaming an entity, file, signal, or generic ripples through:

- the RTL itself,
- its testbench (`tb_<module>/`),
- its formal files (`formal/<module>.*`),
- `modules.md`, `interfaces.md`, README,
- any other module that instantiates it.

Do the whole rename in **one PR**. Half-renamed state is worse than no
rename.

---

## 7. Pull requests

### 7.1 Pre-flight checklist

Before opening a PR, run locally:

```sh
make sim
make formal

# CODING_STYLE.md §18 — every file has an SPDX header
git grep -L 'SPDX-License-Identifier' -- 'src/**/*.vhd' 'sim/**/*.vhd'
```

If `make sim` or `make formal` fails on `main` before your change, open
an issue rather than working around it.

### 7.2 Commit messages

We use conventional-style prefixes:

- `feat(<scope>): …` — new module, new feature.
- `fix(<scope>): …` — bug fix.
- `refactor(<scope>): …` — no behavioural change.
- `docs(<scope>): …` — documentation only.
- `test(<scope>): …` — testbench changes.
- `formal(<scope>): …` — formal property changes.
- `chore: …` — build system, repository hygiene, dependencies.

`<scope>` is the module name where it's meaningful
(`fix(wbus_arbiter): …`), the area of the docs otherwise
(`docs(interfaces): …`).

The body explains *why*, not *what* — the diff says what.

### 7.3 PR description

Include:

- A short description of the change.
- Which rule in `CODING_STYLE.md` (if any) this PR closes or follows.
- A statement that `make sim` and `make formal` pass locally on your
  branch.
- Any new `[CONFIRM]` markers introduced (please don't — but if
  unavoidable, list them and link to a tracking issue).

PRs that change RTL behaviour and don't say what tests were added are
returned without review.

### 7.4 Review and merge

- Reviewers will check against `CODING_STYLE.md` mechanically — see
  §2 of that document. Disputes about style live in the style
  document, not in the PR thread.
- Bug fixes and verification additions are merged on a single
  reviewer's approval.
- New RTL modules and changes to `interfaces.md` require a second
  reviewer.
- The maintainer (currently @MJoergen) does the final merge.

We squash-merge by default. Keep your PR's commits clean if you want
them preserved; otherwise the squash will produce a single commit
named after the PR.

---

## 8. Reporting bugs

Open an issue with:

- The minimal reproduction (a testbench is best; a tagged-line code
  snippet is acceptable).
- The expected vs. observed behaviour, with reference to either
  `interfaces.md` or the relevant spec (AMBA, Wishbone B4, Avalon-MM).
- The GHDL / Yosys / SymbiYosys versions you reproduced with.
- For formal failures, the SymbiYosys output trace if available.

If the bug is a `CODING_STYLE.md` violation rather than a functional
problem, file it but mark it `style:` — these are batched.

---

## 9. Suggesting new modules

Open an issue first, *before* writing code. The discussion answers
the cheap questions early:

- Does this fit one of the existing interface families, or does it
  imply a new interface?
- Is there already a module that covers the use case under a different
  name?
- What does the testbench look like? (If you can't sketch a
  testbench, the module is under-specified.)
- What is the verification plan? (Testbench, formal, or both?)

A module proposed without an issue and a sketch of the verification
plan will not be reviewed.

---

## 10. License

This project is MIT-licensed. By contributing a PR, you agree your
contribution is licensed under the same terms. Every new `.vhd` file
must carry the SPDX header (`-- SPDX-License-Identifier: MIT`) from the
moment it is committed.

---

## 11. Open questions tracked elsewhere

Architectural items still under discussion live in
[`CODING_STYLE.md` §19](CODING_STYLE.md#19-open-questions). Don't
introduce a third interpretation in a PR; resolve the question in an
issue first, update `CODING_STYLE.md`, then open the PR.
formal proofs; how to run the full regression locally; and what we
expect to see in a pull request.

For *coding conventions*, see [CODING_STYLE.md](CODING_STYLE.md). For
the *interface contracts* every module must obey, see
[interfaces.md](interfaces.md). For the *current module inventory*, see
[modules.md](modules.md). This document does not duplicate any of
those; it points at them.

---

## 1. Prerequisites

You need:

- **GHDL** with VHDL-2008 support. The reference invocation is
  `ghdl --std=08`.
- **GNU Make** (3.81+).
- **GTKWave** (optional, but recommended for inspecting test failures).
- **SymbiYosys** + **Yosys** with the GHDL frontend, for formal
  verification. The reference invocation is `sby -f <module>.sby`.

