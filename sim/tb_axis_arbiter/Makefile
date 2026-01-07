# Author:  Michael Jørgensen
#
# Description: Makefile for simulating the wbus_arbiter.vhd file.

# List of source files
SRC += $(SRC_DIR)/axis/axis_arbiter.vhd
SRC += $(SRC_DIR)/axis/axis_distributor.vhd

# List of test specific simulation files
SRC += tb_axis_arbiter.vhd

# List of generic simulation files
SRC += $(SIM_SRC_DIR)/lfsr.vhd
SRC += $(SIM_SRC_DIR)/random.vhd
SRC += $(SIM_SRC_DIR)/axis_sim.vhd

# Top level entity
DUT = axis_arbiter

# Test duration
STOP_TIME = 30us

# Test bench configuration
GENERIC += -gG_RANDOM=true
GENERIC += -gG_FAST=true
GENERIC += -gG_CNT_SIZE=12
GENERIC += -gG_DATA_BYTES=4

# Don't stop on errors
ASSERT_LEVEL = none

include ../Makefile.inc

