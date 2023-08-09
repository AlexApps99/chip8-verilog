// Generates a random byte on each clock using a XORshift algorithm
// TODO apparently SystemVerilog has built-in PRNG functions?
module rng (
    // Reset
    input wire rst,
    // Clock (regenerates on each clock)
    input wire clk,
    // Random byte
    output reg [7:0] x
);

// The PRNG seed
parameter SEED = 8'h4;

// Using blocking assignment feels fishy, but it does use sequential calculation, so I'm not sure...
always @(posedge rst or posedge clk) begin: rng_block
    if (rst) begin
        // Initialize byte with seed
        x = SEED;
    end else begin
        // basic XORshift RNG
        x = x ^ (x << 13);
        x = x ^ (x >> 17);
        x = x ^ (x << 5);
    end
end

endmodule
