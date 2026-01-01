# fpga_utilities

This repo contains a collection of building blocks for FPGA development:

The intention is to use these modules as "LEGO" bricks, i.e. to insert them in your design whereever needed.

These models are tested using [simulation testbenches](sim) and [formal verification](formal).

## Interfaces
The modules make use of a small consistent set of interfaces:

* AXI streaming
* AXI streaming, packet oriented.
* AXI Lite
* Wishbone memory map
* Avalon memory map

So, when are the different interfaces used? The AXI streaming is the simplest, it provides a means of transferring
blobs of data from one module to another in a timely manner. I.e. data is only transferred when both (simultaneously)
the sender has data to send AND the receiver is ready to receive. In other words, this interface includes flow control
in both directions. Signals used in this interface is "READY", "VALID", and "DATA". It is required that the sender,
while waiting for the receiver, keeps "VALID" asserted and the "DATA" unchanged.

AXI streaming, packet oriented, is used when data has a natural packet structure. i.e. when there is a beginning and an
end to each packet. Alternatively, this is used when the blob of data cannot be transferred in a single clock cycle.
Signals used in this interface are "READY", "VALID", "DATA", "BYTES", and "LAST". It is assumed that the data comes in
byte-sized chunks. The "BYTES" field indicates the number of valid bytes in this particular clock cycle. The "DATA"
field is left-justifed, i.e. first byte in the data is in the 8 most significant bits of the "DATA" field. Furthermore,
when "LAST" is not asserted the "BYTES" field is ignored, and hence it is implicit that all bytes in "DATA" are valid.


## Modules
* [axis\_fifo\_sync.vhd](axis_fifo_sync.vhd)
This is a simple synchronuous FIFO (i.e. input and output have same clock).


