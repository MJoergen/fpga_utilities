# Author:  Michael Jørgensen
#
# Description: Makefile for simulating

# You should set these variables before including this Makefile:
# These are just random default values.
DUT          ?= main
SRC          ?= $(TB).vhd
STOP_TIME    ?= 1 us
GENERIC      ?=
ASSERT_LEVEL ?= error

################## Don't change anything below here ******************************

TB = tb_$(DUT)
WAVE = $(TB).fst
SAVE = $(TB).gtkw
TB_upper = $(shell echo $(TB) | tr '[:lower:]' '[:upper:]')
WORK = work/WORK.$(TB_upper).elab

# Code coverage
COV += --coverage

SIMULATOR = nvc
VHDL_VERSION += --std=2019

# Elaboration
#ELAB += -frelaxed
#ELAB += -fsynopsys

# Compilation options
#COMP_OPTIONS += -frelaxed
#COMP_OPTIONS += -fsynopsys

# Runtime options
RUN_OPTIONS += --ieee-warnings=off-at-0
#RUN_OPTIONS += --assert-level=$(ASSERT_LEVEL)

# Source file directories
SRC_DIR = ../../src
SIM_SRC_DIR = ../src

# Default target: Run the test
$(WAVE): $(WORK) Makefile
	rm -f PASS
	rm -f *.gcda
	$(SIMULATOR) $(VHDL_VERSION) $(RUN_OPTIONS) -r $(TB) --wave=$(WAVE) && echo > PASS

# Show the waveform of the last simulation
show: $(WAVE)
	gtkwave $(WAVE) $(SAVE)

# Show code coverage
.PHONY: show_coverage
show_coverage: html
	xdg-open html/index.html

# Analyze and Elaborate the testbench
$(WORK): $(SRC)
	$(SIMULATOR) $(VHDL_VERSION) -a $(SRC)
	$(SIMULATOR) $(VHDL_VERSION) -e $(GENERIC) $(TB)

# Generate code coverage data
html: $(WAVE)
	rm -f e~$(TB).gcno
	rm -f e~$(TB).gcda
	rm -rf html
	ghdl coverage --format=lcov coverage-*.json > $(TB)_gcov.info
	genhtml -o html $(TB)_gcov.info

# Compile and run the testbench using the QuestaSim simulator
questa: $(SRC)
	vcom -2008 $(SRC)
	vsim -do vsim_$(DUT).do

clean:
	rm -rf *.o
	rm -rf *.cf
	rm -rf $(TB)
	rm -rf $(WAVE)
	rm -rf $(DUT)_bmc
	rm -rf $(DUT)_cover
	rm -rf work
	rm -rf *.gcda
	rm -rf *.gcno
	rm -rf tb_*_gcov.info
	rm -rf html
	rm -rf src/*.html
	rm -rf PASS
	rm -rf *.json

