# Author:  Michael Jørgensen
#
# Description: Makefile for simulating the axi_pipe_wide.vhd file.

# List of source files
SRC += $(SRC_DIR)/axip/axip_insert_fixed_header.vhd
SRC += $(SRC_DIR)/axip/axip_remove_fixed_header.vhd

# List of test specific simulation files
SRC += $(SIM_SRC_DIR)/axis_pause.vhd
SRC += $(SIM_SRC_DIR)/axip_pause.vhd
SRC += $(SIM_SRC_DIR)/axip_sim.vhd
SRC += $(SIM_SRC_DIR)/axip_master_sim.vhd
SRC += $(SIM_SRC_DIR)/axip_slave_sim.vhd
SRC += $(SIM_SRC_DIR)/lfsr.vhd
SRC += $(SIM_SRC_DIR)/random.vhd
SRC += tb_axip_fixed_header.vhd

# Top level entity
DUT = axip_fixed_header

# Test duration
STOP_TIME = 100us

# Test specific generics
GENERIC += -gG_PAUSE_SIZE=3
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

