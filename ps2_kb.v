`define HANDLE_KEY(n) key_detected = n;

// Very basic, primitive PS/2 implementation.
// Doesn't support resetting the keyboard, which is a bit problematic.
module ps2_kb(
    input wire rst,
    input wire clk,
    inout wire data_pin,
    inout wire clk_pin,
    output reg [15:0] input_keys,
    // The most recent key that's being held (or 16 as sentinel value for no key)
    output reg [4:0] newest_key_down
);

reg prev_byte_was_release;
reg parity_fail;
reg [7:0] current_byte;

// 0 = before Start bit, 1 to 8 = before 8 bits, 9 = before parity bit, 10 = before stop bit (and repeat)
reg [3:0] bit_counter;

assign clk_pin = clk;

always @(negedge clk or posedge rst) begin: ps2_block
    reg [4:0] key_detected;
    if (rst) begin
        bit_counter <= 0;
        current_byte <= 0;
        prev_byte_was_release <= 0;
        parity_fail <= 0;
        input_keys <= 0;
        newest_key_down <= 16;
    end else begin
        bit_counter <= bit_counter + 1;
        if (bit_counter == 0) begin
            // Start bit (don't start until start bit is low)
            if (data_pin) begin
                bit_counter <= 0;
            end
        end else if (bit_counter <= 8) begin
            // Save data bits
            current_byte <= current_byte | (data_pin << (bit_counter - 1));
        end else if (bit_counter == 9) begin
            // Parity bit
            // Mark current byte is invalid if parity doesn't match
            parity_fail <= (^current_byte == data_pin);
        end else begin
            // Stop bit

            // Zero variables
            bit_counter <= 0;
            current_byte <= 0;
            prev_byte_was_release <= 0;
            parity_fail <= 0;

            // If parity check passed, and end bit is high, react according to key code
            if (parity_fail == 0 && data_pin != 0) begin
                if (current_byte == 8'hF0) begin
                    // This byte precedes the key code being released
                    prev_byte_was_release <= 1;
                end else begin
                    case (current_byte)
                        // X (22)
                        8'h22: `HANDLE_KEY(0)
                        // 1 (16)
                        8'h16: `HANDLE_KEY(1)
                        // 2 (1E)
                        8'h1E: `HANDLE_KEY(2)
                        // 3 (26)
                        8'h26: `HANDLE_KEY(3)
                        // Q (15)
                        8'h15: `HANDLE_KEY(4)
                        // W (1D)
                        8'h1D: `HANDLE_KEY(5)
                        // E (24)
                        8'h24: `HANDLE_KEY(6)
                        // A (1C)
                        8'h1C: `HANDLE_KEY(7)
                        // S (1B)
                        8'h1B: `HANDLE_KEY(8)
                        // D (23)
                        8'h23: `HANDLE_KEY(9)
                        // Z (1A)
                        8'h1A: `HANDLE_KEY(10)
                        // C (21)
                        8'h21: `HANDLE_KEY(11)
                        // 4 (25)
                        8'h25: `HANDLE_KEY(12)
                        // R (2D)
                        8'h2D: `HANDLE_KEY(13)
                        // F (2B)
                        8'h2B: `HANDLE_KEY(14)
                        // V (2A)
                        8'h2A: `HANDLE_KEY(15)
                    endcase
                    input_keys[key_detected] = ~prev_byte_was_release;
                    if (newest_key_down == key_detected && prev_byte_was_release)
                        newest_key_down = 16;
                    else if (!prev_byte_was_release)
                        newest_key_down = key_detected;
                end
            end
        end
    end
end

endmodule
