# fpga_utilities

This repo contains a collection of building blocks for FPGA development:

The intention is to use these modules as "LEGO" bricks, i.e. to insert them in your design wherever needed.

These modules are tested using [simulation testbenches](https://github.com/MJoergen/fpga_utilities/tree/main/sim) and [formal verification](https://github.com/MJoergen/fpga_utilities/tree/main/formal).

This uses modern VHDL-2008 and uses GHDL as a simulator.

Currently under development.

## Interfaces
The modules make use of a small consistent set of interfaces:

| Interface | Prefix used in file/entity names | Spec reference |
| --------- | -------------------------------- | -------------- |
| AXI streaming | axis_* | AMBA AXI4-Stream |
| AXI packet    | axip_* | AXI streaming with packet boundaries / TLAST framing |
| AXI Lite      | axil_* | AMBA AXI4-Lite   |
| Wishbone      | wb_*   | Wishbone B4 / B3 |

Each of these interfaces are described in more detail in
[interfaces.md](https://github.com/MJoergen/fpga_utilities/tree/main/interfaces.md).

## Modules

There are modules specific for each type of interface, including
* FIFO (synchronous and asynchronous)
* pipelines (shallow FIFO)
* arbiters
* ... and more

Each of these modules are described in more detail in
[modules.md](https://github.com/MJoergen/fpga_utilities/tree/main/modules.md).

