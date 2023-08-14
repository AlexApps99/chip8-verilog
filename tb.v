`timescale 1us/1us

module tb;

reg rst;
reg chip8_instruction_clk_540hz;

wire [15:0] input_keys;
assign input_keys = 16'b0;
wire [4:0] newest_key_down;
assign newest_key_down = 5'd16;
wire [63:0] display [31:0];
wire buzzer;


// Chip-8 module
chip8 chip8_inst(
    .rst(rst),
    .instruction_clk(chip8_instruction_clk_540hz),
    .input_keys(input_keys),
    .clear_newest_key_down(),
    .newest_key_down(newest_key_down),
    .display(display),
    .buzzer(buzzer)
);

initial begin: tb_block
    integer i;


    chip8_instruction_clk_540hz = 0;
    rst = 0;
    #926
    rst = 1;
    #926

    rst = 0;
    #926

    // hack
    $readmemh("character_data.hex", chip8_inst.memory, 80, 80 + 80 - 1);
    $readmemh("ibm.ch8.hex", chip8_inst.memory, 512);
    $display("PC:%H OP:%H VN:%H I:%H SP:%H", chip8_inst.PC, chip8_inst.op, chip8_inst.VN[0], chip8_inst.I, chip8_inst.stack_pointer);

    #926

    for (i = 0; i < 5000; i = i + 1) begin
        #926
        chip8_instruction_clk_540hz = 1;

        #926

        $display("PC:%H OP:%H VN:%H I:%H SP:%H", chip8_inst.PC, chip8_inst.op, chip8_inst.VN[0], chip8_inst.I, chip8_inst.stack_pointer);

        chip8_instruction_clk_540hz = 0;
    end

end

endmodule
