# Run all source files through yosys to check for synthesis

SRC += axip_arbiter_general.vhd
SRC += axip_arbiter.vhd
SRC += axip_demux.vhd
SRC += axip_dropper.vhd
SRC += axip_fifo_async.vhd
SRC += axip_fifo.vhd
SRC += axip_insert_fixed_header.vhd
SRC += axip_pipe.vhd
#SRC += axip_pkg.vhd                # Only contains a package
SRC += axip_remove_fixed_header.vhd

TARGETS = $(patsubst %.vhd,%.edif,$(SRC))

all: $(TARGETS)

# Explicitly handle dependencies
axip_arbiter_general.edif: axip_pkg.vhd axip_arbiter.vhd axip_arbiter_general.vhd
axip_dropper.edif:         ../axis/axis_fifo.vhd axip_pkg.vhd axip_dropper.vhd
axip_pipe.edif:            ../axis/axis_pipe.vhd axip_pipe.vhd
axip_fifo_async.edif:      ../axis/axis_fifo_async.vhd axip_fifo_async.vhd
axip_fifo.edif:            ../axis/axis_fifo.vhd axip_fifo.vhd

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

GENERICS_axip_arbiter_general     = -gG_NUM_MASTERS=4 -gG_DATA_BYTES=4
GENERICS_axip_arbiter             = -gG_DATA_BYTES=4
GENERICS_axip_demux               = -gG_DATA_BYTES=4
GENERICS_axip_dropper             = -gG_DATA_BYTES=4
GENERICS_axip_fifo_async          = -gG_ADDR_BITS=4 -gG_DATA_BYTES=4 -gG_RAM_STYLE=block
GENERICS_axip_fifo                = -gG_ADDR_BITS=4 -gG_DATA_BYTES=4 -gG_RAM_STYLE=distributed
GENERICS_axip_insert_fixed_header = -gG_DATA_BYTES=8 -gG_HEADER_BYTES=2
GENERICS_axip_pipe                = -gG_DATA_BYTES=4
GENERICS_axip_remove_fixed_header = -gG_DATA_BYTES=8 -gG_HEADER_BYTES=2

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

