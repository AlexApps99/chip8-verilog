//`include "rng.v"
//`include "bcd.v"

module chip8 (
    input wire rst,
    // Pulses at 60 * 9 Hz per instruction?
    input wire instruction_clk,
    // Pulses at 60 Hz
    input wire frame_clk,
    input wire [15:0] input_keys,
    output reg clear_newest_key_down,
    input wire [4:0] newest_key_down,
    // Display data (64x32, row-major)
    output reg [2047:0] display,
    output wire buzzer
);

// Double-dabble BCD algorithm for a byte, returning a byte for each 10s digit
// [hundreds (byte, 0-9)][tens (byte, 0-9)][ones (byte, 0-9)]
function [23:0] bcd_from_byte(input [7:0] num);
    begin: bcd_scr_function_inner
        integer bcd_i;
        reg [19:0] bcd_scr;
        bcd_scr = num << 1;
        for (bcd_i = 0; bcd_i < 7; bcd_i = bcd_i + 1) begin
            if (bcd_scr[11:8] >= 5) begin
                bcd_scr[11:8] = bcd_scr[11:8] + 4'h3;
            end

            if (bcd_scr[15:12] >= 5) begin
                bcd_scr[15:12] = bcd_scr[15:12] + 4'h3;
            end

            if (bcd_scr[19:16] >= 5) begin
                bcd_scr[19:16] = bcd_scr[19:16] + 4'h3;
            end

            bcd_scr = bcd_scr << 1;
        end
        bcd_from_byte = {4'b0, bcd_scr[16 +: 4], 4'b0, bcd_scr[12 +: 4], 4'b0, bcd_scr[8 +: 4]};
    end
endfunction

localparam STACK_SIZE = 16;

// RAM (note that the first 512 bytes are unused)
reg [7:0] memory [4095:0];

// 16 8-bit registers V0 to VF
reg [7:0] VN [15:0];

// Stack, has 16 addresses
reg [11:0] stack [STACK_SIZE-1:0];

// Stack pointer (points to the first empty slot of the stack)
reg [$clog2(STACK_SIZE+1)-1:0] stack_pointer;

// Address register I
reg [11:0] I;

// Program counter
reg [11:0] PC;

// Delay timers, decremented at 60Hz until zero
reg [7:0] delay_timer;
reg [7:0] sound_timer;

assign buzzer = (sound_timer != 8'b0);

wire [7:0] rand_num;
rng rng_inst (
    .clk(instruction_clk),
    .rst(rst),
    .x(rand_num)
);

initial begin: begin_init
    integer i;

    // Clear display
    display <= 'b0;

    // Clear and initialize memory
    for (i = 0; i < 4096; i = i + 1) begin
        memory[i] <= 8'b0;
    end
    $readmemh("character_data.hex", memory, 80, 80 + 64);
    $readmemh("ibm.ch8.hex", memory, 512);

    for (i = 0; i < 16; i = i + 1) begin
        VN[i] <= 8'b0;
    end

    for (i = 0; i < 16; i = i + 1) begin
        stack[i] <= 12'b0; 
    end

    stack_pointer <= 4'b0;
    I <= 12'b0;
    PC <= 512;
    delay_timer <= 8'b0;
    sound_timer <= 8'b0;

    clear_newest_key_down <= 0;
end

wire [15:0] op;
wire [7:0] byte_0, byte_1;
wire [3:0] nibble_0, nibble_1, nibble_2, nibble_3;
assign byte_0 = memory[PC];
assign byte_1 = memory[PC + 1];
assign nibble_0 = byte_0[7:4];
assign nibble_1 = byte_0[3:0];
assign nibble_2 = byte_1[7:4];
assign nibble_3 = byte_1[3:0];
assign op = {byte_0, byte_1};


// Synchronous logic (should avoid blocking assignment)
always @(posedge rst or posedge instruction_clk) begin: instruction_clk_block
    integer i;


    // Increment the program counter, if nothing else happens
    PC <= PC + 12'h2;

    case (nibble_0)
        4'h0 : case (op)
            16'hE0 : begin
                // Clear display
                display <= 'b0;
            end
            16'hEE : begin
                // Return from subroutine
                if (stack_pointer <= STACK_SIZE) begin
                    PC <= stack[stack_pointer-1];
                    stack_pointer <= stack_pointer - 1'b1;
                end
            end
        endcase
        4'h1 : begin
            // Jump
            PC <= op[11:0];
        end
        4'h2 : begin
            // Call subroutine
            if (stack_pointer < STACK_SIZE) begin
                stack[stack_pointer] <= PC + 12'h2;
                PC <= op[11:0];
                stack_pointer <= stack_pointer + 1'b1;
            end
        end
        4'h3 : begin
            // Skip if VX == NN
            if (VN[nibble_1] == byte_1) begin
                PC <= PC + 12'h4;
            end
        end
        4'h4 : begin
            // Skip if VX != NN
            if (VN[nibble_1] != byte_1) begin
                PC <= PC + 12'h4;
            end
        end
        4'h5 : begin
            // Skip if VX == VY
            if (VN[nibble_1] == VN[nibble_2]) begin
                PC <= PC + 12'h4;
            end
        end
        4'h6 : begin
            // Set VX to NN
            VN[nibble_1] <= byte_1;
        end
        4'h7 : begin
            // Add NN to VX, not touching carry flag
            VN[nibble_1] <= VN[nibble_1] + byte_1;
        end
        4'h8 : case (nibble_3)
            4'h0 : begin
                // Vx = Vy
                VN[nibble_1] <= VN[nibble_2];
            end
            4'h1 : begin
                // Vx |= Vy
                VN[nibble_1] <= VN[nibble_1] | VN[nibble_2];
            end
            4'h2 : begin
                // Vx &= Vy
                VN[nibble_1] <= VN[nibble_1] & VN[nibble_2];
            end
            4'h3 : begin
                // Vx ^= Vy
                VN[nibble_1] <= VN[nibble_1] ^ VN[nibble_2];
            end
            4'h4 : begin
                // x += Vy (sets carry VF)
                {VN[15], VN[nibble_1]} <= VN[nibble_1] + VN[nibble_2];
            end
            4'h5 : begin
                // Vx -= Vy (sets borrow VF)
                VN[nibble_1] <= VN[nibble_1] - VN[nibble_2];
                VN[15] <= (VN[nibble_1] >= VN[nibble_2]);
            end
            4'h6 : begin
                // Vx >>= 1 (sets overflow VF)
                VN[nibble_1] <= VN[nibble_1] >> 1;
                VN[15] <= VN[nibble_1][0];
            end
            4'h7 : begin
                // Vx = Vy - Vx (sets borrow VF)
                VN[nibble_1] <= VN[nibble_2] - VN[nibble_1];
                VN[15] <= (VN[nibble_2] >= VN[nibble_1]);
            end
            4'hE : begin
                // Vx <<= 1 (sets overflow VF)
                VN[nibble_1] <= VN[nibble_1] << 1;
                VN[15] <= VN[nibble_1][7];
            end
        endcase
        4'h9 : begin
            // Skip if VX != VY
            if (VN[nibble_1] != VN[nibble_2]) begin
                PC <= PC + 12'h4;
            end
        end
        4'hA : begin
            // Sets I to address NNN
            I <= op[11:0];
        end
        4'hB : begin
            // Jumps to address NNN + V0
            PC <= VN[0] + op[11:0];
        end
        4'hC : begin
            // RNG
            VN[nibble_1] <= (rand_num & byte_1);
        end
        4'hD : begin
            // TODO Draw (sets VF)
        end
        4'hE : case (byte_1)
            8'h9E : begin
                // Skip if key in VX is pressed
                if ((input_keys & (1 << VN[nibble_1])) != 0) begin
                    PC <= PC + 12'h4;
                end
            end
            8'hA1 : begin
                // Skip if key in VX is not pressed
                if ((input_keys & (1 << VN[nibble_1])) == 0) begin
                    PC <= PC + 12'h4;
                end
            end
        endcase
        4'hF : case (byte_1)
            8'h07 : begin
                // VX = delay_timer
                VN[nibble_1] <= delay_timer;
            end
            8'h0A : begin
                // Block for key press, then store in VX
                if (clear_newest_key_down != 0 && newest_key_down < 16) begin
                    VN[nibble_1] <= newest_key_down;
                    clear_newest_key_down <= 0;
                end else begin
                    clear_newest_key_down <= 1;
                    // Don't move on yet
                    PC <= PC;
                end
            end
            8'h15 : begin
                // delay_timer = VX
                delay_timer <= VN[nibble_1];
            end
            8'h18 : begin
                // sound_timer = VX
                sound_timer <= VN[nibble_1];
            end
            8'h1E : begin
                // I += VX
                I <= I + VN[nibble_1];
            end
            8'h29 : begin
                // I = sprite_addr of hex character
                I <= 12'd80 + (8'd5 * VN[nibble_1][3:0]);
            end
            8'h33 : begin
                // BCD
                {memory[I], memory[I+1], memory[I+2]} <= bcd_from_byte(VN[nibble_1]);
            end
            8'h55 : begin
                // Stores V0 to VX to memory from I
                for (i = 0; i <= nibble_1; i = i + 1) begin
                    memory[I + i] <= VN[i];
                end
                //memory[I +: nibble_1] <= VN[0 +: nibble_1];
            end
            8'h65 : begin
                // Fills V0 to VX with memory from I
                for (i = 0; i <= nibble_1; i = i + 1) begin
                    VN[i] <= memory[I + i];
                end
                //VN[0 +: nibble_1] <= memory[I +: nibble_1];
            end
        endcase
    endcase
end

always @(posedge frame_clk) begin: frame_block
    if (delay_timer != 8'b0) begin
        delay_timer <= delay_timer - 1;
    end
    if (sound_timer != 8'b0) begin
        sound_timer <= sound_timer - 1;
    end
end

endmodule
