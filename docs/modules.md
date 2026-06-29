# Modules

This document summarises the modules included in this repository.
Modules are grouped by interface (and a *Converters* section for
cross-interface bridges), then sorted alphabetically within each group.
Simulation-only modules are listed separately at the end.

Every entry links to its source under `src/` or `sim/src/`. Each module's
detailed verification status (formal proof, testbench, both, or neither)
is given in the coverage matrix below.

## Verification coverage matrix

The table below cross-references each RTL module in `src/` against the
formal proofs in [`../formal/`](../formal/) and the testbenches under
[`../sim/`](../sim/). Modules with neither a proof nor a dedicated
testbench are flagged as **unverified**.

| Module                       | Formal proof | Testbench |
| ---------------------------- | :----------: | :-------: |
| `avm_arbiter`                | ✓ | `tb_avm_arbiter` |
| `avm_decrease`               | – | `tb_avm_decrease` |
| `avm_increase`               | ✓ | `tb_avm_increase` |
| `avm_pipe`                   | – | `tb_avm_pipe` |
| `avm_readahead`              | ✓ | `tb_avm_readahead` |
| `axil_arbiter`               | – | `tb_axil_arbiter` |
| `axil_arbiter_read`          | – | covered indirectly via `tb_axil_arbiter` |
| `axil_arbiter_write`         | – | covered indirectly via `tb_axil_arbiter` |
| `axil_fifo_async`            | – | **unverified** |
| `axil_pipe`                  | – | `tb_axil_pipe` |
| `axip_arbiter`               | ✓ | `tb_axip_arbiter` |
| `axip_arbiter_general`       | – | **unverified** |
| `axip_demux`                 | – | **unverified** |
| `axip_dropper`               | ✓ | **no testbench** |
| `axip_fifo`                  | – | `tb_axip_fifo` |
| `axip_fifo_async`            | – | **unverified** |
| `axip_insert_fixed_header`   | ✓ | `tb_axip_insert_fixed_header`, `tb_axip_fixed_header` |
| `axip_pipe`                  | – | `tb_axip_pipe` |
| `axip_remove_fixed_header`   | ✓ | `tb_axip_remove_fixed_header`, `tb_axip_fixed_header` |
| `axis_arbiter`               | ✓ | `tb_axis_arbiter` |
| `axis_demux`                 | – | **unverified** |
| `axis_fifo`                  | ✓ | `tb_axis_fifo` |
| `axis_fifo_async`            | – | `tb_axis_fifo_async` |
| `axis_pipe`                  | – | `tb_axis_pipe` |
| `axis_pipe_async`            | – | `tb_axis_pipe_async` |
| `axis_pipe_lite`             | – | `tb_axis_pipe_lite` |
| `avm_to_wbus`                | – | `tb_avm_to_wbus` |
| `wbus_to_avm`                | – | `tb_wbus_to_avm` |
| `axil_to_wbus`               | ✓ | `tb_axil_to_wbus`, `tb_wbus_axil_wbus` |
| `axip_to_axis`               | ✓ | `tb_axip_axis_axip` |
| `axis_to_axip`               | ✓ | `tb_axip_axis_axip` |
| `wbus_to_axil`               | – | `tb_wbus_to_axil`, `tb_wbus_axil_wbus` |
| `wbus_arbiter`               | ✓ | `tb_wbus_arbiter` |
| `wbus_arbiter_general`       | – | **unverified** |
| `wbus_mapper`                | – | **unverified** |

Modules currently marked **unverified** should be considered
experimental; they may be removed or refactored without notice. Adding
testbenches and/or formal properties for these is tracked as an open
TODO.

## AXI streaming

Source: [`../src/axis/`](../src/axis/). All modules consume and produce
the `axis` interface specified in
[interfaces.md](interfaces.md#axi-streaming).

- [`axis_arbiter.vhd`](../src/axis/axis_arbiter.vhd): Round-robin
  arbiter that merges two AXIS sources onto a single
  downstream AXIS sink. Generic-parameterised data width; selection is
  packet-unaware (single-beat granularity).
- [`axis_demux.vhd`](../src/axis/axis_demux.vhd): Demultiplexes a
  single AXIS source onto two AXIS sinks, selected by an external
  control input. **Unverified — no testbench or formal proof.**
- [`axis_fifo.vhd`](../src/axis/axis_fifo.vhd): Synchronous AXIS FIFO
  (single clock for in and out). Depth is generic; storage uses
  inferred block RAM.
- [`axis_fifo_async.vhd`](../src/axis/axis_fifo_async.vhd): Full
  asynchronous AXIS FIFO for clock-domain crossing.
- [`axis_pipe.vhd`](../src/axis/axis_pipe.vhd): Two-stage AXIS pipeline
  register. Breaks combinational paths through both `VALID` and `READY`
  at the cost of one cycle of latency. Useful for timing closure.
- [`axis_pipe_async.vhd`](../src/axis/axis_pipe_async.vhd): Shallow
  asynchronous AXIS FIFO for clock-domain crossing.
- [`axis_pipe_lite.vhd`](../src/axis/axis_pipe_lite.vhd): Single-stage
  AXIS pipeline register. Breaks the combinational path through `VALID`
  but **not** through `READY` — choose `axis_pipe` if
  both directions need breaking.

## AXI packet

Source: [`../src/axip/`](../src/axip/). All modules consume and produce
the `axip` interface specified in
[interfaces.md](interfaces.md#axi-packet). Every entity uses
[`../src/axip/axip_pkg.vhd`](../src/axip/axip_pkg.vhd); add it to the
compile order before any `axip_*` instance.

- [`axip_arbiter.vhd`](../src/axip/axip_arbiter.vhd): Arbiter merging two
  AXIP sources onto a single AXIP sink. Packet-aware: once a packet
  starts, the arbiter holds the grant until the corresponding `LAST` to
  avoid interleaving beats from different packets.
- [`axip_arbiter_general.vhd`](../src/axip/axip_arbiter_general.vhd):
  N-input variant of `axip_arbiter`. The number of inputs is a generic.
  **Unverified — no testbench or formal proof.**
- [`axip_demux.vhd`](../src/axip/axip_demux.vhd): Demultiplexes
  a single AXIP source onto two AXIP sinks, selected at packet
  granularity by an external control input.
  **Unverified.**
- [`axip_dropper.vhd`](../src/axip/axip_dropper.vhd): Drops selected
  packets from an AXIP stream under control of an external `drop` input.
  Pass-through latency is one cycle when not dropping.
  Formally proved; no dedicated testbench yet.
- [`axip_fifo.vhd`](../src/axip/axip_fifo.vhd): Synchronous AXIP FIFO
  (single clock for in and out). Stores `DATA`, `LAST`, and `BYTES`.
  Depth is generic.
- [`axip_fifo_async.vhd`](../src/axip/axip_fifo_async.vhd): Asynchronous
  AXIP FIFO for clock-domain crossing. CDC notes as for
  `axis_fifo_async`. **Unverified.**
- [`axip_insert_fixed_header.vhd`](../src/axip/axip_insert_fixed_header.vhd):
  Prepends a fixed-size header (supplied via a per-packet
  input) to each packet on an AXIP stream. Header width
  is a generic; the source packet's framing is preserved on the output.
- [`axip_pipe.vhd`](../src/axip/axip_pipe.vhd): Two-stage AXIP pipeline
  register. Same timing-closure use case as `axis_pipe`.
- [`axip_pkg.vhd`](../src/axip/axip_pkg.vhd): Package defining the
  records, types, and helper functions used by every `axip_*` entity.
  Not an entity; required in the compile order.
- [`axip_remove_fixed_header.vhd`](../src/axip/axip_remove_fixed_header.vhd):
  Inverse of `axip_insert_fixed_header`: strips a fixed-size prefix
  from each packet. Round-trip with `axip_insert_fixed_header` is the
  identity for any packet at least as long as the header.

## AXI Lite

Source: [`../src/axil/`](../src/axil/). All modules consume and produce
the `axil` interface specified in
[interfaces.md](interfaces.md#axi-lite).

- [`axil_arbiter.vhd`](../src/axil/axil_arbiter.vhd): Arbiter merging
  two AXI-Lite masters onto a single AXI-Lite slave port. Internally
  instantiates `axil_arbiter_read` and `axil_arbiter_write`.
- [`axil_arbiter_read.vhd`](../src/axil/internal/axil_arbiter_read.vhd): Internal
  helper — read-channel arbitration only (`AR` / `R`). Typically
  instantiated via `axil_arbiter`.
- [`axil_arbiter_write.vhd`](../src/axil/internal/axil_arbiter_write.vhd):
  Internal helper — write-channel arbitration only (`AW` / `W` / `B`).
  Typically instantiated via `axil_arbiter`.
- [`axil_fifo_async.vhd`](../src/axil/axil_fifo_async.vhd): Asynchronous
  AXI-Lite FIFO for clock-domain crossing. Buffers all five channels
  independently. **Unverified.**
- [`axil_pipe.vhd`](../src/axil/axil_pipe.vhd): Two-stage AXI-Lite
  pipeline register on all five channels. Useful for timing closure.

## Wishbone

Source: [`../src/wbus/`](../src/wbus/). All modules consume and produce
the `wbus` interface specified in
[interfaces.md](interfaces.md#wishbone). Every entity uses
[`../src/wbus/wbus_pkg.vhd`](../src/wbus/wbus_pkg.vhd); add it to the
compile order before any `wbus_*` instance.

- [`wbus_arbiter.vhd`](../src/wbus/wbus_arbiter.vhd): Arbiter merging two
  Wishbone masters onto a single Wishbone slave port. Selection
  policy: round-robin.
- [`wbus_arbiter_general.vhd`](../src/wbus/wbus_arbiter_general.vhd):
  N-input variant of `wbus_arbiter`. **Unverified.**
- [`wbus_mapper.vhd`](../src/wbus/wbus_mapper.vhd): Address decoder
  distributing one Wishbone master onto several Wishbone slaves. The
  base/mask table is supplied via a generic.
  **Unverified.**
- [`wbus_pkg.vhd`](../src/wbus/wbus_pkg.vhd): Package defining the
  records, types, and helper functions used by every `wbus_*` entity.
  Not an entity; required in the compile order.

## Avalon-MM

Source: [`../src/avm/`](../src/avm/). All modules consume and produce
the `avm` interface specified in
[interfaces.md](interfaces.md#avalon).

- [`avm_arbiter.vhd`](../src/avm/avm_arbiter.vhd): Arbiter merging two
  Avalon-MM masters onto a single Avalon-MM slave port. Burst-aware:
  once a burst starts, the grant is held until the burst completes.
- [`avm_decrease.vhd`](../src/avm/avm_decrease.vhd): Data-width adapter
  that narrows an Avalon-MM bus (master side wider than slave side).
  Generic width ratio. **No formal proof.**
- [`avm_increase.vhd`](../src/avm/avm_increase.vhd): Data-width adapter
  that widens an Avalon-MM bus (master side narrower than slave side).
  Counterpart to `avm_decrease`.
- [`avm_pipe.vhd`](../src/avm/avm_pipe.vhd): Two-stage Avalon-MM
  pipeline register. Useful for timing closure. **No formal proof.**
- [`avm_readahead.vhd`](../src/avm/avm_readahead.vhd): Read-ahead buffer
  / small cache that speculatively issues read bursts to reduce
  round-trip latency on sequential read traffic. See the entity header
  for the prefetch policy and protocol assumptions.

## Converters

Source: [`../src/converters/`](../src/converters/). These bridge between
the interfaces specified in [interfaces.md](interfaces.md).

- [`avm_to_wbus.vhd`](../src/converters/avm_to_wbus.vhd): Avalon MM
  slave on the master side, Wishbone master on the slave side. Honours
  `BYTEENABLE` via Wishbone `SEL`.
- [`axil_to_wbus.vhd`](../src/converters/axil_to_wbus.vhd): AXI-Lite
  slave on the master side, Wishbone master on the slave side. Honours
  `WSTRB` via Wishbone `SEL`.
- [`axip_to_axis.vhd`](../src/converters/axip_to_axis.vhd): Converts an
  AXIP source to an AXIS sink by dropping the framing signals (`LAST`,
  `BYTES`). The output is the concatenated byte stream of all valid
  bytes; downstream loses packet boundaries.
- [`axis_to_axip.vhd`](../src/converters/axis_to_axip.vhd): Converts an
  AXIS source to an AXIP sink by inserting framing. The frame length is
  fixed by a generic.
- [`wbus_to_avm.vhd`](../src/converters/wbus_to_avm.vhd): Wishbone
  slave on the master side, Avalon MM master on the slave side.
- [`wbus_to_axil.vhd`](../src/converters/wbus_to_axil.vhd): Wishbone
  slave on the master side, AXI-Lite master on the slave side.

The round-trip identities `axip_to_axis ∘ axis_to_axip = id` and
`wbus_to_axil ∘ axil_to_wbus = id` are exercised by
[`../sim/tb_axip_axis_axip/`](../sim/tb_axip_axis_axip/) and
[`../sim/tb_wbus_axil_wbus/`](../sim/tb_wbus_axil_wbus/) respectively.

## Simulation modules

Source: [`../sim/src/`](../sim/src/). These entities are intended for
testbenches only; they are not synthesisable. Every interface ships the
same four-piece BFM family:

- **`*_master_sim`** — actively drives the interface as a master.
- **`*_slave_sim`** — actively responds as a slave.
- **`*_sim`** — convenience wrapper that instantiates both sides of the
  bus for back-to-back regression tests.
- **`*_pause`** — back-pressure injector inserted in series with the
  bus; randomises stall patterns for stress testing.

### AXIS

- [`axis_master_sim.vhd`](../sim/src/axis_master_sim.vhd): Simulates an
  AXIS master driving a configurable traffic pattern.
- [`axis_slave_sim.vhd`](../sim/src/axis_slave_sim.vhd): Simulates an
  AXIS slave with configurable back-pressure.
- [`axis_sim.vhd`](../sim/src/axis_sim.vhd): Combined master + slave
  wrapper.
- [`axis_pause.vhd`](../sim/src/axis_pause.vhd): Inserts pseudo-random
  pauses (deasserts `VALID` / `READY`) on an AXIS link.

### AXIP

- [`axip_master_sim.vhd`](../sim/src/axip_master_sim.vhd): Simulates an
  AXIP master, including framing (`LAST`, `BYTES`).
- [`axip_slave_sim.vhd`](../sim/src/axip_slave_sim.vhd): Simulates an
  AXIP slave with configurable back-pressure.
- [`axip_sim.vhd`](../sim/src/axip_sim.vhd): Combined master + slave
  wrapper.
- [`axip_pause.vhd`](../sim/src/axip_pause.vhd): Inserts pseudo-random
  pauses on an AXIP link.
- [`axip_logger.vhd`](../sim/src/axip_logger.vhd): Logs each AXIP packet
  to the simulation transcript for debugging.

### AXI Lite

- [`axil_master_sim.vhd`](../sim/src/axil_master_sim.vhd): Simulates an
  AXI-Lite master issuing configurable read/write transactions.
- [`axil_slave_sim.vhd`](../sim/src/axil_slave_sim.vhd): Simulates an
  AXI-Lite slave with a memory backing store.
- [`axil_sim.vhd`](../sim/src/axil_sim.vhd): Combined master + slave
  wrapper.
- [`axil_pause.vhd`](../sim/src/axil_pause.vhd): Inserts pseudo-random
  pauses on AXI-Lite channels.
- [`axil_busy.vhd`](../sim/src/axil_busy.vhd): Activity monitor that
  asserts a flag whenever we are waiting for one of AW or W channels.

### Wishbone

- [`wbus_master_sim.vhd`](../sim/src/wbus_master_sim.vhd): Simulates a
  Wishbone master.
- [`wbus_slave_sim.vhd`](../sim/src/wbus_slave_sim.vhd): Simulates a
  Wishbone slave with a memory backing store and configurable response
  latency.
- [`wbus_sim.vhd`](../sim/src/wbus_sim.vhd): Combined master + slave
  wrapper.
- [`wbus_pause.vhd`](../sim/src/wbus_pause.vhd): Inserts pseudo-random
  pauses on a Wishbone link.

### Avalon-MM

- [`avm_master_sim.vhd`](../sim/src/avm_master_sim.vhd): Simulates an
  Avalon-MM master, including burst transactions.
- [`avm_slave_sim.vhd`](../sim/src/avm_slave_sim.vhd): Simulates an
  Avalon-MM slave with a memory backing store and configurable read
  latency.
- [`avm_sim.vhd`](../sim/src/avm_sim.vhd): Combined master + slave
  wrapper.
- [`avm_pause.vhd`](../sim/src/avm_pause.vhd): Inserts pseudo-random
  pauses on an Avalon-MM link.

### Verification helpers

These are not interface-specific; they are reused across testbenches.

- [`lfsr.vhd`](../sim/src/lfsr.vhd): Maximal-length linear-feedback
  shift register, used as a pseudo-random source by other helpers.
  Polynomial width is a generic.
- [`random.vhd`](../sim/src/random.vhd): Pseudo-random number generator
  with seedable initialisation; wraps `lfsr`. Use a fixed
  seed in regressions for reproducibility.

