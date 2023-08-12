#!/bin/bash

verilator -O3 --timing --binary tb.v -Wno-TIMESCALEMOD && obj_dir/Vtb
