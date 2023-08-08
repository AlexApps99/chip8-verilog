`include "rng.v"
`include "bcd.v"

// TODO one clock for instructions, another clock for waiting for next frame?
module chip8 (
    input wire rst,
    // Pulses at 60 * 9 Hz per instruction?
    input wire instruction_clk,
    // Pulses at 60 Hz
    input wire frame_clk,
    input wire [15:0] input_keys,
    input wire [4:0] newest_key_down,
    // Display data (64x32, row-major)
    output reg [2047:0] display,
    output wire buzzer
);

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

// For input change detection
reg block_for_input;
reg [4:0] last_newest_key_down;

assign buzzer = (sound_timer != 8'b0);

wire [7:0] rand;
rng rng_inst (
    .clk(timer_clk),
    .rst(rst),
    .x(rand)
);

initial begin: begin_init
    integer i, j;

    // Clear display
    display <= 'b0;

    // Clear and initialize memory
    for (i = 0; i < 4096; i = i + 1) begin
        memory[i] <= 8'b0;
    end
    $readmemh("character_data.hex", memory, 80);
    $readmemb("ibm.ch8", 512);

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

    block_for_input <= 0;
    last_newest_key_down <= 16;
end

// Synchronous logic (should avoid blocking assignment)
always @(posedge instruction_clk) begin: instruction_clk_block
    reg [7:0] byte_0, byte_1;
    reg [3:0] nibble_0, nibble_1, nibble_2, nibble_3;
    reg [15:0] op;
    integer i, bcd_i;
    // BCD Scratchspace
    reg [19:0] bcd_scr;

    byte_0 = memory[PC];
    nibble_0 = memory[PC][7:4];
    nibble_1 = memory[PC][3:0];
    byte_1 = memory[PC + 1];
    nibble_2 = memory[PC + 1][7:4];
    nibble_3 = memory[PC + 1][3:0];
    op = {byte_0, byte_1};

    // Increment the program counter, if nothing else happens
    PC <= PC + 2;

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
                    stack_pointer <= stack_pointer - 1;
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
                stack[stack_pointer] <= PC + 2;
                PC <= op[11:0];
                stack_pointer <= stack_pointer + 1;
            end
        end
        4'h3 : begin
            // Skip if VX == NN
            if (VN[nibble_1] == byte_1) begin
                PC <= PC + 4;
            end
        end
        4'h4 : begin
            // Skip if VX != NN
            if (VN[nibble_1] != byte_1) begin
                PC <= PC + 4;
            end
        end
        4'h5 : begin
            // Skip if VX == VY
            if (VN[nibble_1] == VN[nibble_2]) begin
                PC <= PC + 4;
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
                // TODO Vx += Vy (sets carry VF)
                VN[nibble_1] <= VN[nibble_1] + VN[nibble_2];
            end
            4'h5 : begin
                // TODO Vx -= Vy (sets borrow VF)
                VN[nibble_1] <= VN[nibble_1] - VN[nibble_2];
            end
            4'h6 : begin
                // TODO Vx >>= 1 (sets overflow VF)
                VN[nibble_1] <= VN[nibble_1] >> 1;
            end
            4'h7 : begin
                // TODO Vx = Vy - Vx (sets borrow VF)
                VN[nibble_1] <= VN[nibble_2] - VN[nibble_1];
            end
            4'hE : begin
                // TODO Vx <<= 1 (sets overflow VF)
                VN[nibble_1] <= VN[nibble_1] << 1;
            end
        endcase
        4'h9 : begin
            // Skip if VX != VY
            if (VN[nibble_1] != VN[nibble_2]) begin
                PC <= PC + 4;
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
            VN[nibble_1] <= (rand & byte_1);
        end
        4'hD : begin
            // TODO Draw (sets VF)
        end
        4'hE : case (byte_1)
            8'h9E : begin
                // Skip if key in VX is pressed
                if ((input_keys & (1 << VN[nibble_1])) != 0) begin
                    PC <= PC + 4;
                end
            end
            8'hA1 : begin
                // Skip if key in VX is not pressed
                if ((input_keys & (1 << VN[nibble_1])) == 0) begin
                    PC <= PC + 4;
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
                if (block_for_input != 0 && newest_key_down != last_newest_key_down && newest_key_down != 16) begin
                    VN[nibble_1] <= newest_key_down;
                    block_for_input <= 0;
                    last_newest_key_down <= 16;
                end else begin
                    block_for_input <= 1;
                    last_newest_key_down <= newest_key_down;
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
                I <= 80 + ((4'hF & VN[nibble_1]) * 5);
            end
            8'h33 : begin
                // BCD

                // I don't really like the kludginess that comes from just dumping this in a switch case.
                // I'm also not sure how safe mixing blocking/non-blocking assignments is.
                bcd_scr = VN[nibble_1] << 1;

                for (bcd_i = 0; bcd_i < 7; bcd_i = bcd_i + 1) begin
                    if (bcd_scr[11:8] >= 5) begin
                        bcd_scr[11:8] = bcd_scr[11:8] + 3;
                    end

                    if (bcd_scr[15:12] >= 5) begin
                        bcd_scr[15:12] = bcd_scr[15:12] + 3;
                    end

                    if (bcd_scr[19:16] >= 5) begin
                        bcd_scr[19:16] = bcd_scr[19:16] + 3;
                    end

                    bcd_scr = bcd_scr << 1;
                end
                memory[I] <= bcd_scr[8 +: 4];
                memory[I+1] <= bcd_scr[12 +: 4];
                memory[I+2] <= bcd_scr[16 +: 4];
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

//always @(posedge frame_clk) begin: frame_block
//    if (delay_timer != 8'b0) begin
//        delay_timer <= delay_timer - 1;
//    end
//    if (sound_timer != 8'b0) begin
//        sound_timer <= sound_timer - 1;
//    end
//end

always @(posedge rst) begin: rst_block
    // TODO combine with the clock one, and initialize everything?
end

//always @* begin
//end

endmodule