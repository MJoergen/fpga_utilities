# Author:  Michael Jørgensen
#
# Description: Makefile for simulating the wbus_mapper.vhd file.

# List of source files
SRC += $(SRC_DIR)/wbus/wbus_pkg.vhd
SRC += $(SRC_DIR)/wbus/wbus_mapper.vhd

# List of test specific simulation files
SRC += tb_wbus_mapper.vhd

# List of generic simulation files
SRC += $(SIM_SRC_DIR)/lfsr.vhd
SRC += $(SIM_SRC_DIR)/random.vhd
SRC += $(SIM_SRC_DIR)/wbus_pause.vhd
SRC += $(SIM_SRC_DIR)/wbus_slave_sim.vhd

# Top level entity
DUT = wbus_mapper

# Test duration
STOP_TIME = 1000us

# Test bench configuration
GENERIC += -gG_DEBUG=false
GENERIC += -gG_NUM_TRANSACTIONS=3000
GENERIC += -gG_TIMEOUT_MAX=20

include ../Makefile.inc
