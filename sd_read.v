module sd_read(
    input wire rst,
    input wire clk,

    output wire sd_clk,
    inout sd_dat0,
    inout sd_cmd
);

assign sd_clk = 1'b0;

// TODO
// https://web.archive.org/web/20200725013613/http://wiki.seabright.co.nz/wiki/SdCardProtocol.html

endmodule
