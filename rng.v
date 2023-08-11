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

always @(posedge rst or posedge clk) begin: rng_block
    if (rst) begin
        // Initialize byte with seed
        x <= SEED;
    end else begin
        // basic XORshift RNG with mostly made-up constants
        x <= next_rand_num(x);
    end
end

endmodule
