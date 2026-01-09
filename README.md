# fpga_utilities

This repo contains a collection of building blocks for FPGA development:

The intention is to use these modules as "LEGO" bricks, i.e. to insert them in your design whereever needed.

These models are tested using [simulation testbenches](sim) and [formal verification](formal).

## Interfaces
The modules make use of a small consistent set of interfaces:

* AXI streaming
* AXI packet
* AXI Lite
* Wishbone

Each of these interfaces are described in more detail [here](interfaces.md).

## Modules

The are modules specific for each type of interface, including
* FIFO (synchronuous and asynchronous)
* pipelines (shallow FIFO)
* arbiters
* ... and more

Each of these modules are described in more detail [here](modules.md).

