// Generates a random byte on each clock using a made-up XORshift algorithm
module rng (
    // Clock (regenerates on each clock)
    input wire clk,
    // Random byte
    output reg [7:0] x = SEED
);

// basic XORshift RNG with mostly made-up constants
function [7:0] next_rand_num(input [7:0] rand_num);
    reg [7:0] x;

    x = rand_num;
    x = x ^ (x << 4);
    x = x ^ (x >> 3);
    x = x ^ (~x << 1);
    x = x ^ (x << 3);

    next_rand_num = x;
endfunction

// The PRNG seed
parameter SEED = 8'h4;

always @(posedge clk) begin: rng_block
    // Generate new random number on each clock
    x <= next_rand_num(x);
end

endmodule
