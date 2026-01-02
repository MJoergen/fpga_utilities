# fpga_utilities

This repo contains a collection of building blocks for FPGA development:

The intention is to use these modules as "LEGO" bricks, i.e. to insert them in your design whereever needed.

These models are tested using [simulation testbenches](sim) and [formal verification](formal).

## Interfaces
The modules make use of a small consistent set of interfaces:

* AXI streaming
* AXI packet
* AXI Lite
* Wishbone memory map
* Avalon memory map

So, when are the different interfaces used? Below I'll give a brief summary of each interface.

### AXI streaming
The AXI streaming is the simplest, it provides a means of transferring blobs of data from one module to another in a
timely manner. I.e. data is only transferred when both (simultaneously) the sender has data to send AND the receiver is
ready to receive. In other words, this interface includes flow control in both directions. Signals used in this
interface are:

* "READY"
* "VALID"
* "DATA".

It is required that the sender, while waiting for the receiver, keeps "VALID" asserted and the "DATA" unchanged.

### AXI packet
AXI packet is used when data has a natural packet structure. i.e. when there is a beginning and an end to each packet.
Alternatively, this is used when the blob of data cannot be transferred in a single clock cycle.  Signals used in this
interface are:

* "READY"
* "VALID"
* "DATA"
* "BYTES"
* "LAST".

It is assumed that the data comes in byte-sized chunks. The "BYTES" field indicates the number of valid bytes in this
particular clock cycle. The "DATA" field is left-justifed, i.e. first byte in the data is in the 8 most significant bits
of the "DATA" field. Furthermore, when "LAST" is not asserted the "BYTES" field is ignored, and hence it is implicit
that all bytes in "DATA" are valid.

## Modules
* [axis\_fifo\_sync.vhd](src/axis_fifo_sync.vhd): This is a simple synchronuous AXI streaming FIFO (i.e. input and output have same clock).
* [axis\_arbiter.vhd](src/axis_arbiter.vhd): This arbitrates (merges) two AXI streaming interfaces into one.
* [axis\_distributor.vhd](src/axis_distributor.vhd): This distribues a single AXI streaming interface into too.
* [axis\_insert\_fixed\_header.vhd](src/axis_insert_fixed_header.vhd): This inserts a fixed-size header in front of an AXI packet.
* [axis\_remove\_fixed\_header.vhd](src/axis_remove_fixed_header.vhd): This removes a fixed-size header from the front of an AXI packet.

* [axip\_fifo\_sync.vhd](src/axip_fifo_sync.vhd): This is a simple synchronuous AXI packet FIFO (i.e. input and output have same clock).

