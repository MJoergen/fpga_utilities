# Author:  Michael Jørgensen
#
# Description: Makefile for simulating the wbus_master_sim.vhd file.

# List of test specific simulation files
SRC += tb_wbus_master.vhd

# List of generic simulation files
SRC += $(SIM_SRC_DIR)/lfsr.vhd
SRC += $(SIM_SRC_DIR)/random.vhd
SRC += $(SIM_SRC_DIR)/wbus_master_sim.vhd
SRC += $(SIM_SRC_DIR)/wbus_slave_sim.vhd

# Top level entity
DUT = wbus_master

# Test duration
STOP_TIME = 500us

# Test bench configuration
GENERIC += -gG_DEBUG=false
GENERIC += -gG_ADDR_SIZE=12
GENERIC += -gG_DATA_SIZE=16

include ../Makefile.inc

