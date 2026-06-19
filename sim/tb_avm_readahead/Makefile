# Author:  Michael Jørgensen
#
# Description: Makefile for simulating the avm_sim.vhd file.

# List of test specific simulation files
SRC += tb_avm_readahead.vhd

# List of generic simulation files
SRC += $(SIM_SRC_DIR)/lfsr.vhd
SRC += $(SIM_SRC_DIR)/random.vhd
SRC += $(SIM_SRC_DIR)/avm_master_sim.vhd
SRC += $(SIM_SRC_DIR)/avm_slave_sim.vhd
SRC += $(SIM_SRC_DIR)/avm_sim.vhd
SRC += $(SIM_SRC_DIR)/avm_pause.vhd
SRC += $(SIM_SRC_DIR)/avm_scoreboard_pkg.vhd
SRC += $(SIM_SRC_DIR)/avm_scoreboard.vhd
SRC += $(SRC_DIR)/axis/axis_fifo.vhd
SRC += $(SRC_DIR)/avm/avm_readahead.vhd

# Top level entity
DUT = avm_readahead

# Test duration
STOP_TIME = 1000us

# Test bench configuration
GENERIC += -gG_BURST_WIDTH=4
GENERIC += -gG_CACHE_SIZE=4
GENERIC += -gG_MAX_BURST=4
GENERIC += -gG_DEBUG=false
GENERIC += -gG_DO_ABORT=true
GENERIC += -gG_PAUSE_SIZE=3
GENERIC += -gG_TIMEOUT_MAX=100
GENERIC += -gG_ADDRESS_SIZE=12
GENERIC += -gG_DATA_SIZE=16

include ../Makefile.inc

