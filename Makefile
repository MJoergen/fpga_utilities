# Author:  Michael Jørgensen
#
# Description: Makefile for testing all the modules

TARGETS += src
TARGETS += sim
TARGETS += formal

all: $(TARGETS)

.PHONY: src
src:
	$(MAKE) -C src

.PHONY: sim
sim:
	$(MAKE) -C sim

.PHONY: formal
formal:
	$(MAKE) -C formal

.PHONY: clean
clean:
	$(MAKE) -C src clean
	$(MAKE) -C sim clean
	$(MAKE) -C formal clean

