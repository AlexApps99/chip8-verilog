// Very basic, primitive PS/2 implementation.
// Doesn't support resetting the keyboard, which is a bit problematic.
module ps2_kb(
    input wire rst,
    input wire clk,
    inout wire data_pin,
    inout wire clk_pin,
    output reg [15:0] input_keys,
    // The most recent key that's being held (or 16 as sentinel value for no key)
    output reg [4:0] newest_key_down,
    input wire clear_newest_key_down
);

function [4:0] keycode(input [7:0] ps2_code);
    case (ps2_code)
        // X (22)
        8'h22: keycode = 0;
        // 1 (16)
        8'h16: keycode = 1;
        // 2 (1E)
        8'h1E: keycode = 2;
        // 3 (26)
        8'h26: keycode = 3;
        // Q (15)
        8'h15: keycode = 4;
        // W (1D)
        8'h1D: keycode = 5;
        // E (24)
        8'h24: keycode = 6;
        // A (1C)
        8'h1C: keycode = 7;
        // S (1B)
        8'h1B: keycode = 8;
        // D (23)
        8'h23: keycode = 9;
        // Z (1A)
        8'h1A: keycode = 10;
        // C (21)
        8'h21: keycode = 11;
        // 4 (25)
        8'h25: keycode = 12;
        // R (2D)
        8'h2D: keycode = 13;
        // F (2B)
        8'h2B: keycode = 14;
        // V (2A)
        8'h2A: keycode = 15;
        default: keycode = 16;
    endcase
endfunction

reg prev_byte_was_release;
reg parity_fail;
reg [7:0] current_byte;
reg [4:0] current_keycode;

// 0 = before Start bit, 1 to 8 = before 8 bits, 9 = before parity bit, 10 = before stop bit (and repeat)
reg [3:0] bit_counter;

assign clk_pin = clk;

always @(negedge clk or posedge rst or posedge clear_newest_key_down) begin: ps2_block
    if (rst) begin
        bit_counter <= 0;
        current_byte <= 0;
        prev_byte_was_release <= 0;
        parity_fail <= 0;
        input_keys <= 0;
        newest_key_down <= 16;
        current_keycode <= 16;
    end else if (clear_newest_key_down) begin
        newest_key_down <= 16;
    end else begin
        bit_counter <= bit_counter + 4'b1;
        if (bit_counter == 0) begin
            // Start bit (don't start until start bit is low)
            if (data_pin) begin
                bit_counter <= 0;
            end
        end else if (bit_counter <= 8) begin
            // Save data bits
            current_byte[bit_counter[2:0]] <= data_pin;
        end else if (bit_counter == 9) begin
            // Parity bit
            // Mark current byte is invalid if parity doesn't match
            parity_fail <= (^current_byte == data_pin);
            current_keycode <= keycode(current_byte);
        end else begin
            // Stop bit

            // Zero variables
            bit_counter <= 0;
            current_byte <= 0;
            prev_byte_was_release <= 0;
            parity_fail <= 0;
            current_keycode <= 16;

            // If parity check passed, and end bit is high, react according to key code
            if (parity_fail == 0 && data_pin != 0) begin
                if (current_byte == 8'hF0) begin
                    // This byte precedes the key code being released
                    prev_byte_was_release <= 1;
                end else begin
                    if (current_keycode < 16) begin
                        input_keys[current_keycode[3:0]] <= ~prev_byte_was_release;
                        if (!prev_byte_was_release && !input_keys[current_keycode[3:0]]) begin
                            newest_key_down <= current_keycode;
                        end
                    end
                end
            end
        end
    end
end

endmodule
