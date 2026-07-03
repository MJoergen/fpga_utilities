# Author:  Michael Jørgensen
#
# Description: Makefile for simulating the wbus_to_axil.vhd file.

# List of source files
SRC += $(SRC_DIR)/converters/axil_to_avm.vhd

# List of test specific simulation files
SRC += tb_axil_to_avm.vhd

# List of generic simulation files
SRC += $(SIM_SRC_DIR)/lfsr.vhd
SRC += $(SIM_SRC_DIR)/random.vhd
SRC += $(SIM_SRC_DIR)/axis_pause.vhd
SRC += $(SIM_SRC_DIR)/axil_pause.vhd
SRC += $(SIM_SRC_DIR)/axil_master_sim.vhd
SRC += $(SIM_SRC_DIR)/avm_slave_sim.vhd

# Top level entity
DUT = axil_to_avm

# Test bench configuration
GENERIC += -gG_DEBUG=false
GENERIC += -gG_FAST=true
GENERIC += -gG_ADDR_BITS=12
GENERIC += -gG_DATA_BITS=16
GENERIC += -gG_BURST_BITS=8
GENERIC += -gG_MAX_BURST=1
GENERIC += -gG_PAUSE_SIZE=3

# Test duration
STOP_TIME = 200us

include ../Makefile.inc

