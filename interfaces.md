# Interfaces

This document specifies the wire-level interfaces used by the modules in
this repository. All interfaces are point-to-point and directional: every
signal group has a single master (or sender) and a single slave (or
receiver). Multi-master and multi-slave topologies are built by
composing arbiters, distributors, and mappers from `src/`.

For each interface this document describes only the subset actually used
by the modules in this repository. Optional signals from the underlying
standards (e.g. `tid`/`tdest`/`tuser` for AXI4-Stream;
`awprot`/`awcache` for AXI4-Lite; `err`/`rty`/tag signals for
Wishbone; write-response signals for Avalon) are intentionally omitted.
Deviations from the parent standard are listed at the end of each
section.

The PSL property files under `../formal/` are the executable
specification of the handshake rules below; they should be treated as
authoritative if this prose ever drifts from the code.

---

## AXI streaming

AXI streaming (`axis`) is the simplest interface in the repository. It
transfers fixed-width data words from a master to a slave with handshake
flow control in both directions: a transfer happens only on cycles where
the master has data ready *and* the slave is ready to accept it. There
is no notion of packet boundary; for framed data use AXI packet
(see [#axi-packet](#axi-packet)).

### Signals

| Signal  | Direction      | Description                                                        |
| ------- | -------------- | ------------------------------------------------------------------ |
| `VALID` | Master → Slave | Master asserts when `DATA` is valid for the current cycle.         |
| `READY` | Slave  → Master| Slave asserts when it can accept a transfer in the current cycle.  |
| `DATA`  | Master → Slave | Payload, `G_DATA_SIZE` bits wide.                                  |

A handshake (transfer) occurs on every rising edge of `clk_i` where
`VALID` and `READY` are both asserted.

### Handshake rules

These rules are enforced by the formal properties under `../formal/`:

1. **Stability while waiting.** Once the master has asserted `VALID`, it
   must hold `VALID` asserted and keep `DATA` stable until the slave
   asserts `READY`.
2. **`READY` is free to toggle.** The slave may assert and deassert
   `READY` arbitrarily; in particular it may assert `READY` before the
   master asserts `VALID`.
3. **No combinational dependency of `VALID` on `READY`.** The master may
   not gate `VALID` with `READY`. This avoids combinational loops when
   modules are chained.
4. **Independent decision allowed.** The slave *may* decide its `READY`
   value based on `VALID` (e.g. an opportunistic FIFO). This is a
   one-way exception to rule 3.
5. **Reset.** While `rst_i` is asserted the master must drive
   `VALID = 0`. `READY` is don't-care during reset.

### Parameterisation

| Generic         | Meaning                | Typical value |
| --------------- | ---------------------- | ------------- |
| `G_DATA_SIZE`   | Bus width in bits.     | 8, 16, 32, 64 |

### Deviations from AMBA AXI4-Stream

- No `TLAST`, `TKEEP`, `TSTRB` (framing lives in `axip` instead;
  see [#axi-packet](#axi-packet)).
- No `TID`, `TDEST` (interface is strictly point-to-point).
- No `TUSER` sideband.

### Verification

- **Formal properties:** `../formal/axis_arbiter.psl`,
  `../formal/axis_arbiter_pair.psl`, `../formal/axis_dropper.psl`,
  `../formal/axis_fifo.psl`.
- **Bus-functional models:** `../sim/src/axis_master_sim.vhd`,
  `../sim/src/axis_slave_sim.vhd`, `../sim/src/axis_sim.vhd`
  (combined wrapper).
- **Back-pressure injection:** `../sim/src/axis_pause.vhd`.

---

## AXI packet

The AXI packet interface (`axip`) is used when data has a natural packet
structure — i.e. there is a beginning and an end to each transfer — or
when a logical data unit does not fit in a single clock cycle. It is a
strict **superset of AXI streaming** (see [#axi-streaming](#axi-streaming)):
the handshake rules are identical, and an `axip` source can drive an
`axis` sink that ignores the framing signals. It is *not* an ARM AMBA
standard; it is a project-local profile that fixes one specific framing
convention so that the modules in this repository can interoperate
without per-user configuration.

### Signals

| Signal  | Direction      | Description                                                                 |
| ------- | -------------- | --------------------------------------------------------------------------- |
| `VALID` | Master → Slave | Master asserts when `DATA`, `LAST`, and `BYTES` are valid.                  |
| `READY` | Slave  → Master| Slave asserts when it can accept a transfer in the current cycle.           |
| `DATA`  | Master → Slave | Payload, `8*N` bits wide, where `N` is the byte width set by `G_DATA_BYTES`. Byte ordering: **left-justified** (byte 0 occupies bits `[8*N-1 : 8*N-8]`). |
| `LAST`  | Master → Slave | Asserted on the final beat of a packet. Deasserted on all preceding beats.  |
| `BYTES` | Master → Slave | Number of valid bytes in the current beat, a natural in the range 0 to `G_DATA_BYTES`. On final beats (`LAST = 1`) only values 1..`G_DATA_BYTES` are valid (see framing rule 1). Ignored by the slave when `LAST = 0`. |

A handshake (transfer) occurs on every rising edge of `clk_i` where
`VALID` and `READY` are both asserted.

### Handshake rules

These rules are identical to AXI streaming and are enforced by the
formal properties under `../formal/`:

1. **Stability while waiting.** Once the master has asserted `VALID`, it
   must hold `VALID` asserted and keep `DATA`, `LAST`, and `BYTES`
   stable until the slave asserts `READY`.
2. **`READY` is free to toggle.** The slave may assert and deassert
   `READY` arbitrarily; in particular it may assert `READY` before the
   master asserts `VALID`.
3. **No combinational dependency of `VALID` on `READY`.** The master may
   not gate `VALID` with `READY`. This avoids combinational loops when
   modules are chained.
4. **Independent decision allowed.** The slave *may* decide its `READY`
   value based on `VALID` (e.g. an opportunistic FIFO). This is a
   one-way exception to rule 3.
5. **Reset.** While `rst_i` is asserted the master must drive
   `VALID = 0`. `READY` is don't-care during reset. All packet state
   inside both endpoints is cleared.

### Byte ordering (note vs. AMBA)

The `DATA` field is **left-justified**: the *first* byte of a packet is
in the *most significant* bits of `DATA`, the second byte in the next
8 bits, and so on. This is the **opposite** of the AMBA AXI4-Stream
convention, which places byte 0 in `tdata[7:0]`. Adapters must shuffle
bytes when interfacing to AMBA-compliant IP.

For an 8-byte (`N = 8`) bus:

```
bit: 63        56 55        48 47        40 ... 7         0
     | byte 0   | byte 1    | byte 2    | ... | byte 7   |
```

### Framing rules

1. **Packets are non-empty.** A packet consists of one or more beats. A
   beat with `LAST = 1` and `BYTES = 0` is **illegal**.
2. **Full beats before `LAST`.** On every beat with `LAST = 0`, *all*
   `N` bytes of `DATA` are valid. Partial-word framing is only
   permitted on the final beat, signalled by `BYTES`.
3. **Final beat.** On the beat with `LAST = 1`, exactly `BYTES` bytes
   are valid, occupying the most significant `8*BYTES` bits of `DATA`.
   The remaining `8*(N - BYTES)` bits are don't-care from the master
   and must be ignored by the slave.
4. **Packet ordering.** Beats of a packet must be presented in order,
   contiguously. There is no inter-packet idle requirement: the master
   may assert `VALID` for the first beat of packet *k+1* in the cycle
   immediately following the `LAST` handshake of packet *k*.
5. **Slave responsibility.** A compliant slave must not assume any
   minimum or maximum packet length; modules that need a bound (e.g.
   `axip_insert_fixed_header`) declare it via a generic.

### Relationship to AXI streaming

`axip` is `axis` plus two extra signals (`LAST`, `BYTES`). Consequently:

- An `axip` source can drive any `axis` sink that ignores framing —
  semantically the result is the byte stream obtained by concatenating
  the valid bytes of every packet.
- An `axis` source cannot generally drive an `axip` sink without
  framing, which is what `../src/converters/axis_to_axip.vhd` exists to
  provide. The reverse direction is `../src/converters/axip_to_axis.vhd`.
- The round-trip identity `axip_to_axis o axis_to_axip = id` is
  exercised by `../sim/tb_axip_axis_axip/`.

### Parameterisation

| Generic         | Meaning                              | Typical value |
| --------------- | ------------------------------------ | ------------- |
| `G_DATA_BYTES`  | Bus width in bytes, `N`.             | 1, 2, 4, 8    |

`BYTES` is declared as a natural in the range 0 to `G_DATA_BYTES`.

### Verification

- **Formal properties:** `../formal/axip_arbiter.psl`,
  `../formal/axip_insert_fixed_header.psl`,
  `../formal/axip_remove_fixed_header.psl`,
  `../formal/axip_to_axis.psl`, `../formal/axis_to_axip.psl`.
- **Bus-functional models:** `../sim/src/axip_master_sim.vhd`,
  `../sim/src/axip_slave_sim.vhd`, `../sim/src/axip_sim.vhd`
  (combined wrapper).
- **Back-pressure injection:** `../sim/src/axip_pause.vhd`.
- **Packet logger:** `../sim/src/axip_logger.vhd`.
- **Types/records:** `../src/axip/axip_pkg.vhd` — must be used by any
  code instantiating an `axip_*` entity.

---

## AXI Lite

The AXI Lite interface (`axil`) is a pipelined memory-mapped interface,
used extensively by AMD/Xilinx IP. It consists of five independent
channels — write address (`AW`), write data (`W`), write response (`B`),
read address (`AR`), and read data (`R`) — each carrying its own
`VALID`/`READY` handshake.

### Signals

| Signal     | Direction      | Description                                                |
| ---------- | -------------- | ---------------------------------------------------------- |
| `AWVALID`  | Master → Slave | Write address valid.                                       |
| `AWREADY`  | Slave  → Master| Write address accepted.                                    |
| `AWADDR`   | Master → Slave | Write address, `G_ADDR_SIZE` bits wide.                    |
| `WVALID`   | Master → Slave | Write data valid.                                          |
| `WREADY`   | Slave  → Master| Write data accepted.                                       |
| `WDATA`    | Master → Slave | Write data, `G_DATA_SIZE` bits wide.                       |
| `WSTRB`    | Master → Slave | Byte enables, `G_DATA_SIZE/8` bits wide. Bit *k* enables byte *k* of `WDATA`. |
| `BVALID`   | Slave  → Master| Write response valid.                                      |
| `BREADY`   | Master → Slave | Write response accepted.                                   |
| `BRESP`    | Slave  → Master| Write response code, 2 bits: `00`=OKAY, `10`=SLVERR.       |
| `ARVALID`  | Master → Slave | Read address valid.                                        |
| `ARREADY`  | Slave  → Master| Read address accepted.                                     |
| `ARADDR`   | Master → Slave | Read address, `G_ADDR_SIZE` bits wide.                     |
| `RVALID`   | Slave  → Master| Read data valid.                                           |
| `RREADY`   | Master → Slave | Read data accepted.                                        |
| `RDATA`    | Slave  → Master| Read data, `G_DATA_SIZE` bits wide.                        |
| `RRESP`    | Slave  → Master| Read response code, 2 bits: `00`=OKAY, `10`=SLVERR.        |

Each channel handshakes independently using the same VALID/READY rules
as AXI streaming.

### Handshake rules (per channel)

1. **Stability while waiting.** Once a channel asserts its `xVALID`, it
   must hold `xVALID` asserted and keep all payload signals stable
   until the receiver asserts `xREADY`.
2. **`xREADY` is free to toggle.** The receiver may assert and deassert
   `xREADY` arbitrarily; in particular it may assert `xREADY` before
   the sender asserts `xVALID`.
3. **No combinational dependency of `xVALID` on `xREADY`.**
4. **Reset.** While `rst_i` is asserted all `xVALID` signals must be
   driven to `0`. All `xREADY` signals are don't-care during reset.

### Transaction ordering rules

1. **Write completion.** A write transaction is complete when the slave
   has handshaked on `AW`, on `W`, and then on `B` — in that order from
   the slave's perspective. The slave must not assert `BVALID` for a
   transaction until **both** the corresponding `AW` and `W` handshakes
   have occurred.
2. **`AW` / `W` independence.** The master may present `AW` and `W` in
   either order, or simultaneously. There is no required cycle
   relationship between the two; the slave must buffer as required.
3. **Read completion.** A read transaction is complete when the slave
   has handshaked on `AR` and then on `R`. The slave must not assert
   `RVALID` for a transaction until the corresponding `AR` has been
   accepted.
4. **In-order responses.** Responses on the `B` and `R` channels are
   returned in the same order as the corresponding requests were
   accepted on `AW` and `AR` respectively. (AXI Lite has no
   transaction IDs, so out-of-order completion would be ambiguous.)
5. **Read / write independence.** Read and write channels are otherwise
   fully independent and may progress concurrently.
6. **No combinational paths between channels.** Compliant slaves must
   not gate one channel's `xREADY` combinationally on another
   channel's `xVALID`, beyond what rule 1 implies.

### Response encoding

| `xRESP` | Meaning  | Notes                                              |
| ------- | -------- | -------------------------------------------------- |
| `00`    | `OKAY`   | Normal completion.                                 |
| `10`    | `SLVERR` | Slave-side error (decode miss, write-protect, …).  |

`EXOKAY` (`01`) and `DECERR` (`11`) are **not** generated by the slave
models in this repository; masters must, however, be
tolerant of any 2-bit value.

### Parameterisation

| Generic         | Meaning             | Typical value |
| --------------- | ------------------- | ------------- |
| `G_ADDR_SIZE`   | Address width.      | 12–32         |
| `G_DATA_SIZE`   | Data width.         | 32, 64        |

`WSTRB` width is derived: `G_DATA_SIZE / 8`.

### Deviations from AMBA AXI4-Lite

- No `AWPROT`, `ARPROT` (protection attributes).
- No `AWCACHE`, `ARCACHE`.
- No exclusive access (`EXOKAY` never asserted).
- Full AMBA AXI4-Lite address alignment rules apply unchanged.

### Verification

- **Formal properties:** `../formal/axil_to_wbus.psl`.
- **Bus-functional models:** `../sim/src/axil_master_sim.vhd`,
  `../sim/src/axil_slave_sim.vhd`, `../sim/src/axil_sim.vhd`
  (combined wrapper).
- **Back-pressure injection:** `../sim/src/axil_pause.vhd`.
- **Activity monitor:** `../sim/src/axil_busy.vhd`.

---

## Wishbone

The Wishbone interface (`wbus`) is a simple point-to-point memory-mapped
interface used by many open-source IP cores. The variant implemented
here is **Wishbone B4 pipelined** (identifiable by the presence of
`STALL`); the classic B3 handshake (`ACK`-only) is **not** supported.

The interface is single-clock and single-master / single-slave at the
wire level. Multi-master and multi-slave topologies are built by
composing `../src/wbus/wbus_arbiter.vhd`,
`../src/wbus/wbus_arbiter_general.vhd`, and
`../src/wbus/wbus_mapper.vhd`.

### Signals

| Signal  | Direction      | Description                                                                              |
| ------- | -------------- | ---------------------------------------------------------------------------------------- |
| `CYC`   | Master → Slave | Cycle in progress. Held asserted from the first request beat until the last response.    |
| `STB`   | Master → Slave | Request strobe. One handshake per cycle in which `STB & ~STALL` is observed.             |
| `STALL` | Slave  → Master| Back-pressure on the request channel. Meaningful only while `STB` is asserted.           |
| `ADDR`  | Master → Slave | Request address, `G_ADDR_SIZE` bits wide. Addressing is per byte.                        |
| `WE`    | Master → Slave | `1` = write request, `0` = read request.                                                 |
| `WRDAT` | Master → Slave | Write data, `G_DATA_SIZE` bits wide.                                                     |
| `SEL`   | Master → Slave | Byte-enable, `G_DATA_SIZE/8` bits wide. Bit *k* selects byte *k* of `WRDAT` (writes) or of the returned `RDDAT` (reads). Non-selected byte lanes are don't-care on the wire and must be ignored by the receiver. |
| `ACK`   | Slave  → Master| Response valid: one pulse per completed read or write.                                   |
| `RDDAT` | Slave  → Master| Read data, valid on cycles where `ACK = 1` and the matching request had `WE = 0`. Only the lanes selected by `SEL` of the matching request are guaranteed valid. |

A request handshake occurs on any rising edge of `clk_i` where
`CYC & STB & ~STALL` is true. A response handshake occurs on any rising
edge of `clk_i` where `CYC & ACK` is true.
Only a single outstanding request is required to be supported.

### Datasheet (per Wishbone B4 §1.4)

| Item                          | Value                                                    |
| ----------------------------- | -------------------------------------------------------- |
| Type of interface             | MASTER and SLAVE                                         |
| Wishbone version              | B4 (pipelined)                                           |
| Port size (data width)        | `G_DATA_SIZE` bits, default 32                           |
| Port granularity              | 8 bits                                                   |
| Maximum operand size          | `G_DATA_SIZE` bits                                       |
| Data transfer ordering        | Little-endian                                            |
| Data transfer sequencing      | Single read or single write per request beat             |
| Supported cycle types         | Single read, single write. Back-to-back single transfers are allowed (one outstanding request at a time). |
| Optional `ERR_O` / `ERR_I`    | **Not supported.** Errors are not signalled on this bus. |
| Optional `RTY_O` / `RTY_I`    | **Not supported.**                                       |
| Optional tag signals          | **None.**                                                |

### Handshake and ordering rules

1. **`CYC` envelopes the transaction.** `CYC` must be asserted no later
   than the cycle in which `STB` is first asserted, and must remain
   asserted until the cycle in which the final outstanding `ACK` is
   returned. The master must not deassert `CYC` while requests are
   in flight.
2. **`STB` requires `CYC`.** `STB` is only meaningful while `CYC` is
   asserted; the slave must ignore `STB` when `CYC = 0`.
3. **`STALL` requires `STB`.** `STALL` is only meaningful while `STB`
   is asserted; its value is don't-care otherwise.
4. **Request stability.** While `STB` is asserted and `STALL` is high
   (i.e. the master is being back-pressured), `ADDR`, `WE`, `SEL`, and
   (on writes) `WRDAT` must remain stable.
5. **Request acceptance.** A request beat is *accepted* on the cycle
   where `STB & ~STALL`. After acceptance the master is free to change
   `STB`, `ADDR`, `WE`, `SEL`, and `WRDAT` on the next cycle (typically
   to issue the next request, or to deassert `STB`).
6. **Response valid.** `ACK` is asserted by the slave for exactly one
   cycle per completed request, independently of `STB`. `RDDAT` is
   valid on that cycle for requests that had `WE = 0`; it is
   don't-care for write requests.
7. **In-order responses.** `ACK`s are returned to the master in the
   same order the corresponding requests were accepted.
8. **Single outstanding request.** The slave is not required to accept
   a new request before the previous response has been delivered. A
   master that needs portable behaviour must therefore not assume any
   pipelining beyond one in-flight request.
9. **Reset.** While `rst_i` is asserted the master must drive
   `CYC = 0`, `STB = 0`. The slave must drive `STALL = 0`, `ACK = 0`.
   All in-flight state is cleared; outstanding responses are *not*
   recovered after reset.

### Read latency

Read latency is variable and not fixed by the protocol. Because only a
single outstanding request is supported (rule 8), the master simply
waits for `ACK` before issuing the next request; back-to-back
throughput is therefore bounded by the slave's response latency. The
`../sim/src/wbus_master_sim.vhd` and `../sim/src/wbus_slave_sim.vhd`
BFMs accept generics controlling minimum/maximum random latency for
stress testing.

### Parameterisation

| Generic          | Meaning                                | Typical value |
| ---------------- | -------------------------------------- | ------------- |
| `G_ADDR_SIZE`    | Address width in bits, byte-addressed. | 16–32         |
| `G_DATA_SIZE`    | Data width in bits.                    | 32            |

`SEL` width is derived: `G_DATA_SIZE / 8`.

### Deviations from Wishbone B4

This implementation intentionally restricts the standard in the
following ways. Each restriction simplifies the modules and their
formal proofs; lift only after extending the proofs:

- No `ERR` / `RTY` (no error or retry response).
- No tag signals (`TGA_*`, `TGC_*`, `TGD_*`).
- No classic B3 single-cycle handshake; B4 pipelined only.
- No registered-feedback / burst cycle types (`CTI`, `BTE`).
- Single outstanding request only; B4 pipelining beyond that is not
  exploited, so back-to-back throughput is bounded by slave response
  latency.

### Relationship to AXI-Lite

For systems that mix Wishbone and AXI-Lite IP, two converters are
provided:

- `../src/converters/axil_to_wbus.vhd` — AXI-Lite master side,
  Wishbone slave side downstream.
- `../src/converters/wbus_to_axil.vhd` — Wishbone master side,
  AXI-Lite slave side downstream.

The round-trip identity `wbus_to_axil o axil_to_wbus = id` is exercised
by `../sim/tb_wbus_axil_wbus/`.

### Verification

- **Formal properties:** `../formal/wbus_arbiter.psl`,
  `../formal/axil_to_wbus.psl`.
- **Bus-functional models:** `../sim/src/wbus_master_sim.vhd`,
  `../sim/src/wbus_slave_sim.vhd`, `../sim/src/wbus_sim.vhd`
  (combined wrapper).
- **Back-pressure injection:** `../sim/src/wbus_pause.vhd`.
- **Types/records:** `../src/wbus/wbus_pkg.vhd` — must be used by
  any code instantiating a `wbus_*` entity.

---

## Avalon

The Avalon interface (`avm`) is the Intel **Avalon Memory-Mapped**
(Avalon-MM) interface, used extensively by Intel/Altera IP. It is a
single-master / single-slave, single-clock memory-mapped interface with
back-pressure on the request side (`WAITREQUEST`) and a decoupled,
variable-latency read response (`READDATAVALID`). Bursts are supported
for both reads and writes via `BURSTCOUNT`.

The Avalon Streaming (Avalon-ST) variant is **not** implemented; for
streaming use `axis` (see [#axi-streaming](#axi-streaming)).

### Signals

| Signal           | Direction      | Description                                                                                        |
| ---------------- | -------------- | -------------------------------------------------------------------------------------------------- |
| `WRITE`          | Master → Slave | Write request.                                                                                     |
| `READ`           | Master → Slave | Read request. `WRITE` and `READ` must never be asserted in the same cycle.                         |
| `ADDRESS`        | Master → Slave | Byte address, `G_ADDR_SIZE` bits wide. The low `log2(G_DATA_SIZE/8)` bits must be zero (naturally aligned). |
| `WRITEDATA`      | Master → Slave | Write data, `G_DATA_SIZE` bits wide.                                                               |
| `BYTEENABLE`     | Master → Slave | Per-byte enables for `WRITEDATA`, `G_DATA_SIZE/8` bits wide.                                       |
| `BURSTCOUNT`     | Master → Slave | Length of the burst in beats, `G_BURST_SIZE` bits wide. Value `1` denotes a single-beat transfer.  |
| `WAITREQUEST`    | Slave  → Master| Slave back-pressure on the request channel. While asserted, the request is *not* accepted.         |
| `READDATA`       | Slave  → Master| Read data, valid on cycles where `READDATAVALID = 1`.                                              |
| `READDATAVALID`  | Slave  → Master| Asserted by the slave for each beat of returned read data.                                         |

### Handshake rules

1. **Mutually exclusive requests.** `WRITE` and `READ` must never be
   asserted simultaneously.
2. **Request acceptance.** A request beat is *accepted* on the cycle
   where (`WRITE | READ`) `& ~WAITREQUEST` is true. Until the request
   is accepted, the master must hold `WRITE` / `READ`, `ADDRESS`,
   `BURSTCOUNT`, and — for writes — `WRITEDATA` and `BYTEENABLE`
   stable.
3. **`WAITREQUEST` is free to toggle.** The slave may assert and
   deassert `WAITREQUEST` arbitrarily; in particular it may be
   asserted in the same cycle the master first asserts `WRITE` or
   `READ`. Its value is don't-care when neither `WRITE` nor `READ` is
   asserted.
4. **No combinational dependency of `WRITE`/`READ` on `WAITREQUEST`.**
5. **`READDATAVALID` is independent of `WAITREQUEST`.** The slave may
   return read data while back-pressuring further requests.
6. **Reset.** While `rst_i` is asserted the master must drive
   `WRITE = 0` and `READ = 0`. The slave must drive
   `WAITREQUEST = 0` (so that no request is pending) and
   `READDATAVALID = 0`. All in-flight state is cleared.

### Burst rules

1. **Single-beat default.** A transfer with `BURSTCOUNT = 1` is a
   single-beat read or single-beat write.
2. **Write bursts.** When `BURSTCOUNT = M > 1` on a write, the master
   issues exactly `M` consecutive write beats. After the first beat is
   accepted, `WRITE` must remain asserted, and `WRITEDATA` /
   `BYTEENABLE` advance per beat. `ADDRESS` and `BURSTCOUNT` must
   remain stable for the duration of the burst. `WAITREQUEST` may be
   asserted between beats to back-pressure individual beats.
3. **Read bursts.** When `BURSTCOUNT = M > 1` on a read, the master
   issues a *single* request beat; the slave returns `M` consecutive
   beats of `READDATA` (each marked by `READDATAVALID`). `READ`,
   `ADDRESS`, and `BURSTCOUNT` need not be held after the request is
   accepted.
4. **Address increment.** Burst beats access consecutive addresses,
   incrementing by `G_DATA_SIZE/8` bytes per beat starting at
   `ADDRESS`. Address wrapping is not supported.
5. **In-order responses.** Read responses are returned in the order
   the requests were accepted.
6. **No overlap of read and write bursts.** The master must not issue
   a new request until the previous write burst has been fully
   transmitted (last beat accepted) or the previous read request has
   been accepted.

### Read latency

The slave's read latency is **variable**: an arbitrary number of cycles
may elapse between the acceptance of a read request and the first
`READDATAVALID`. Masters must therefore tag or count outstanding
requests if they need to associate read data with a particular request.
The `../sim/src/avm_master_sim.vhd` and `../sim/src/avm_slave_sim.vhd`
BFMs accept generics controlling minimum/maximum random latency for
stress testing.

### Write responses

This implementation supports **implicit write responses only**: there is
no `WRITERESPONSEVALID` or `RESPONSE` signal. A write is considered
complete on the cycle its (final) request beat is accepted. Write errors
are not signalled.

### Parameterisation

| Generic          | Meaning                  | Typical value |
| ---------------- | ------------------------ | ------------- |
| `G_ADDR_SIZE`    | Address width in bits.   | 16–32         |
| `G_DATA_SIZE`    | Data width in bits.      | 32, 64        |
| `G_BURST_SIZE`   | `BURSTCOUNT` width.      | 4–8           |

`BYTEENABLE` width is derived: `G_DATA_SIZE / 8`.

### Deviations from the Avalon-MM spec

- No `WRITERESPONSEVALID` / `RESPONSE` (implicit, no-error writes only).
- No `DEBUGACCESS`.
- No `LOCK` / `BEGINBURSTTRANSFER` (the simpler `WAITREQUEST`-gated
  per-beat handshake is used uniformly).
- Address is byte-addressed (the standard permits either; we pin byte
  addressing for consistency with the Wishbone profile).

### Verification

- **Formal properties:** `../formal/avm_arbit.psl`,
  `../formal/avm_increase.psl`, `../formal/avm_readahead.psl`.
- **Bus-functional models:** `../sim/src/avm_master_sim.vhd`,
  `../sim/src/avm_slave_sim.vhd`, `../sim/src/avm_sim.vhd`
  (combined wrapper).
- **Back-pressure injection:** `../sim/src/avm_pause.vhd`.

