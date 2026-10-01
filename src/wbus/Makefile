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
# Per-file generic overrides.
#
# Format: space-separated list of `-gNAME=VALUE` arguments.
# These are passed both to `ghdl -m` (for the elaboration smoke test)
# and to the `ghdl` pass inside yosys (for the actual synthesis).
#
# Files not listed below are synthesised with all generic defaults.
# Use small geometry generics (G_ADDR_BITS, G_DATA_BITS) to keep the
# synthesis check fast; pick generics that exercise non-trivial paths.
#
# Add a line per file that needs overrides:

GENERICS_wbus_arbiter         = -gG_ADDR_BITS=6  -gG_DATA_BITS=8
# Three masters exercise the recursive (G_NUM_MASTERS > 2) branch, and
# non-default widths check that the widths are propagated to the sub-arbiters.
GENERICS_wbus_arbiter_general = -gG_NUM_MASTERS=3 -gG_ADDR_BITS=6 -gG_DATA_BITS=16


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

