# Author:  Michael Jørgensen
#
# Description: Makefile for simulating all the modules

all:
	make -C tb_axil_arbiter
	make -C tb_axil_sim
	make -C tb_axil_to_wbus
	make -C tb_axip_fifo_sync
	make -C tb_axip_fixed_header
	make -C tb_axip_insert_fixed_header
	make -C tb_axip_remove_fixed_header
	make -C tb_axis_arbiter
	make -C tb_axis_fifo_sync
	make -C tb_axis_sim
	make -C tb_wbus_arbiter
	make -C tb_wbus_master
	make -C tb_wbus_to_axil

clean:
	make -C tb_axil_arbiter clean
	make -C tb_axil_sim clean
	make -C tb_axil_to_wbus clean
	make -C tb_axip_fifo_sync clean
	make -C tb_axip_fixed_header clean
	make -C tb_axip_insert_fixed_header clean
	make -C tb_axip_remove_fixed_header clean
	make -C tb_axis_arbiter clean
	make -C tb_axis_fifo_sync clean
	make -C tb_axis_sim clean
	make -C tb_wbus_arbiter clean
	make -C tb_wbus_master clean
	make -C tb_wbus_to_axil clean

