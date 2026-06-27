# Author:  Michael Jørgensen
#
# Description: Makefile for simulating the avm_sim.vhd file.

# List of test specific simulation files
SRC += tb_avm_to_wbus.vhd

# List of generic simulation files
SRC += $(SIM_SRC_DIR)/lfsr.vhd
SRC += $(SIM_SRC_DIR)/random.vhd
SRC += $(SIM_SRC_DIR)/avm_master_sim.vhd
SRC += $(SIM_SRC_DIR)/wbus_slave_sim.vhd
SRC += $(SRC_DIR)/converters/avm_to_wbus.vhd

# Top level entity
DUT = avm_to_wbus

# Test duration
STOP_TIME = 20us

# Test bench configuration
GENERIC += -gG_BURST_BITS=4
GENERIC += -gG_MAX_BURST=1
GENERIC += -gG_DEBUG=false
GENERIC += -gG_PAUSE_SIZE=2
GENERIC += -gG_TIMEOUT_MAX=0
GENERIC += -gG_ADDR_BITS=7
GENERIC += -gG_DATA_BITS=32

include ../Makefile.inc

