# Author:  Michael Jørgensen
#
# Description: Makefile for simulating all the modules

DUTS += tb_avm_arbiter
DUTS += tb_avm_decrease
DUTS += tb_avm_increase
DUTS += tb_avm_pipe
DUTS += tb_avm_readahead
DUTS += tb_avm_sim
DUTS += tb_avm_to_axil
DUTS += tb_axil_arbiter
DUTS += tb_axil_pipe
DUTS += tb_axil_sim
DUTS += tb_axil_to_avm
DUTS += tb_axil_to_wbus
DUTS += tb_axip_arbiter
DUTS += tb_axip_axis_axip
DUTS += tb_axip_dropper
DUTS += tb_axip_fifo
DUTS += tb_axip_fixed_header
DUTS += tb_axip_insert_fixed_header
DUTS += tb_axip_pipe
DUTS += tb_axip_remove_fixed_header
DUTS += tb_axip_sim
DUTS += tb_axis_arbiter
DUTS += tb_axis_decrease_increase
DUTS += tb_axis_fifo
DUTS += tb_axis_pipe
DUTS += tb_axis_pipe_lite
DUTS += tb_axis_sim
DUTS += tb_wbus_arbiter
DUTS += tb_wbus_axil_wbus
DUTS += tb_wbus_sim
DUTS += tb_wbus_to_axil
DUTS += tb_wbus_to_avm
DUTS += tb_avm_to_wbus

DUT_PASS   = $(patsubst %,%/PASS,$(DUTS))

all: $(DUT_PASS)

%/PASS: DUT=$(patsubst %/PASS,%,$@)
%/PASS:
	$(MAKE) -C $(DUT)

clean:
	for i in $(DUTS); do $(MAKE) -C $$i clean; done

