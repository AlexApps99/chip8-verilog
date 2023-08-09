#!/bin/sh

hexdump -ve '1/1 "%.2X\n"' ibm.ch8 > ibm.ch8.hex
