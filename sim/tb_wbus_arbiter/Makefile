# Author:  Michael Jørgensen
#
# Description: Makefile for simulating the wbus_arbiter.vhd file.

# List of source files
SRC += $(SRC_DIR)/wbus/wbus_arbiter.vhd

# List of test specific simulation files
SRC += tb_wbus_arbiter.vhd

# List of generic simulation files
SRC += $(SIM_SRC_DIR)/lfsr.vhd
SRC += $(SIM_SRC_DIR)/random.vhd
SRC += $(SIM_SRC_DIR)/wbus_master_sim.vhd
SRC += $(SIM_SRC_DIR)/wbus_slave_sim.vhd

# Top level entity
DUT = wbus_arbiter

# Test duration
STOP_TIME = 1200us

# Test bench configuration
GENERIC += -gG_DEBUG=false
GENERIC += -gG_DO_ABORT=true
GENERIC += -gG_ADDR_SIZE=12
GENERIC += -gG_DATA_SIZE=16

# Don't stop on errors
#ASSERT_LEVEL = none

include ../Makefile.inc

