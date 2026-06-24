# Author:  Michael Jørgensen
#
# Description: Makefile for simulating the avm_arbiter.vhd file.

# List of source files
SRC += $(SRC_DIR)/avm/avm_arbiter.vhd

# List of test specific simulation files
SRC += tb_avm_arbiter.vhd

# List of generic simulation files
SRC += $(SIM_SRC_DIR)/avm_master_sim.vhd
SRC += $(SIM_SRC_DIR)/avm_pause.vhd
SRC += $(SIM_SRC_DIR)/avm_sim.vhd
SRC += $(SIM_SRC_DIR)/avm_slave_sim.vhd
SRC += $(SIM_SRC_DIR)/lfsr.vhd
SRC += $(SIM_SRC_DIR)/random.vhd
SRC += $(SRC_DIR)/axis/axis_fifo.vhd

# Top level entity
DUT = avm_arbiter

# Test duration
STOP_TIME = 600us

# Test bench configuration
GENERIC += -gG_BURST_WIDTH=4
GENERIC += -gG_PREFER_SWAP=true
GENERIC += -gG_PAUSE_SIZE=3
GENERIC += -gG_ADDR_SIZE=12
GENERIC += -gG_DATA_SIZE=16

include ../Makefile.inc

