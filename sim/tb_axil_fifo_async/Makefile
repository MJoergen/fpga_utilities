# Author:  Michael Jørgensen
#
# Description: Makefile for simulating the axil_fifo_async.vhd file.

# List of source files
SRC += $(SRC_DIR)/axis/axis_fifo_async.vhd
SRC += $(SRC_DIR)/axil/axil_fifo_async.vhd

# List of test specific simulation files
SRC += tb_axil_fifo_async.vhd

# List of generic simulation files
SRC += $(SIM_SRC_DIR)/axil_master_sim.vhd
SRC += $(SIM_SRC_DIR)/axil_pause.vhd
SRC += $(SIM_SRC_DIR)/axil_slave_sim.vhd
SRC += $(SIM_SRC_DIR)/axis_pause.vhd
SRC += $(SIM_SRC_DIR)/lfsr.vhd
SRC += $(SIM_SRC_DIR)/random.vhd

# Top level entity
DUT = axil_fifo_async

# Test duration
STOP_TIME = 200us

# Test bench configuration
GENERIC += -gG_DEBUG=false
GENERIC += -gG_RATIO=170
GENERIC += -gG_PAUSE_SIZE=2
GENERIC += -gG_RANDOM=true
GENERIC += -gG_FAST=true
GENERIC += -gG_WR_DEPTH=4
GENERIC += -gG_RD_DEPTH=4
GENERIC += -gG_ADDR_BITS=10
GENERIC += -gG_DATA_BITS=16

include ../Makefile.inc
