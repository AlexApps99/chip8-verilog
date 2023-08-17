// Generates a 720p widescreen 60fps VGA signal from display data
module vga(
    // Clock for each pixel, should be 7.425MHz for this set of timings
    input wire pixel_clk_7_425mhz,
    // Display data (64x32, row-major)
    input wire [63:0] display [31:0],
    // Color signal output (black/white)
    output reg color = '0,
    // Horizontal sync (low during sync pulse)
    output wire hsync,
    // Vertical sync (low during sync pulse)
    output wire vsync,
    // True if not in region where display is drawn
    output wire in_hblank,
    output wire in_vblank
);

// VGA timing parameters for 1280x720 taken from this page:
// https://projectf.io/posts/video-timings-vga-720p-1080p/#hd-1280x720-60-hz

// Have a look at a VGA timing diagram if it doesn't make sense :)

// Horizontal timing parameters (divided by 10 to accomodate for a slower clock)
localparam SYNC_PULSE_H_PX = 4;
localparam BACK_PORCH_H_PX = 22;
localparam VISIBLE_H_PX = 128;
localparam FRONT_PORCH_H_PX = 11;

// Vertical timing parameters (with shorter height and longer porches, to letterbox the 2:1 video signal into 16:9)
localparam VISIBLE_V_LN = 720 - 80;
localparam FRONT_PORCH_V_LN = 5 + 40;
localparam SYNC_PULSE_V_LN = 5;
localparam BACK_PORCH_V_LN = 20 + 40;

// Horizontal values calculated from timing parameters above
localparam WHOLE_LINE_H_PX = SYNC_PULSE_H_PX + BACK_PORCH_H_PX + VISIBLE_H_PX + FRONT_PORCH_H_PX;
localparam DATA_STARTS_H_PX = SYNC_PULSE_H_PX + BACK_PORCH_H_PX;
localparam DATA_ENDS_H_PX = DATA_STARTS_H_PX + VISIBLE_H_PX;

// Vertical values calculated from timing parameters above
localparam WHOLE_FRAME_V_LN = SYNC_PULSE_V_LN + BACK_PORCH_V_LN + VISIBLE_V_LN + FRONT_PORCH_V_LN;
localparam DATA_STARTS_V_LN = SYNC_PULSE_V_LN + BACK_PORCH_V_LN;
localparam DATA_ENDS_V_LN = DATA_STARTS_V_LN + VISIBLE_V_LN;

localparam H_PX_COUNTER_SIZE = $clog2(WHOLE_LINE_H_PX);
localparam V_LN_COUNTER_SIZE = $clog2(WHOLE_FRAME_V_LN);

// Counters for the current position on the screen
reg [H_PX_COUNTER_SIZE-1:0] h_px_counter = '0;
reg [V_LN_COUNTER_SIZE-1:0] v_ln_counter = '0;

// HSync/VSync should be low during the sync pulse region
assign hsync = (h_px_counter >= SYNC_PULSE_H_PX);
assign vsync = (v_ln_counter >= SYNC_PULSE_V_LN);
assign in_hblank = !(h_px_counter >= DATA_STARTS_H_PX && h_px_counter < DATA_ENDS_H_PX);
assign in_vblank = !(v_ln_counter >= DATA_STARTS_V_LN && v_ln_counter < DATA_ENDS_V_LN);

function get_pixel(input [5:0] h_offset, input [4:0] v_offset, input [63:0] display [31:0]);
    // h_offset is reversed because the left-most pixel is the most significant byte of the line
    get_pixel = display[v_offset][~h_offset];
endfunction

always @(posedge pixel_clk_7_425mhz) begin: vga_pixel
    begin
        if (!in_vblank && !in_hblank) begin
            // Draw pixel data corresponding to current position on screen
            // Each data pixel is shown on 2 horizontal VGA pixels and 20 vertical VGA pixels
            color <= get_pixel((h_px_counter-DATA_STARTS_H_PX[H_PX_COUNTER_SIZE-1:0]) >> 1, ((v_ln_counter - DATA_STARTS_V_LN[V_LN_COUNTER_SIZE-1:0]) >> 2)/5, display);
        end else begin
            // Not in a drawable area, so just do black
            color <= 0;
        end

        // Update counters
        if (h_px_counter != (WHOLE_LINE_H_PX - 1)) begin
            // Increment H counter if not at the end yet
            h_px_counter <= h_px_counter + 1'b1;
        end else begin
            // Reset H counter
            h_px_counter <= 0;
            if (v_ln_counter != (WHOLE_FRAME_V_LN - 1)) begin
                // Increment V counter if not at the end yet
                v_ln_counter <= v_ln_counter + 1'b1;
            end else begin
                // Reset V counter
                v_ln_counter <= 0;
            end
        end
    end
end

endmodule
