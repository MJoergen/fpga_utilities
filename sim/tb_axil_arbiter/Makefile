# Author:  Michael Jørgensen
#
# Description: Makefile for simulating the axil_sim.vhd file.

SRC += $(SRC_DIR)/axil_arbiter.vhd
SRC += $(SRC_DIR)/axis_arbiter.vhd
SRC += $(SRC_DIR)/axis_arbiter_pair.vhd
SRC += $(SRC_DIR)/axis_distributor.vhd

# List of test specific simulation files
SRC += tb_axil_arbiter.vhd

# List of generic simulation files
SRC += $(SIM_SRC_DIR)/axil_master_sim.vhd
SRC += $(SIM_SRC_DIR)/axil_slave_sim.vhd
SRC += $(SIM_SRC_DIR)/axil_busy.vhd
SRC += $(SIM_SRC_DIR)/axil_pause.vhd
SRC += $(SIM_SRC_DIR)/axis_pause.vhd
SRC += $(SIM_SRC_DIR)/lfsr.vhd
SRC += $(SIM_SRC_DIR)/random.vhd

# Top level entity
DUT = axil_arbiter

# Test duration
STOP_TIME = 100us

# Test bench configuration
GENERIC += -gG_DEBUG=false
GENERIC += -gG_PAUSE_SIZE=2
GENERIC += -gG_RANDOM=true
GENERIC += -gG_FAST=true
GENERIC += -gG_ID_SIZE=4
GENERIC += -gG_ADDR_SIZE=10
GENERIC += -gG_DATA_SIZE=16

# Don't stop on errors
#ASSERT_LEVEL = none

include ../Makefile.inc

