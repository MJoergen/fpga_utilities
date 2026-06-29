# Run all source files through yosys to check for synthesis

SRC += axis_arbiter.vhd
SRC += axis_demux.vhd
SRC += axis_dropper.vhd
SRC += axis_fifo_async.vhd
SRC += axis_fifo.vhd
SRC += axis_pipe_async.vhd
SRC += axis_pipe_lite.vhd
SRC += axis_pipe.vhd



TARGETS = $(patsubst %.vhd,%.edif,$(SRC))

all: $(TARGETS)

# Explicitly handle dependencies
axis_dropper.edif:         axis_fifo.vhd axis_dropper.vhd

########################################
# Per-file generic overrides.
#
# Format: space-separated list of `-gNAME=VALUE` arguments.
# These are passed both to `ghdl -m` (for the elaboration smoke test)
# and to the `ghdl` pass inside yosys (for the actual synthesis).
#
# Files not listed below are synthesised with all generic defaults.
# Use small geometry generics (G_ADDR_BITS, G_DATA_BITS) to keep the
# synthesis check fast; pick generics that exercise non-trivial paths
# (e.g. set G_RAM_STYLE=block to confirm BRAM inference).
#
# Add a line per file that needs overrides:

GENERICS_axis_fifo       = -gG_ADDR_BITS=6  -gG_DATA_BITS=8 -gG_RAM_STYLE=distributed
GENERICS_axis_fifo_async = -gG_ADDR_BITS=12 -gG_DATA_BITS=8 -gG_RAM_STYLE=block
GENERICS_axis_pipe_async = -gG_DATA_BITS=8
GENERICS_axis_arbiter    = -gG_DATA_BITS=8
GENERICS_axis_demux      = -gG_DATA_BITS=8
GENERICS_axis_dropper    = -gG_ADDR_BITS=4 -gG_DATA_BITS=8 -gG_RAM_DEPTH=32
GENERICS_axis_pipe_lite  = -gG_DATA_BITS=8
GENERICS_axis_pipe       = -gG_DATA_BITS=8

########################################
# Don't change anything below here

%.edif: DUT=$(basename $@)

# Convenience: GHDL_GENERICS expands per-target. If no overrides are
# defined for $(DUT) it expands to the empty string, which is harmless.
%.edif: GHDL_GENERICS=$(GENERICS_$(DUT))

%.edif: %.vhd
	ghdl -i --std=08 --work=$(DUT)_work $^
	ghdl -m --std=08 --work=$(DUT)_work $(DUT) $(GHDL_GENERICS)
	yosys -m ghdl -p 'ghdl --std=08 --work=$(DUT)_work $(GHDL_GENERICS) $(DUT); synth_xilinx -top $(DUT) -edif $@' > $(DUT).log

.PHONY: clean
clean:
	rm -f *_work-obj08.cf
	rm -f *.log
	rm -f *.edif

