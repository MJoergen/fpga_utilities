# This Makefile runs through all the DUTs
# and does Bounded Model Check on each of them.

DUTS += avm_arbiter
DUTS += avm_readahead
DUTS += avm_increase
DUTS += axil_to_avm
DUTS += axil_to_wbus
DUTS += axip_arbiter
DUTS += axip_dropper
DUTS += axip_insert_fixed_header
DUTS += axip_remove_fixed_header
DUTS += axip_to_axis
DUTS += axis_arbiter
DUTS += axis_fifo
DUTS += axis_to_axip
DUTS += wbus_arbiter

BMC        = $(patsubst %,%_bmc,$(DUTS))
COVER      = $(patsubst %,%_cover,$(DUTS))
PROVE      = $(patsubst %,%_prove,$(DUTS))
BMC_PASS   = $(patsubst %,%_bmc/PASS,$(DUTS))
COVER_PASS = $(patsubst %,%_cover/PASS,$(DUTS))

all: $(BMC_PASS)

%_bmc/PASS: DUT=$(patsubst %_bmc/PASS,%,$@)
%_bmc/PASS:
	sby --yosys "yosys -m ghdl" -f $(DUT).sby

clean:
	rm -rf $(BMC)
	rm -rf $(COVER)
	rm -rf $(PROVE)
	rm -rf $(DUTS)

