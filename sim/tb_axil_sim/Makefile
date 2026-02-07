# Author:  Michael Jørgensen
#
# Description: Makefile for simulating the axil_sim.vhd file.

SRC += $(SRC_DIR)/axis/axis_pkg.vhd
SRC += $(SRC_DIR)/axil/axil_pkg.vhd

# List of generic simulation files
SRC += $(SIM_SRC_DIR)/lfsr.vhd
SRC += $(SIM_SRC_DIR)/random.vhd
SRC += $(SIM_SRC_DIR)/axis_pause.vhd
SRC += $(SIM_SRC_DIR)/axil_master_sim.vhd
SRC += $(SIM_SRC_DIR)/axil_slave_sim.vhd
SRC += $(SIM_SRC_DIR)/axil_sim.vhd
SRC += $(SIM_SRC_DIR)/axil_pause.vhd

# List of test specific simulation files
SRC += tb_axil_sim.vhd

# Top level entity
DUT = axil_sim

# Test duration
STOP_TIME = 20us

# Test bench configuration
GENERIC += -gG_DEBUG=false
GENERIC += -gG_PAUSE_SIZE=3
GENERIC += -gG_RANDOM=true
GENERIC += -gG_FAST=true
GENERIC += -gG_ADDR_SIZE=8
GENERIC += -gG_DATA_SIZE=16

# Don't stop on errors
#ASSERT_LEVEL = none

include ../Makefile.inc

