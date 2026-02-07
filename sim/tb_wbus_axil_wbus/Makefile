# Author:  Michael Jørgensen
#
# Description: Makefile for simulating the axil_wbus.vhd and wbus_axil.vhd files.

# List of source files
SRC += $(SRC_DIR)/axil/axil_pkg.vhd
SRC += $(SRC_DIR)/wbus/wbus_pkg.vhd
SRC += $(SRC_DIR)/converters/axil_to_wbus.vhd
SRC += $(SRC_DIR)/converters/wbus_to_axil.vhd

# List of generic simulation files
SRC += $(SIM_SRC_DIR)/lfsr.vhd
SRC += $(SIM_SRC_DIR)/random.vhd
SRC += $(SIM_SRC_DIR)/wbus_master_sim.vhd
SRC += $(SIM_SRC_DIR)/wbus_slave_sim.vhd

# List of test specific simulation files
SRC += tb_wbus_axil_wbus.vhd

# Top level entity
DUT = wbus_axil_wbus

# Test duration
STOP_TIME = 100us

# Test specific generics
GENERIC += -gG_DEBUG=false
GENERIC += -gG_ADDR_SIZE=8
GENERIC += -gG_DATA_SIZE=16

# Don't stop on errors
#ASSERT_LEVEL = none

include ../Makefile.inc

