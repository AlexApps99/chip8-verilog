// Chip-8 FPGA implementation
// "It's a work in progress"

//`include "ps2_kb.v"
//`include "vga.v"
//`include "chip8.v"
//`include "clk_div.v"

module main(
    // Reset button (initializes everything)
    input wire rst,

    // External clock (every other clock is just a divided version of this)
    input wire vga_pixel_clk_7_425mhz,

    // PS/2 keyboard data pin
    inout wire ps2_data_pin,
    // PS/2 keyboard clock pin
    inout wire ps2_clk_pin,

    // VGA R/G/B pin (black/white, effectively)
    output wire vga_color,
    // VGA HSync pin
    output wire vga_hsync,
    // VGA VSync pin
    output wire vga_vsync,

    // Sound buzzer using PWM
    output wire buzzer_pwm

    // TODO SD Card
    //output reg sd_clk,
    //inout sd_dat0,
    //inout sd_cmd
);

// Clocks

// 12.5 kHz PS/2 clock
wire ps2_clk_12_5khz;
clk_div #(594) clk_div_ps2_inst(
    .rst(rst),
    .clk_in(vga_pixel_clk_7_425mhz),
    .clk_out(ps2_clk_12_5khz)
);

// 540 Hz Chip-8 instruction clock (also used for buzzer)
wire chip8_instruction_clk_540hz;
clk_div #(13750) clk_div_chip8_instruction_inst(
    .rst(rst),
    .clk_in(vga_pixel_clk_7_425mhz),
    .clk_out(chip8_instruction_clk_540hz)
);

wire [4:0] newest_key_down;
wire clear_newest_key_down;
wire [15:0] input_keys;
// Display data (64x32, row-major)
wire [63:0] display [31:0];

// Buzzer clock, should be a comfortably audible tone
wire buzzer_clk;
assign buzzer_clk = chip8_instruction_clk_540hz;
wire buzzer;
// PWM should only be active when the game is buzzing
assign buzzer_pwm = buzzer_clk & buzzer;

// VGA graphics module
vga vga_inst(
    .rst(rst),
    .pixel_clk_7_425mhz(vga_pixel_clk_7_425mhz),
    // 2D array of black/white bits
    .display(display),
    .color(vga_color),
    .hsync(vga_hsync),
    .vsync(vga_vsync),
    .in_hblank(),
    .in_vblank()
);

// PS/2 keyboard module
ps2_kb ps2_kv_inst(
    .rst(rst),
    .clk(ps2_clk_12_5khz),
    .data_pin(ps2_data_pin),
    .clk_pin(ps2_clk_pin),
    .input_keys(input_keys),
    .clear_newest_key_down(clear_newest_key_down),
    .newest_key_down(newest_key_down)
);

// Chip-8 module
chip8 chip8_inst(
    .rst(rst),
    .instruction_clk(chip8_instruction_clk_540hz),
    .input_keys(input_keys),
    .clear_newest_key_down(clear_newest_key_down),
    .newest_key_down(newest_key_down),
    .display(display),
    .buzzer(buzzer)
);


endmodule
