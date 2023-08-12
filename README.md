# Verilog Chip-8 :)
## TODO
- Boot loader/game switching process
- SD card IO to load different games
- Reset
- Draw should be tied to VSYNC

## Testing
I have vaguely tested the Chip-8 functionality in Verilator simulator, but everything else (e.g I/O) I'm probably just going to hope for the best.

To run the tests, use `./tb.sh`. [This site](https://www.dcode.fr/binary-image) might help when converting the binary output into an image.

## Optimization
Not really sure how to improve upon this. In Quartus II on my laptop, none of the compilation attempts have finished, despite running it for hours. Maybe there's an undetected fundamental problem, or maybe it just has rubbish Linux support.

## ROMs
Run `./make_hex.sh` to generate hex files for the various game files used.
