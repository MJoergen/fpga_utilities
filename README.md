# fpga_utilities

[![CI – src](https://github.com/MJoergen/fpga_utilities/actions/workflows/ci.yml/badge.svg?branch=main&event=push&job=src)](https://github.com/MJoergen/fpga_utilities/actions/workflows/ci.yml?query=branch%3Amain)
[![CI – sim](https://github.com/MJoergen/fpga_utilities/actions/workflows/ci.yml/badge.svg?branch=main&event=push&job=sim)](https://github.com/MJoergen/fpga_utilities/actions/workflows/ci.yml?query=branch%3Amain)
[![CI – formal](https://github.com/MJoergen/fpga_utilities/actions/workflows/ci.yml/badge.svg?branch=main&event=push&job=formal)](https://github.com/MJoergen/fpga_utilities/actions/workflows/ci.yml?query=branch%3Amain)
[![CI – style](https://github.com/MJoergen/fpga_utilities/actions/workflows/ci.yml/badge.svg?branch=main&event=push&job=style)](https://github.com/MJoergen/fpga_utilities/actions/workflows/ci.yml?query=branch%3Amain)
[![License: MIT](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)
[![VHDL: 2008](https://img.shields.io/badge/VHDL-2008-informational)](CODING_STYLE.md#1-language-and-tooling)
[![Status: active](https://img.shields.io/badge/status-active%20development-orange)](#status)

A collection of small, reusable VHDL-2008 building blocks for FPGA
development. The intent is to use these modules as "LEGO" bricks — drop
them into your design wherever needed.

Most modules are exercised by [GHDL simulation testbenches](sim/) under
`sim/tb_*/`, and a subset additionally has
[SymbiYosys formal proofs](formal/). The per-module coverage is tracked
in [docs/modules.md](docs/modules.md).

## Status

Under active development. No tagged releases yet; module APIs may
change. Pin to a commit SHA if you depend on this repo.

The three CI badges above show, in order:

- **sim** — `make sim` (GHDL testbenches) on the latest commit to `main`.
- **formal** — `make formal` (SymbiYosys proofs) on the latest commit to `main`.
- **style** — SPDX-header presence and markdown link checks.

A red badge on `main` is a release-blocker. For per-module verification
status (formal proof, testbench, both, or neither), see the coverage
matrix in [docs/modules.md](docs/modules.md#verification-coverage-matrix).

## Repository layout

- `src/`           — synthesisable VHDL (the "LEGO bricks")
- `sim/`           — GHDL testbenches and bus-functional models
- `formal/`        — SymbiYosys `.sby` configs and PSL properties
- `Makefile`       — top-level driver for `make sim`, `make formal`, and `make src`
- `docs/interfaces.md`  — interface specifications
- `docs/modules.md`     — per-module documentation
- `CODING_STYLE.md` — VHDL coding conventions used throughout
- `CONTRIBUTING.md` — how to add modules, testbenches, and proofs

## Tooling

- Simulation: **GHDL** (VHDL-2008).
- Formal: **SymbiYosys** with PSL properties via the yosys GHDL frontend.
- Top-level `Makefile` plus `sim/Makefile` and `formal/Makefile` drive both
  flows. From the repo root: `make sim`, `make formal`, `make src`.

## Interfaces

The modules use a small, consistent set of interfaces:

| Interface     | Prefix    | Spec reference                                       |
| ------------- | --------- | ---------------------------------------------------- |
| AXI streaming | `axis_*`  | AMBA AXI4-Stream                                     |
| AXI packet    | `axip_*`  | Custom AXI4-Stream profile (mandatory TLAST framing) |
| AXI Lite      | `axil_*`  | AMBA AXI4-Lite                                       |
| Wishbone      | `wbus_*`  | Wishbone B4                                          |
| Avalon-MM     | `avm_*`   | Intel Avalon Memory-Mapped                           |

The full handshake contract for each interface is in [docs/interfaces.md](docs/interfaces.md).

## Modules

Per-interface modules currently in the repo:

- **AXIS** (`src/axis/`): `axis_arbiter`,
  `axis_demux`, `axis_fifo`, `axis_fifo_async`,
  `axis_pipe`, `axis_pipe_async`, `axis_pipe_lite`
- **AXIP** (`src/axip/`): `axip_arbiter`, `axip_arbiter_general`,
  `axip_demux`, `axip_dropper`, `axip_fifo`, `axip_fifo_async`,
  `axip_insert_fixed_header`, `axip_remove_fixed_header`,
  `axip_pipe`
- **AXI-Lite** (`src/axil/`): `axil_arbiter`, `axil_arbiter_read`,
  `axil_arbiter_write`, `axil_fifo_async`, `axil_pipe`
- **Wishbone** (`src/wbus/`): `wbus_arbiter`, `wbus_arbiter_general`,
  `wbus_mapper`
- **Avalon-MM** (`src/avm/`): `avm_arbiter`, `avm_decrease`,
  `avm_increase`, `avm_pipe`, `avm_readahead`
- **Converters** (`src/converters/`): `axil_to_wbus`, `wbus_to_axil`,
  `axis_to_axip`, `axip_to_axis`

Packages `src/axip/axip_pkg.vhd` and `src/wbus/wbus_pkg.vhd` declare the
records used by the corresponding modules and must be in the compile
order before any `axip_*` / `wbus_*` entity is instantiated.

Details (generics, ports, reset, clocking, verification scope, limits)
are in [docs/modules.md](docs/modules.md).

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md) for the workflow and
[CODING_STYLE.md](CODING_STYLE.md) for the VHDL conventions. Bug
reports, feature proposals, and style issues each have a dedicated
template under `.github/ISSUE_TEMPLATE/`.

## License

MIT — see [LICENSE](LICENSE).

