# fpga_utilities

This repo contains a collection of building blocks for FPGA development:

The intention is to use these modules as "LEGO" bricks, i.e. to insert them in your design whereever needed.

These models are tested using [simulation testbenches](sim) and [formal verification](formal).

## Interfaces
The modules make use of a small consistent set of interfaces:

* Uni-directional
    - AXI streaming
    - AXI packet
* Bi-directional (transation based)
    - AXI Lite
    - Wishbone
    - Avalon

So, when are the different interfaces used? Below I'll give a brief summary of each interface.

### AXI streaming
The AXI streaming is the simplest, it provides a means of transferring blobs of data from one module to another in a
timely manner. I.e. data is only transferred when both (simultaneously) the sender has data to send AND the receiver is
ready to receive. In other words, this interface includes flow control in both directions. Signals used in this
interface are:

* "READY"
* "VALID"
* "DATA".

It is required that the sender, while waiting for the receiver, keeps "VALID" asserted and the "DATA" unchanged. Note
that this interface is uni-directional.

### AXI packet
AXI packet is used when data has a natural packet structure. i.e. when there is a beginning and an end to each packet.
Alternatively, this is used when the blob of data cannot be transferred in a single clock cycle.  Signals used in this
interface are:

* "READY"
* "VALID"
* "DATA"
* "LAST"
* "BYTES".

It is assumed that the data comes in byte-sized chunks. The "BYTES" field indicates the number of valid bytes in this
particular clock cycle. The "DATA" field is left-justifed, i.e. first byte in the data is in the 8 most significant bits
of the "DATA" field. Furthermore, when "LAST" is not asserted the "BYTES" field is ignored, and hence it is implicit
that all bytes in "DATA" are valid. Note that this interface is uni-directional.

### AXI lite
Note that this interface is bi-directional.

This is used extensively by AMD IP blocks.

* "AWREADY"
* "AWVALID"
* "AWADDR"
* "WREADY"
* "WVALID"
* "WDATA"
* "WSTRB"
* "BREADY"
* "BVALID"
* "BRESP"
* "ARREADY"
* "ARVALID"
* "ARADDR"
* "RREADY"
* "RVALID"
* "RDATA"
* "RRESP"

### Wishbone

* "CYC"
* "STALL"
* "STB"
* "ADDR"
* "WE"
* "WRDAT"
* "ACK"
* "RDDAT"

Note that this interface is bi-directional.

### Avalon
Note that this interface is bi-directional.

## Modules

### AXI streaming

* [axis\_fifo\_sync.vhd](src/axis/axis_fifo_sync.vhd): This is a simple synchronuous AXI streaming FIFO (i.e. input and output have same clock).
* [axis\_arbiter.vhd](src/axis/axis_arbiter.vhd): This arbitrates (merges) two AXI streaming interfaces into one.
* [axis\_distributor.vhd](src/axis/axis_distributor.vhd): This distribues a single AXI streaming interface into too.
* [axis\_pipe.vhd](src/axis/axis_pipe.vhd): A small 2-stage FIFO for AXI streaming.
* [axis\_pipe\_lite.vhd](src/axis/axis_pipe_lite.vhd): A small 1-stage FIFO for AXI streaming.

### AXI packet

* [axip\_fifo\_sync.vhd](src/axip/axip_fifo_sync.vhd): This is a simple synchronuous AXI packet FIFO (i.e. input and output have same clock).
* [axip\_insert\_fixed\_header.vhd](src/axip/axip_insert_fixed_header.vhd): This inserts a fixed-size header in front of an AXI packet.
* [axip\_remove\_fixed\_header.vhd](src/axip/axip_remove_fixed_header.vhd): This removes a fixed-size header from the front of an AXI packet.
* [axip\_arbiter.vhd](src/axip/axip_arbiter.vhd): This arbitrates between two AXI packet masters.
* [axip\_arbiter\_general.vhd](src/axip/axip_arbiter_general.vhd): This arbitrates (merges) several AXI packet interfaces into one.
* [axip\_dropper.vhd](src/axip/axip_dropper.vhd): This drops selected packets from an AXI packet interface.

### AXI Lite

* [axil\_arbiter.vhd](src/axil/axil_arbiter.vhd): This arbitrates between two AXI lite masters.
* [axil\_pipe.vhd](src/axil/axil_pipe.vhd): A small 2-stage FIFO for AXI Lite.

### Wishbone

* [wbus\_arbiter.vhd](src/wbus/wbus_arbiter.vhd): This arbitrates (merges) two Wishbone interfaces into one.
* [wbus\_arbiter\_general.vhd](src/wbus/wbus_arbiter_general.vhd): This arbitrates (merges) several Wishbone interfaces into one.
* [wbus\_mapper.vhd](src/wbus/wbus_mapper.vhd): This distributes a single Wishbone master to several Wishbone slaves.

### Conversion between interfaces

* [axip\_to\_axis.vhd](src/converters/axip_to_axis.vhd): Convert from an AXI packet interface to an AXI streaming interface.
* [axis\_to\_axip.vhd](src/converters/axis_to_axip.vhd): Convert from an AXI streaming interface to an AXI packet interface.
* [axil\_to\_wbus.vhd](src/converters/axil_to_wbus.vhd): Convert from AXI lite to Wishbone.
* [wbus\_to\_axil.vhd](src/converters/wbus_to_axil.vhd): Convert from Wishbone to AXI lite.

### Simulation modules

* [axis\_pause.vhd](sim/src/axis_pause.vhd) : Inserts empty clock cycles in an AXI streaming interface
* [axis\_sim.vhd](sim/src/axis_sim.vhd) : Simulate an AXI streaming Master and Slave

* [axip\_logger.vhd](sim/src/axip_logger.vhd) : Makes a debug log of each packet
* [axip\_pause.vhd](sim/src/axip_pause.vhd) : Inserts empty clock cycles in an AXI packet interface
* [axip\_sim.vhd](sim/src/axip_sim.vhd) : Simulate an AXI packet Master and Slave

* [axil\_master\_sim.vhd](sim/src/axil_master_sim.vhd) : Simulate an AXI lite Master
* [axil\_pause.vhd](sim/src/axil_pause.vhd) : Inserts empty clock cycles in an AXI lite interface
* [axil\_sim.vhd](sim/src/axil_sim.vhd) : Simulate an AXI lite Master and Slave
* [axil\_slave\_sim.vhd](sim/src/axil_slave_sim.vhd) : Simulate an AXI lite Slave

