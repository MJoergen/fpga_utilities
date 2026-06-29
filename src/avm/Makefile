# Run all source files through yosys to check for synthesis

SRC += avm_arbiter.vhd
SRC += avm_decrease.vhd
SRC += avm_increase.vhd
SRC += avm_pipe.vhd
SRC += avm_readahead.vhd

TARGETS = $(patsubst %.vhd,%.edif,$(SRC))

all: $(TARGETS)

# Explicitly handle dependencies
avm_pipe.edif: avm_pipe.vhd ../axis/axis_pipe.vhd
avm_increase.edif: avm_increase.vhd ../axis/axis_fifo.vhd


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

GENERICS_avm_arbiter   = -gG_ADDR_BITS=6  -gG_DATA_BITS=8
GENERICS_avm_decrease  = -gG_SLAVE_ADDR_BITS=12 -gG_SLAVE_DATA_BITS=32 -gG_MASTER_ADDR_BITS=13 -gG_MASTER_DATA_BITS=16
GENERICS_avm_increase  = -gG_SLAVE_ADDR_BITS=13 -gG_SLAVE_DATA_BITS=16 -gG_MASTER_ADDR_BITS=12 -gG_MASTER_DATA_BITS=32
GENERICS_avm_pipe      = -gG_ADDR_BITS=6  -gG_DATA_BITS=8
GENERICS_avm_readahead = -gG_ADDR_BITS=6  -gG_DATA_BITS=8


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

