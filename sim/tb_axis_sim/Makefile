# Author:  Michael Jørgensen
#
# Description: Makefile for simulating the axi_wbus.vhd file.

# List of generic simulation files
SRC += $(SRC_DIR)/axis/axis_pkg.vhd
SRC += $(SIM_SRC_DIR)/lfsr.vhd
SRC += $(SIM_SRC_DIR)/random.vhd
SRC += $(SIM_SRC_DIR)/axis_master_sim.vhd
SRC += $(SIM_SRC_DIR)/axis_slave_sim.vhd
SRC += $(SIM_SRC_DIR)/axis_pause.vhd
SRC += $(SIM_SRC_DIR)/axis_sim.vhd

# List of test specific simulation files
SRC += tb_axis_sim.vhd

# Top level entity
DUT = axis_sim

# Test duration
STOP_TIME = 30us

# Test bench configuration
GENERIC += -gG_PAUSE_SIZE=3
GENERIC += -gG_RAM_DEPTH=8
GENERIC += -gG_RANDOM=true
GENERIC += -gG_FAST=true
GENERIC += -gG_CNT_SIZE=12
GENERIC += -gG_DATA_BYTES=3

# Don't stop on errors
#ASSERT_LEVEL = none

include ../Makefile.inc

