# Author:  Michael Jørgensen
#
# Description: Makefile for simulating the axi_wbus.vhd file.

# List of source files
SRC += $(SRC_DIR)/axis/axis_fifo.vhd
SRC += $(SRC_DIR)/axis/axis_decrease.vhd
SRC += $(SRC_DIR)/axis/axis_increase.vhd

# List of test specific simulation files
SRC += tb_axis_decrease_increase.vhd

# List of generic simulation files
SRC += $(SIM_SRC_DIR)/axis_sim.vhd
SRC += $(SIM_SRC_DIR)/axis_master_sim.vhd
SRC += $(SIM_SRC_DIR)/axis_slave_sim.vhd
SRC += $(SIM_SRC_DIR)/lfsr.vhd
SRC += $(SIM_SRC_DIR)/random.vhd

# Top level entity
DUT = axis_decrease_increase

# Test duration
STOP_TIME = 80us

# Test bench configuration
GENERIC += -gG_RANDOM=true
GENERIC += -gG_FAST=true
GENERIC += -gG_DATA_BITS_LARGE=12
GENERIC += -gG_DATA_BITS_SMALL=8

# Don't stop on errors
#ASSERT_LEVEL = none

include ../Makefile.inc

