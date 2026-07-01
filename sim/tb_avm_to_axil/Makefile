# Author:  Michael Jørgensen
#
# Description: Makefile for simulating the wbus_to_axil.vhd file.

# List of source files
SRC += $(SRC_DIR)/converters/avm_to_axil.vhd

# List of test specific simulation files
SRC += tb_avm_to_axil.vhd

# List of generic simulation files
SRC += $(SIM_SRC_DIR)/lfsr.vhd
SRC += $(SIM_SRC_DIR)/random.vhd
SRC += $(SIM_SRC_DIR)/axis_pause.vhd
SRC += $(SIM_SRC_DIR)/axil_pause.vhd
SRC += $(SIM_SRC_DIR)/avm_master_sim.vhd
SRC += $(SIM_SRC_DIR)/axil_slave_sim.vhd

# Top level entity
DUT = avm_to_axil

# Test bench configuration
GENERIC += -gG_DEBUG=false
GENERIC += -gG_FAST=true
GENERIC += -gG_ADDR_BITS=12
GENERIC += -gG_DATA_BITS=16
GENERIC += -gG_BURST_BITS=8
GENERIC += -gG_MAX_BURST=1
GENERIC += -gG_RANDOM_BYTEENABLE=false
GENERIC += -gG_TIMEOUT_MAX=0

# Test duration
STOP_TIME = 400us

include ../Makefile.inc

