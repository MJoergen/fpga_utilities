# Run all source files through yosys to check for synthesis

SRC += avm_to_axil.vhd
SRC += avm_to_wbus.vhd
SRC += axil_to_avm.vhd
SRC += axil_to_wbus.vhd
SRC += axip_to_axis.vhd
SRC += axis_to_axip.vhd
SRC += wbus_to_avm.vhd
SRC += wbus_to_axil.vhd


TARGETS = $(patsubst %.vhd,%.edif,$(SRC))

all: $(TARGETS)

# Explicitly handle dependencies


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

GENERICS_avm_to_axil   = -gG_ADDR_BITS=6  -gG_DATA_BITS=8
GENERICS_avm_to_wbus   = -gG_ADDR_BITS=6  -gG_DATA_BITS=8 -gG_BURST_BITS=4
GENERICS_axil_to_avm   = -gG_ADDR_BITS=6  -gG_DATA_BITS=8
GENERICS_axil_to_wbus  = -gG_ADDR_BITS=6  -gG_DATA_BITS=8
GENERICS_axip_to_axis  = -gG_DATA_BYTES=4
GENERICS_axis_to_axip  = -gG_DATA_BYTES=4
GENERICS_wbus_to_avm   = -gG_ADDR_BITS=6  -gG_DATA_BITS=8
GENERICS_wbus_to_axil  = -gG_ADDR_BITS=6  -gG_DATA_BITS=8

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

