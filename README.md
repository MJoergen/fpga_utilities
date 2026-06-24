# fpga_utilities

A collection of small, reusable VHDL-2008 building blocks for FPGA
development. The intent is to use these modules as "LEGO" bricks — drop
them into your design wherever needed.

Most modules are exercised by [GHDL simulation testbenches](sim/) under
`sim/tb_*/`, and a subset additionally has
[SymbiYosys formal proofs](formal/). The per-module coverage is tracked
in [modules.md](modules.md).

**Status:** under active development. No tagged releases yet; module
APIs may change. Pin to a commit SHA if you depend on this repo.

## Repository layout

- `src/`           — synthesisable VHDL (the "LEGO bricks")
- `sim/`           — GHDL testbenches and bus-functional models
- `formal/`        — SymbiYosys `.sby` configs and PSL properties
- `Makefile`       — top-level driver for `make sim` / `make formal`
- `interfaces.md`  — interface specifications
- `modules.md`     — per-module documentation

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

Per-interface modules currently in the repo:

- **AXIS** (`src/axis/`): `axis_arbiter`,
  `axis_distributor`, `axis_dropper`, `axis_fifo`, `axis_fifo_async`,
  `axis_pipe`, `axis_pipe_async`, `axis_pipe_lite`
- **AXIP** (`src/axip/`): `axip_arbiter`, `axip_arbiter_general`,
  `axip_distributor`, `axip_fifo`, `axip_fifo_async`,
  `axip_insert_fixed_header`, `axip_remove_fixed_header`,
  `axip_pipe`, `axip_pipe_async`
- **AXI-Lite** (`src/axil/`): `axil_arbiter`, `axil_arbiter_read`,
  `axil_arbiter_write`, `axil_fifo_async`, `axil_pipe`,
  `axil_pipe_async`
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
are in [modules.md](modules.md).

## License

MIT — see [LICENSE](LICENSE).

