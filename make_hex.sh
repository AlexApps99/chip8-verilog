#!/bin/bash
shopt -s nullglob

for file in ./*.ch8
do
  hexdump -ve '1/1 "%.2X\n"' "$file" > "$file".hex
done

for file in chip8-test-suite/bin/*.ch8
do
  hexdump -ve '1/1 "%.2X\n"' "$file" > "$file".hex
done
