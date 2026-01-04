# Author:  Michael Jørgensen
#
# Description: Makefile for simulating the axip_to_axis.vhd and axis_to_axip.vhd files.

# List of source files
SRC += $(SRC_DIR)/axis_fifo_sync.vhd
SRC += $(SRC_DIR)/axis_to_axip.vhd
SRC += $(SRC_DIR)/axip_to_axis.vhd

# List of test specific simulation files
SRC += tb_axip_axis_axip.vhd

# List of generic simulation files
SRC += $(SIM_SRC_DIR)/axip_sim.vhd
SRC += $(SIM_SRC_DIR)/axis_sim.vhd
SRC += $(SIM_SRC_DIR)/axis_pause.vhd
SRC += $(SIM_SRC_DIR)/lfsr.vhd
SRC += $(SIM_SRC_DIR)/random.vhd

# Top level entity
DUT = axip_axis_axip

# Test duration
STOP_TIME = 80us

# Test bench configuration
GENERIC += -gG_PAUSE_SIZE=3
GENERIC += -gG_RAM_DEPTH=8
GENERIC += -gG_DEBUG=false
GENERIC += -gG_RANDOM=true
GENERIC += -gG_FAST=true
GENERIC += -gG_MIN_LENGTH=1
GENERIC += -gG_MAX_LENGTH=20
GENERIC += -gG_CNT_SIZE=12
GENERIC += -gG_DATA_BYTES=3

# Don't stop on errors
#ASSERT_LEVEL = none

include ../Makefile.inc

