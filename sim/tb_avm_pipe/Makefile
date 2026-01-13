# Author:  Michael Jørgensen
#
# Description: Makefile for simulating the avm_pipe.vhd file.

# List of source files
SRC += $(SRC_DIR)/avm/avm_pipe.vhd
SRC += $(SRC_DIR)/axis/axis_pipe.vhd

# List of test specific simulation files
SRC += tb_avm_pipe.vhd

# List of generic simulation files
SRC += $(SIM_SRC_DIR)/avm_master_sim.vhd
SRC += $(SIM_SRC_DIR)/avm_pause.vhd
SRC += $(SIM_SRC_DIR)/avm_sim.vhd
SRC += $(SIM_SRC_DIR)/avm_slave_sim.vhd
SRC += $(SIM_SRC_DIR)/lfsr.vhd
SRC += $(SIM_SRC_DIR)/random.vhd

# Top level entity
DUT = avm_pipe

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

