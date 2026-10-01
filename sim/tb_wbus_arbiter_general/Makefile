# Author:  Michael Jørgensen
#
# Description: Makefile for simulating the wbus_arbiter_general.vhd file.

# List of source files
SRC += $(SRC_DIR)/wbus/wbus_pkg.vhd
SRC += $(SRC_DIR)/wbus/wbus_arbiter.vhd
SRC += $(SRC_DIR)/wbus/wbus_arbiter_general.vhd

# List of test specific simulation files
SRC += tb_wbus_arbiter_general.vhd

# List of generic simulation files
SRC += $(SIM_SRC_DIR)/lfsr.vhd
SRC += $(SIM_SRC_DIR)/random.vhd
SRC += $(SIM_SRC_DIR)/wbus_master_sim.vhd
SRC += $(SIM_SRC_DIR)/wbus_slave_sim.vhd

# Top level entity
DUT = wbus_arbiter_general

# Test duration
STOP_TIME = 1000us

# Test bench configuration
# Three masters exercise both the recursive branch and the single-master branch
# of wbus_arbiter_general. The widths differ from the generic defaults (32).
GENERIC += -gG_DEBUG=false
GENERIC += -gG_DO_ABORT=true
GENERIC += -gG_NUM_MASTERS=3
GENERIC += -gG_ADDR_BITS=8
GENERIC += -gG_DATA_BITS=16

include ../Makefile.inc
