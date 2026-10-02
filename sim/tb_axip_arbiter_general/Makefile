# Author:  Michael Jørgensen
#
# Description: Makefile for simulating the axip_arbiter_general.vhd file.

# List of source files
SRC += $(SRC_DIR)/axip/axip_pkg.vhd
SRC += $(SRC_DIR)/axip/axip_arbiter.vhd
SRC += $(SRC_DIR)/axip/axip_arbiter_general.vhd
SRC += $(SRC_DIR)/axip/axip_insert_fixed_header.vhd
SRC += $(SRC_DIR)/axip/axip_remove_fixed_header.vhd

# List of test specific simulation files
SRC += tb_axip_arbiter_general.vhd

# List of generic simulation files
SRC += $(SIM_SRC_DIR)/lfsr.vhd
SRC += $(SIM_SRC_DIR)/random.vhd
SRC += $(SIM_SRC_DIR)/axip_sim.vhd
SRC += $(SIM_SRC_DIR)/axip_master_sim.vhd
SRC += $(SIM_SRC_DIR)/axip_slave_sim.vhd

# Top level entity
DUT = axip_arbiter_general

# Test duration
STOP_TIME = 300us

# Test bench configuration
# Five masters exercise all three branches of axip_arbiter_general (one, two, and
# more than two masters), with two levels of recursion (5 = 3 + 2, 3 = 2 + 1).
GENERIC += -gG_RANDOM=true
GENERIC += -gG_DEBUG=false
GENERIC += -gG_MIN_LENGTH=1
GENERIC += -gG_MAX_LENGTH=10
GENERIC += -gG_FAST=true
GENERIC += -gG_CNT_SIZE=12
GENERIC += -gG_NUM_MASTERS=5
GENERIC += -gG_DATA_BYTES=4

include ../Makefile.inc
