# Author:  Michael Jørgensen
#
# Description: Makefile for simulating the axi_pipe_wide.vhd file.

# List of source files
SRC += $(SRC_DIR)/axis_fifo_sync.vhd
SRC += $(SRC_DIR)/axip_remove_fixed_header.vhd

# List of test specific simulation files
SRC += $(SIM_SRC_DIR)/lfsr.vhd
SRC += $(SIM_SRC_DIR)/random.vhd
SRC += tb_axip_remove_fixed_header.vhd

# Top level entity
DUT = axip_remove_fixed_header

# Test duration
STOP_TIME = 100us

# Test specific generics
GENERIC += -gG_DEBUG=false
GENERIC += -gG_MAX_LENGTH=30
GENERIC += -gG_CNT_SIZE=14
GENERIC += -gG_FAST=true
GENERIC += -gG_RANDOM=true
GENERIC += -gG_DATA_BYTES=8
GENERIC += -gG_HEADER_BYTES=2

# Don't stop on errors
#ASSERT_LEVEL = none

include ../Makefile.inc

