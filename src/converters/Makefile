# Run all source files through yosys to check for synthesis

SRC += axil_to_wbus.vhd
SRC += axip_to_axis.vhd
SRC += axis_to_axip.vhd
SRC += wbus_to_axil.vhd

TARGETS = $(patsubst %.vhd,%.edif,$(SRC))

all: $(TARGETS)

# Explicitly handle dependencies


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

