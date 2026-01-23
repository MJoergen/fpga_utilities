# Author:  Michael Jørgensen
#
# Description: Makefile for simulating the axi_wbus.vhd file.

# List of source files
SRC += $(SRC_DIR)/axis/axis_fifo_sync.vhd

# List of test specific simulation files
SRC += tb_axis_fifo_sync.vhd

# List of generic simulation files
SRC += $(SIM_SRC_DIR)/axis_sim.vhd
SRC += $(SIM_SRC_DIR)/axis_master_sim.vhd
SRC += $(SIM_SRC_DIR)/axis_slave_sim.vhd
SRC += $(SIM_SRC_DIR)/lfsr.vhd
SRC += $(SIM_SRC_DIR)/random.vhd

# Top level entity
DUT = axis_fifo_sync

# Test duration
STOP_TIME = 20us

# Test bench configuration
GENERIC += -gG_RAM_DEPTH=8
GENERIC += -gG_RANDOM=true
GENERIC += -gG_FAST=true
GENERIC += -gG_CNT_SIZE=12
GENERIC += -gG_DATA_BYTES=3

# Don't stop on errors
#ASSERT_LEVEL = none

include ../Makefile.inc

