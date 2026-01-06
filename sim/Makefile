# Author:  Michael Jørgensen
#
# Description: Makefile for simulating all the modules

DUTS += tb_axil_arbiter
DUTS += tb_axil_pipe
DUTS += tb_axil_sim
DUTS += tb_axil_to_wbus
DUTS += tb_axip_fifo_sync
DUTS += tb_axip_fixed_header
DUTS += tb_axip_insert_fixed_header
DUTS += tb_axip_remove_fixed_header
DUTS += tb_axis_arbiter
DUTS += tb_axis_fifo_sync
DUTS += tb_axis_pipe
DUTS += tb_axis_pipe_lite
DUTS += tb_axis_sim
DUTS += tb_wbus_arbiter
DUTS += tb_wbus_master
DUTS += tb_wbus_to_axil

DUT_PASS   = $(patsubst %,%/PASS,$(DUTS))

all: $(DUT_PASS)

%/PASS: DUT=$(patsubst %/PASS,%,$@)
%/PASS:
	make -C $(DUT)

clean:
	for i in $(DUTS); do make -C $$i clean; done

