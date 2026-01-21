# Run all source files through yosys to check for synthesis

SRC += wbus_arbiter_general.vhd
SRC += wbus_arbiter.vhd
SRC += wbus_mapper.vhd

TARGETS = $(patsubst %.vhd,%.edif,$(SRC))

all: $(TARGETS)

# Explicitly handle dependencies
wbus_arbiter_general.edif: wbus_arbiter_general.vhd wbus_pkg.vhd wbus_arbiter.vhd
wbus_mapper.edif: wbus_mapper.vhd wbus_pkg.vhd


########################################
# Don't change anything below here

%.edif: DUT=$(basename $@)

%.edif: %.vhd
	ghdl -i --std=08 --work=$(DUT)_work $^
	ghdl -m --std=08 --work=$(DUT)_work $(DUT)
	yosys -m ghdl -p 'ghdl --std=08 --work=$(DUT)_work $(DUT); synth_xilinx -top $(DUT) -edif $@' > $(DUT).log

.PHONY: clean
clean:
	rm -f *_work-obj08.cf
	rm -f *.log
	rm -f *.edif

