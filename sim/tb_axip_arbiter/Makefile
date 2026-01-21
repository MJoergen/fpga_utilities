# Author:  Michael Jørgensen
#
# Description: Makefile for simulating the axip_arbiter.vhd file.

# List of source files
SRC += $(SRC_DIR)/axip/axip_arbiter.vhd
SRC += $(SRC_DIR)/axip/axip_distributor.vhd
SRC += $(SRC_DIR)/axip/axip_insert_fixed_header.vhd
SRC += $(SRC_DIR)/axip/axip_remove_fixed_header.vhd
SRC += $(SRC_DIR)/axis/axis_fifo_sync.vhd

# List of test specific simulation files
SRC += tb_axip_arbiter.vhd

# List of generic simulation files
SRC += $(SIM_SRC_DIR)/lfsr.vhd
SRC += $(SIM_SRC_DIR)/random.vhd
SRC += $(SIM_SRC_DIR)/axip_sim.vhd

# Top level entity
DUT = axip_arbiter

# Test duration
STOP_TIME = 100us

# Test bench configuration
GENERIC += -gG_RANDOM=true
GENERIC += -gG_DEBUG=false
GENERIC += -gG_MIN_LENGTH=1
GENERIC += -gG_MAX_LENGTH=10
GENERIC += -gG_FAST=true
GENERIC += -gG_CNT_SIZE=13
GENERIC += -gG_DATA_BYTES=4

# Don't stop on errors
ASSERT_LEVEL = none

include ../Makefile.inc

