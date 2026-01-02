# Author:  Michael Jørgensen
#
# Description: Makefile for simulating all the modules

all:
	make -C tb_axip_fifo_sync
	make -C tb_axis_arbiter
	make -C tb_axis_fifo_sync
	make -C tb_axis_fixed_header
	make -C tb_axis_insert_fixed_header
	make -C tb_axis_remove_fixed_header
	make -C tb_axis_sim

clean:
	make -C tb_axip_fifo_sync clean
	make -C tb_axis_arbiter clean
	make -C tb_axis_fifo_sync clean
	make -C tb_axis_fixed_header clean
	make -C tb_axis_insert_fixed_header clean
	make -C tb_axis_remove_fixed_header clean
	make -C tb_axis_sim clean

