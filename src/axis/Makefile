# Run all source files through yosys to check for synthesis

SRC += axis_arbiter_pair.vhd
SRC += axis_arbiter.vhd
SRC += axis_distributor.vhd
SRC += axis_dropper.vhd
#SRC += axis_fifo_async.vhd   # Uses XPM, not supported by yosys
SRC += axis_fifo_sync.vhd
SRC += axis_pipe_async.vhd
SRC += axis_pipe_lite.vhd
SRC += axis_pipe.vhd

TARGETS = $(patsubst %.vhd,%.edif,$(SRC))

all: $(TARGETS)

# Explicitly handle dependencies
axis_dropper.edif:         axis_fifo_sync.vhd axis_dropper.vhd

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

