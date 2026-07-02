# Badges

This document explains the badges shown in the [project README](../README.md).

Each badge links to the live source of its data — clicking goes to the
CI run, the LICENSE file, or the relevant section of the coding style.
The information here is the *what* and *why* behind each badge; for
the *how* (the workflow itself), see
[`.github/workflows/ci.yml`](../.github/workflows/ci.yml).

---

## CI badges

The four CI badges report the result of the workflow defined in
`ci.yml`, run on every push to `main` and every pull request targeting
`main`. Each badge corresponds to one of the three jobs in that
workflow.

### `src`

> Status of `make src` on the latest commit to `main`.

The `src` job runs GHDL synthesis on every source file under `src/`. The badge
goes red if **any** synthesis fails, which means at least one of:

- GHDL refused to synthesize a file.

A green `src` badge does **not** mean every module is verified — only
that every source file is synthesizable. The per-module verification
status (which modules have a testbench at all) lives in the
[coverage matrix in `modules.md`](modules.md#verification-coverage-matrix).

### `sim`

> Status of `make sim` on the latest commit to `main`.

The `sim` job runs every GHDL testbench under `sim/tb_*/`. The badge
goes red if **any** testbench fails, which means at least one of:

- A `report ... severity failure` fired, e.g. a protocol violation
  detected by one of the BFM `assert_proc` blocks.
- A testbench exceeded `G_TIMEOUT_MAX` waiting for a response.
- GHDL refused to compile a file (rare, but possible after a refactor).

A green `sim` badge does **not** mean every module is verified — only
that every existing testbench passes. The per-module verification
status (which modules have a testbench at all) lives in the
[coverage matrix in `modules.md`](modules.md#verification-coverage-matrix).

### `formal`

> Status of `make formal` on the latest commit to `main`.

The `formal` job runs every SymbiYosys proof under `formal/`. The badge
goes red if **any** PSL property under any module fails — including
*"cover"* properties that document reachable scenarios (a cover that
becomes unreachable is usually a bug, not an improvement).

A green `formal` badge means the documented handshake contracts in
[`interfaces.md`](interfaces.md) — VALID/READY stability, in-order
responses, mutual exclusion of arbiter grants, etc. — hold for the
subset of modules that have property files. Modules without a PSL file
contribute nothing to this badge.

Counterexample traces from failed proofs are uploaded as CI artefacts
for 7 days; click through the failed run to download them and open in
GTKWave.

### `style`

> Status of the style checks on the latest commit to `main`.

The `style` job runs cheap, no-toolchain checks that catch
documentation drift. Currently:

- **SPDX header presence.** Every file under `src/` and `sim/` must
  carry an `SPDX-License-Identifier: MIT` line. See
  [`CODING_STYLE.md` §18](../CODING_STYLE.md#18-license-headers).
- **Markdown link integrity.** Every `[text](target)` link in the root
  markdown files must resolve. Configuration in
  [`.github/mlc_config.json`](../.github/mlc_config.json).

A red `style` badge is the cheapest one to fix: the failure message
points at the offending file and line. It's also the cheapest one to
prevent — both checks are runnable locally:

```sh
# SPDX
git grep -L 'SPDX-License-Identifier' -- 'src/**/*.vhd' 'sim/**/*.vhd'

# Links (requires npm i -g markdown-link-check)
markdown-link-check README.md interfaces.md modules.md
```

---

## Static badges

The remaining badges are not driven by CI. They convey project
metadata that changes rarely.

### `license: MIT`

The MIT license is permissive and allows commercial use, modification,
and redistribution without source release. The full text is in
[`LICENSE`](../LICENSE). Every individual file under `src/` and `sim/`
also carries the license identifier as an SPDX header so the grant is
unambiguous on a per-file basis if you copy individual modules into a
larger project.

### `VHDL: 2008`

All RTL and simulation code in this repository targets VHDL-2008. The
specific 2008 features in use are listed in
[`CODING_STYLE.md` §1](../CODING_STYLE.md#1-language-and-tooling).
Files will not compile cleanly under VHDL-93 / VHDL-2002.

### `status: active development`

There are no tagged releases yet. Module APIs may change. If you
depend on this repository in another project, pin to a specific commit
SHA — not to `main`. This badge will switch to *"stable"* when the
first tagged release is cut; see
[CONTRIBUTING.md §11](../CONTRIBUTING.md#11-open-questions-tracked-elsewhere)
for the open architectural questions that block tagging.

---

## How the badges are generated

The three CI badges use the GitHub Actions badge URL:

In the URL pattern below, replace <owner>, <repo>, <file>, and <job-name>.

```
https://github.com/<owner>/<repo>/actions/workflows/<file>/badge.svg?branch=main&job=<job-name>
```

This URL is served directly by GitHub and reflects the most recent
workflow run on the named branch. It updates automatically — there is
no shielding or caching layer in between.

The static badges use [shields.io](https://shields.io). These are
manually authored and only change when the source markdown is edited.

If you fork this repository, update every badge URL in
[`README.md`](../README.md) to point at your fork's owner / repo. The
badges will keep showing *the upstream's* status until you do.

---

## Why no `tests passing` / `coverage` / `version` badges?

Some common badges that are deliberately **not** present:

- **`tests passing` (counter).** The `sim` job already conveys
  pass/fail; a counter adds visual noise without information.
- **`coverage %`.** Code coverage for HDL is poorly standardised and
  no two tools agree on what counts. The verification-coverage matrix
  in [`modules.md`](modules.md#verification-coverage-matrix) tracks
  what matters at the per-module level: does this module have a
  testbench? a formal proof? both? neither?
- **`version`.** There are no tagged releases yet. When there are, a
  shields.io `github/v/release/MJoergen/fpga_utilities` badge will
  appear above `license`.
- **`stars`, `forks`, `contributors`.** These are visible on the
  repository page already and don't belong in a documentation badge
  row.

---

## Adding a new badge

If you propose a new badge, the bar to clear is:

1. **It must convey actionable information.** If it's always green
   (or always grey), it's noise.
2. **It must have a stable source.** GitHub Actions and `shields.io`
   are stable; third-party services that show "no data" after a few
   months are not.
3. **It must link to the underlying data.** A badge that doesn't link
   anywhere is decoration.
4. **It must be explained here.** Add a section to this document in
   the same PR.

Open a [style revision issue](../.github/ISSUE_TEMPLATE/style_revision.yml)
before adding a badge — they affect every visitor's first impression
of the project.

