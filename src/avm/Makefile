# Run all source files through yosys to check for synthesis

SRC += avm_arbit.vhd
SRC += avm_pipe.vhd

TARGETS = $(patsubst %.vhd,%.edif,$(SRC))

all: $(TARGETS)

# Explicitly handle dependencies
avm_pipe.edif: avm_pipe.vhd ../axis/axis_pipe.vhd


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

