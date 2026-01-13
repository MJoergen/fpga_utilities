# Author:  Michael Jørgensen
#
# Description: Makefile for simulating the avm_sim.vhd file.

# List of test specific simulation files
SRC += tb_avm_sim.vhd

# List of generic simulation files
SRC += $(SIM_SRC_DIR)/lfsr.vhd
SRC += $(SIM_SRC_DIR)/random.vhd
SRC += $(SIM_SRC_DIR)/avm_master_sim.vhd
SRC += $(SIM_SRC_DIR)/avm_slave_sim.vhd
SRC += $(SIM_SRC_DIR)/avm_sim.vhd
SRC += $(SIM_SRC_DIR)/avm_pause.vhd

# Top level entity
DUT = avm_sim

# Test duration
STOP_TIME = 500us

# Test bench configuration
GENERIC += -gG_DEBUG=false
GENERIC += -gG_ADDR_SIZE=12
GENERIC += -gG_DATA_SIZE=16
GENERIC += -gG_TIMEOUT_MAX=100
GENERIC += -gG_PAUSE_SIZE=3
GENERIC += -gG_DO_ABORT=true

include ../Makefile.inc

