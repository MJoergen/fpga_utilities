# Author:  Michael Jørgensen
#
# Description: Makefile for simulating the axi_wbus.vhd file.

# List of source files
SRC += $(SRC_DIR)/axis/axis_pkg.vhd
SRC += $(SRC_DIR)/axip/axip_pkg.vhd
SRC += $(SRC_DIR)/axis/axis_pipe_async.vhd
SRC += $(SRC_DIR)/axip/axip_pipe_async.vhd
SRC += $(SRC_DIR)/axip/axip_insert_fixed_header.vhd
SRC += $(SRC_DIR)/axip/axip_remove_fixed_header.vhd

# List of generic simulation files
SRC += $(SIM_SRC_DIR)/lfsr.vhd
SRC += $(SIM_SRC_DIR)/random.vhd
SRC += $(SIM_SRC_DIR)/axip_master_sim.vhd
SRC += $(SIM_SRC_DIR)/axip_slave_sim.vhd

# List of test specific simulation files
SRC += tb_axip_pipe_async.vhd

# Top level entity
DUT = axip_pipe_async

# Test duration
STOP_TIME = 100us

# Test bench configuration
GENERIC += -gG_DEBUG=false
GENERIC += -gG_PIPE_SIZE=4
GENERIC += -gG_RANDOM=true
GENERIC += -gG_FAST=true
GENERIC += -gG_CNT_SIZE=14
GENERIC += -gG_DATA_BYTES=3
GENERIC += -gG_RATIO=80
GENERIC += -gG_MIN_LENGTH=1
GENERIC += -gG_MAX_LENGTH=20

# Don't stop on errors
#ASSERT_LEVEL = none

include ../Makefile.inc

