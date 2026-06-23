# fpga_utilities

A collection of small, reusable VHDL-2008 building blocks for FPGA
development. The intent is to use these modules as "LEGO" bricks — drop
them into your design wherever needed.

All modules are exercised with [GHDL simulation testbenches](sim/) and
[SymbiYosys formal proofs](formal/).

**Status:** under active development. No tagged releases yet; module
APIs may change. Pin to a commit SHA if you depend on this repo.

## Repository layout

- `src/`      — synthesisable VHDL (the "LEGO bricks")
- `sim/`      — GHDL testbenches and bus-functional models
- `formal/`   — SymbiYosys `.sby` configs and PSL properties
- `interfaces.md` — interface specifications
- `modules.md`    — per-module documentation

## Tooling

- Simulation: **GHDL** (VHDL-2008).
- Formal: **SymbiYosys** with PSL properties via the yosys GHDL frontend.
- Top-level `Makefile` plus `sim/Makefile` and `formal/Makefile` drive both
  flows. From the repo root: `make sim`, `make formal`.

## Interfaces

The modules use a small, consistent set of interfaces:

| Interface     | Prefix    | Spec reference                                       |
| ------------- | --------- | ---------------------------------------------------- |
| AXI streaming | `axis_*`  | AMBA AXI4-Stream                                     |
| AXI packet    | `axip_*`  | Custom AXI4-Stream profile (mandatory TLAST framing) |
| AXI Lite      | `axil_*`  | AMBA AXI4-Lite                                       |
| Wishbone      | `wbus_*`  | Wishbone B4                                          |
| Avalon-MM     | `avm_*`   | Intel Avalon Memory-Mapped                           |

The full handshake contract for each interface is in [interfaces.md](interfaces.md).

## Modules

Per-interface modules currently include:

- **AXIS**: `axis_fifo`, `axis_arbiter`, `axis_arbiter_pair`,
  `axis_dropper`, `axis_to_axip`
- **AXIP**: `axip_arbiter`, `axip_insert_fixed_header`,
  `axip_remove_fixed_header`, `axip_to_axis`, `axip_pipe_async`
- **AXI-Lite ↔ Wishbone**: `axil_to_wbus`
- **Wishbone**: `wbus_arbiter`
- **Avalon-MM**: `avm_arbit`, `avm_increase`, `avm_readahead`

Details (generics, ports, reset, clocking, verification scope, limits)
are in [modules.md](modules.md).

## License

MIT — see [LICENSE](LICENSE).

