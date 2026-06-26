<!--
Thanks for contributing! Please fill in the sections below.
A PR without test/formal evidence of behaviour will be returned without review.
See CONTRIBUTING.md §7 for the full pre-flight checklist.
-->

## Summary

<!-- One or two sentences. What does this PR do, and why? -->

## Type of change

<!-- Tick all that apply. -->

- [ ] `feat`     — new module or new feature
- [ ] `fix`      — bug fix (functional or protocol)
- [ ] `refactor` — no behavioural change
- [ ] `docs`     — documentation only
- [ ] `test`     — testbench changes
- [ ] `formal`   — formal property changes
- [ ] `chore`    — build system / repository hygiene

## Scope

<!-- Module name(s) or documentation area. Examples:
       wbus_arbiter, axil_to_wbus
       interfaces, modules, CODING_STYLE -->

## Relevant rule or contract

<!-- If this PR closes or follows a specific rule, link it.
     Examples:
       Closes CODING_STYLE.md §5.1 (generic naming).
       Implements interfaces.md#wishbone SEL handling.
       Fixes wbus_arbiter B5 from the internal audit.
     If none, write "n/a". -->

## Behavioural change details

<!-- Required for `feat` and `fix`. Skip for pure `refactor`, `docs`, `chore`. -->

### What changed

<!-- One paragraph. What does the module / file do differently now? -->

### How was it caught / how is it now caught

<!-- Required for `fix`: which testbench or formal property exercises the bug?
     Required for `feat`: which testbench / formal property exercises the new
     behaviour? "Would have caught" is the standard - if the existing tests
     don't fail on the previous code, the test is part of the fix. -->

### Interface contract impact

<!-- Does this change the wire-level behaviour of an interface as documented in
     interfaces.md? If yes, did you update interfaces.md in this PR? -->

- [ ] No interface contract change.
- [ ] Interface contract changed; `interfaces.md` updated in this PR.

## Pre-flight checklist

<!-- Tick when done. Don't open the PR with unticked boxes unless you say why
     in the section below. -->

- [ ] `make sim` passes locally.
- [ ] `make formal` passes locally.
- [ ] Every new `.vhd` file has an SPDX header
      (`git grep -L 'SPDX-License-Identifier' -- 'src/**/*.vhd' 'sim/**/*.vhd'` is empty).
- [ ] `CODING_STYLE.md` §20 checklist walked for every new / renamed entity.
- [ ] `modules.md` updated (entry + coverage matrix) if `src/` changed.
- [ ] `interfaces.md` updated if the interface contract changed.
- [ ] README updated if the bullets in *Modules* or the interface table changed.
- [ ] No new `[CONFIRM]` markers introduced. If unavoidable, listed below with
      a tracking issue link.

## Renames touched (if any)

<!-- A rename PR must update every site in one go.
     Tick the ones you touched, or write "n/a". -->

- [ ] RTL (`src/`)
- [ ] Testbench (`sim/tb_<module>/`)
- [ ] Formal (`formal/<module>.{psl,sby,gtkw}`)
- [ ] BFMs (`sim/src/`)
- [ ] `modules.md` / `interfaces.md` / README
- [ ] Other instantiators

## Notes for the reviewer

<!-- Anything that helps the reviewer: tricky corner cases, deferred items,
     follow-up PRs you plan to open. Optional. -->

