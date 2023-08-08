// Applies the Double-Dabble BCD algorithm to an 8-bit number
module bcd(
    // Number in binary
    input [7:0] num,
    // BCD output (4 bits per 10's place)
    output reg [11:0] bcd
);

always @(num) begin: calc_bcd
    // Scratchspace
    reg [19:0] scr;
    integer i;

    scr = num << 1;

    for (i = 0; i < 7; i = i + 1) begin
        if (scr[11:8] >= 5) begin
            scr[11:8] = scr[11:8] + 3;
        end

        if (scr[15:12] >= 5) begin
            scr[15:12] = scr[15:12] + 3;
        end

        if (scr[19:16] >= 5) begin
            scr[19:16] = scr[19:16] + 3;
        end

        scr = scr << 1;
    end
    bcd = scr[19:8];
end

endmodule
