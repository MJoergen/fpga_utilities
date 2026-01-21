# Run all source files through yosys to check for synthesis

SRC += axil_arbiter_read.vhd
SRC += axil_arbiter.vhd
SRC += axil_arbiter_write.vhd
#SRC += axil_fifo_async.vhd
SRC += axil_pipe_async.vhd
SRC += axil_pipe.vhd

TARGETS = $(patsubst %.vhd,%.edif,$(SRC))

all: $(TARGETS)

# Explicitly handle dependencies
axil_arbiter.edif: axil_arbiter_read.vhd axil_arbiter.vhd axil_arbiter_write.vhd
axil_pipe_async.edif: axil_pipe_async.vhd ../axis/axis_pipe_async.vhd
axil_pipe.edif: axil_pipe.vhd ../axis/axis_pipe.vhd


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

