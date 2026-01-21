# Description: Makefile for synthesizing all the modules

TARGETS += avm
TARGETS += axil
TARGETS += axip
TARGETS += axis
TARGETS += converters
TARGETS += wbus

all:
	for i in $(TARGETS); do $(MAKE) -C $$i; done

clean:
	for i in $(TARGETS); do $(MAKE) -C $$i clean; done

