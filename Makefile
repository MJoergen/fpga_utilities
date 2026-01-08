# Author:  Michael Jørgensen
#
# Description: Makefile for testing all the modules

TARGETS += sim
TARGETS += formal

all: $(TARGETS)

.PHONY: sim
sim:
	make -C sim

.PHONY: formal
formal:
	make -C formal

.PHONY: clean
clean:
	make -C sim clean
	make -C formal clean

