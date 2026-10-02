# Author:  Michael Jørgensen
#
# Description: Makefile for simulating the axis_dropper.vhd file.

# List of source files
SRC += $(SRC_DIR)/axis/axis_dropper.vhd

# List of test specific simulation files
SRC += tb_axis_dropper.vhd

# List of generic simulation files
SRC += $(SIM_SRC_DIR)/lfsr.vhd
SRC += $(SIM_SRC_DIR)/random.vhd

# Top level entity
DUT = axis_dropper

# Test duration
STOP_TIME = 500us

# Test bench configuration
GENERIC += -gG_NUM_FRAMES=2000
GENERIC += -gG_MAX_LENGTH=12
GENERIC += -gG_ADDR_BITS=4
GENERIC += -gG_DATA_BITS=16
GENERIC += -gG_CNT_BITS=4

include ../Makefile.inc
