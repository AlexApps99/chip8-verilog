// Divides a clock signal, approximating ~50% duty cycle
module clk_div #(
    // The divisor for the input clock
    parameter DIVISOR = 'd2
)
(
    // Reset (starts the cycle again, initially high)
    input wire rst,
    // Input clock (not divided yet)
    input wire clk_in,
    // Output clock (divided)
    output wire clk_out
);

// Counts number of input clocks
reg [$clog2(DIVISOR)-1:0] counter;

// Clock should be high if counter is < 50%
assign clk_out = counter < (DIVISOR >> 1);

always @(posedge rst or posedge clk_in) begin: clk_div_block
    if (rst) begin
        // Zero counter if resetting
        counter <= 0;
    end else if (counter == (DIVISOR - 1)) begin
        // Zero counter if wrapping round
        counter <= 0;
    end else begin
        // Increment counter
        counter <= counter + 1'b1;
    end
end

endmodule
