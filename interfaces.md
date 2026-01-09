# Interfaces
In the following I'll give a summary of the different types of interfaces supported by
these utilities.

In all cases, the interfaces are point-to-point, and directional. This means there is
a Master and a Slave (or similarly, a Sender and a Receiver).

So, when are the different interfaces used? Below I'll give a summary of each interface.

## AXI streaming
The AXI streaming is the simplest, it provides a means of transferring blobs of data from
one module to another in a timely manner. I.e. data is only transferred when
simultaneously the sender has data to send AND the receiver is ready to receive. In other
words, this interface includes flow control in both directions. Signals used in this
interface are:

* "READY" : Slave to Master
* "VALID" : Master to Slave
* "DATA"  : Master to Slave

It is required that the sender, while waiting for the receiver, keeps "VALID" asserted and
the "DATA" unchanged.

## AXI packet
AXI packet is used when data has a natural packet structure. i.e. when there is a
beginning and an end to each packet.  Alternatively, this is used when the blob of data
cannot be transferred in a single clock cycle.  Signals used in this interface are:

* "READY" : Slave to Master
* "VALID" : Master to Slave
* "DATA"  : Master to Slave
* "LAST"  : Master to Slave
* "BYTES" : Master to Slave

It is assumed that the data comes in byte-sized chunks. The "BYTES" field indicates the
number of valid bytes in this particular clock cycle. The "DATA" field is left-justifed,
i.e. first byte in the data is in the 8 most significant bits of the "DATA" field.
Furthermore, when "LAST" is not asserted the "BYTES" field is ignored, and hence it is
implicit that all bytes in "DATA" are valid.
 
## AXI lite
This interface is used extensively by AMD IP blocks. It provides a pipelined memory
interface. It consists of five independent channels.

* "AWREADY" : Slave to Master
* "AWVALID" : Master to Slave
* "AWADDR"  : Master to Slave
* "WREADY"  : Slave to Master
* "WVALID"  : Master to Slave
* "WDATA"   : Master to Slave
* "WSTRB"   : Master to Slave
* "BREADY"  : Master to Slave
* "BVALID"  : Slave to Master
* "BRESP"   : Slave to Master
* "ARREADY" : Slave to Master
* "ARVALID" : Master to Slave
* "ARADDR"  : Master to Slave
* "RREADY"  : Master to Slave
* "RVALID"  : Slave to Master
* "RDATA"   : Slave to Master
* "RRESP"   : Slave to Master

## Wishbone
This interface is used by many Open Source projects. It provides a simpler memory
interface.

* "CYC"   : Master to Slave
* "STALL" : Slave to Master
* "STB"   : Master to Slave
* "ADDR"  : Master to Slave
* "WE"    : Master to Slave
* "WRDAT" : Master to Slave
* "ACK"   : Slave to Master
* "RDDAT" : Slave to Master

## Avalon
TBD

