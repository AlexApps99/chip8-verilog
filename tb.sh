#!/bin/bash

verilator --timing --binary tb.v -Wno-TIMESCALEMOD && obj_dir/Vtb
