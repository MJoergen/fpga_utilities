# Author:  Michael Jørgensen
#
# Description: Makefile for simulating the axi_wbus.vhd file.

# List of source files

# List of test specific simulation files
SRC += tb_axip_sim.vhd

# List of generic simulation files
SRC += $(SIM_SRC_DIR)/axip_sim.vhd
SRC += $(SIM_SRC_DIR)/axip_master_sim.vhd
SRC += $(SIM_SRC_DIR)/axip_slave_sim.vhd
SRC += $(SIM_SRC_DIR)/lfsr.vhd
SRC += $(SIM_SRC_DIR)/random.vhd
SRC += $(SIM_SRC_DIR)/axis_pause.vhd
SRC += $(SIM_SRC_DIR)/axip_pause.vhd

# Top level entity
DUT = axip_sim

# Test duration
STOP_TIME = 300us

# Test bench configuration
GENERIC += -gG_DEBUG=false
GENERIC += -gG_PAUSE_SIZE=2
GENERIC += -gG_MIN_LENGTH=1
GENERIC += -gG_MAX_LENGTH=20
GENERIC += -gG_CNT_SIZE=14
GENERIC += -gG_DATA_BYTES=3

# Don't stop on errors
#ASSERT_LEVEL = none

include ../Makefile.inc

