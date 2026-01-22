# Run all source files through yosys to check for synthesis

SRC += axip_arbiter_general.vhd
SRC += axip_arbiter.vhd
SRC += axip_distributor.vhd
#SRC += axip_fifo_async.vhd         # Uses XPM, not supported by yosys
SRC += axip_fifo_sync.vhd
SRC += axip_insert_fixed_header.vhd
SRC += axip_pipe.vhd
#SRC += axip_pkg.vhd                # Only contains a package
SRC += axip_remove_fixed_header.vhd

TARGETS = $(patsubst %.vhd,%.edif,$(SRC))

all: $(TARGETS)

# Explicitly handle dependencies
axip_arbiter_general.edif: axip_pkg.vhd axip_arbiter.vhd axip_arbiter_general.vhd
axip_pipe.edif:            ../axis/axis_pipe.vhd axip_pipe.vhd
axip_fifo_sync.edif:       ../axis/axis_fifo_sync.vhd axip_fifo_sync.vhd

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

