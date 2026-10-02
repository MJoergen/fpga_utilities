# Author:  Michael Jørgensen
#
# Description: Makefile for simulating the axip_fifo_async.vhd file.

# List of source files
SRC += $(SRC_DIR)/axis/axis_fifo_async.vhd
SRC += $(SRC_DIR)/axip/axip_fifo_async.vhd

# List of test specific simulation files
SRC += tb_axip_fifo_async.vhd

# List of generic simulation files
SRC += $(SIM_SRC_DIR)/axip_master_sim.vhd
SRC += $(SIM_SRC_DIR)/axip_slave_sim.vhd
SRC += $(SIM_SRC_DIR)/lfsr.vhd
SRC += $(SIM_SRC_DIR)/random.vhd

# Top level entity
DUT = axip_fifo_async

# Test duration
STOP_TIME = 100us

# Test bench configuration
GENERIC += -gG_DEBUG=false
GENERIC += -gG_RATIO=170
GENERIC += -gG_RANDOM=true
GENERIC += -gG_FAST=true
GENERIC += -gG_MIN_LENGTH=1
GENERIC += -gG_MAX_LENGTH=20
GENERIC += -gG_CNT_SIZE=12
GENERIC += -gG_ADDR_BITS=3
GENERIC += -gG_DATA_BYTES=3

include ../Makefile.inc
