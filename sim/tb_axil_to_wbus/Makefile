# Author:  Michael Jørgensen
#
# Description: Makefile for simulating the axi_wbus.vhd file.

# List of source files
SRC += $(SRC_DIR)/axil_arbiter.vhd
SRC += $(SRC_DIR)/axis_arbiter.vhd
SRC += $(SRC_DIR)/axis_arbiter_pair.vhd
SRC += $(SRC_DIR)/axis_distributor.vhd
SRC += $(SRC_DIR)/axil_to_wbus.vhd
SRC += $(SRC_DIR)/wbus_to_axil.vhd

# List of test specific simulation files
SRC += tb_axil_to_wbus.vhd

# List of generic simulation files
SRC += $(SIM_SRC_DIR)/axil_busy.vhd
SRC += $(SIM_SRC_DIR)/axil_pause.vhd
SRC += $(SIM_SRC_DIR)/axis_pause.vhd
SRC += $(SIM_SRC_DIR)/lfsr.vhd
SRC += $(SIM_SRC_DIR)/random.vhd
SRC += $(SIM_SRC_DIR)/axil_master_sim.vhd
SRC += $(SIM_SRC_DIR)/wbus_slave_sim.vhd

# Top level entity
DUT = axil_to_wbus

# Test duration
STOP_TIME = 100us

# Test bench configuration
GENERIC += -gG_DEBUG=false
GENERIC += -gG_LATENCY=2
GENERIC += -gG_RANDOM=true
GENERIC += -gG_FAST=true
GENERIC += -gG_ADDR_SIZE=8
GENERIC += -gG_DATA_SIZE=16

# Don't stop on errors
ASSERT_LEVEL = none

include ../Makefile.inc

