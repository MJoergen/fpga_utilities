# Modules

In the following I'll give a summary of the different modules included in
these utilities.

The modules are sorted according to interface type, and then sorted alphabetically.

## AXI streaming

* [axis\_arbiter.vhd](src/axis/axis_arbiter.vhd): This arbitrates (merges) two AXI
  streaming interfaces into one.
* [axis\_distributor.vhd](src/axis/axis_distributor.vhd): This distribues a single AXI
  streaming interface into two.
* [axis\_fifo\_sync.vhd](src/axis/axis_fifo_sync.vhd): This is a simple synchronuous AXI
  streaming FIFO (i.e. input and output have same clock).
* [axis\_pipe\_lite.vhd](src/axis/axis_pipe_lite.vhd): A small 1-stage FIFO for AXI
  streaming. This can be useful for adding registers to an AXI streaming pipeline for
  helping to achieve timing closure.
* [axis\_pipe.vhd](src/axis/axis_pipe.vhd): A small 2-stage FIFO for AXI streaming. This
  can be useful for adding registers to an AXI streaming pipeline for helping to achieve
  timing closure.

## AXI packet

* [axip\_fifo\_sync.vhd](src/axip/axip_fifo_sync.vhd): This is a simple synchronuous AXI
  packet FIFO (i.e. input and output have same clock).
* [axip\_insert\_fixed\_header.vhd](src/axip/axip_insert_fixed_header.vhd): This inserts a
  fixed-size header in front of an AXI packet.
* [axip\_remove\_fixed\_header.vhd](src/axip/axip_remove_fixed_header.vhd): This removes a
  fixed-size header from the front of an AXI packet.
* [axip\_arbiter.vhd](src/axip/axip_arbiter.vhd): This arbitrates between two AXI packet
  masters.
* [axip\_arbiter\_general.vhd](src/axip/axip_arbiter_general.vhd): This arbitrates
  (merges) several AXI packet interfaces into one.
* [axip\_dropper.vhd](src/axip/axip_dropper.vhd): This drops selected packets from an AXI
  packet interface.

## AXI Lite

* [axil\_arbiter.vhd](src/axil/axil_arbiter.vhd): This arbitrates between two AXI lite
  masters.
* [axil\_pipe.vhd](src/axil/axil_pipe.vhd): A small 2-stage FIFO for AXI Lite.

## Wishbone

* [wbus\_arbiter.vhd](src/wbus/wbus_arbiter.vhd): This arbitrates (merges) two Wishbone
  interfaces into one.
* [wbus\_arbiter\_general.vhd](src/wbus/wbus_arbiter_general.vhd): This arbitrates
  (merges) several Wishbone interfaces into one.
* [wbus\_mapper.vhd](src/wbus/wbus_mapper.vhd): This distributes a single Wishbone master
  to several Wishbone slaves.

## Avalon

* [avm\_pipe.vhd](src/avm/avm_pipe.vhd): A small 2-stage FIFO for Avalon.
* [avm\_arbit.vhd](src/avm/avm_arbit.vhd): This arbitrates between two Avalon masters.

## Conversion between interfaces

* [axip\_to\_axis.vhd](src/converters/axip_to_axis.vhd): Convert from an AXI packet
  interface to an AXI streaming interface.
* [axis\_to\_axip.vhd](src/converters/axis_to_axip.vhd): Convert from an AXI streaming
  interface to an AXI packet interface.
* [axil\_to\_wbus.vhd](src/converters/axil_to_wbus.vhd): Convert from AXI lite to
  Wishbone.
* [wbus\_to\_axil.vhd](src/converters/wbus_to_axil.vhd): Convert from Wishbone to AXI
  lite.

## Simulation modules

* [axis\_pause.vhd](sim/src/axis_pause.vhd) : Inserts empty clock cycles in an AXI
  streaming interface
* [axis\_sim.vhd](sim/src/axis_sim.vhd) : Simulate an AXI streaming Master and Slave
* [axip\_logger.vhd](sim/src/axip_logger.vhd) : Makes a debug log of each packet
* [axip\_pause.vhd](sim/src/axip_pause.vhd) : Inserts empty clock cycles in an AXI packet
  interface
* [axip\_sim.vhd](sim/src/axip_sim.vhd) : Simulate an AXI packet Master and Slave
* [axil\_master\_sim.vhd](sim/src/axil_master_sim.vhd) : Simulate an AXI lite Master
* [axil\_pause.vhd](sim/src/axil_pause.vhd) : Inserts empty clock cycles in an AXI lite
  interface
* [axil\_sim.vhd](sim/src/axil_sim.vhd) : Simulate an AXI lite Master and Slave
* [axil\_slave\_sim.vhd](sim/src/axil_slave_sim.vhd) : Simulate an AXI lite Slave
* [avm\_sim.vhd](sim/src/avm_sim.vhd) : Simulate an Avalon Master and Slave
* [wbus\_sim.vhd](sim/src/wbus_sim.vhd) : Simulate a Wishbone Master and Slave

