# Author:  Michael Jørgensen
#
# Description: Makefile for simulating the avm_arbit.vhd file.

# List of source files
SRC += $(SRC_DIR)/avm/avm_pkg.vhd
SRC += $(SRC_DIR)/avm/avm_arbit.vhd

# List of generic simulation files
SRC += $(SIM_SRC_DIR)/lfsr.vhd
SRC += $(SIM_SRC_DIR)/random.vhd
SRC += $(SIM_SRC_DIR)/avm_pause.vhd
SRC += $(SIM_SRC_DIR)/avm_master_sim.vhd
SRC += $(SIM_SRC_DIR)/avm_slave_sim.vhd
SRC += $(SIM_SRC_DIR)/avm_sim.vhd

# List of test specific simulation files
SRC += tb_avm_arbit.vhd

# Top level entity
DUT = avm_arbit

# Test duration
STOP_TIME = 500us

# Test bench configuration
GENERIC += -gG_PREFER_SWAP=true
GENERIC += -gG_PAUSE_SIZE=3
GENERIC += -gG_ADDR_SIZE=12
GENERIC += -gG_DATA_SIZE=16

include ../Makefile.inc

