`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 04/25/2025 02:20:01 PM
// Design Name: 
// Module Name: control
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


// fpu internal enconding for ALUsel
// // INST       - ALUsel
// // // // // // // // // 
// // fmadd.s    = 5'b11001
// // fmsub.s    = 5'b11011
// // fnmsub.s   = 5'b11101
// // fnmadd.s   = 5'b11111
// // fadd.s     = 5'b00000
// // fsub.s     = 5'b00001
// // fmul.s     = 5'b00010
// // fdiv.s     = 5'b00011
// // fsqrt.s    = 5'b01011
// // fsgnj.s    = 5'b00110
// // fsgnjn.s   = 5'b00111
// // fsgnjx.s   = 5'b01000
// // fmin.s     = 5'b01010
// // fmax.s     = 5'b01001
// // fcvt.w.s   = 5'b01101
// // fcvt.wu.s  = 5'b01100
// // fmv.x.w    = 5'b01010 << bypass rs1 using integer ALU
// // feq.s      = 5'b10000
// // flt.s      = 5'b01111
// // fle.s      = 5'b01110
// // fclass.s   = 5'b10001
// // fcvt.s.w   = 5'b10011
// // fcvt.s.wu  = 5'b10101
// // fmv.w.x    = 5'b01010 << bypass rs1 using integer ALU

// for float instructions imALU0_FPU1 is high which selects the fpu_alu module
// ALUsel is then used by fpu_alu to select the operation

module control(
    input logic [31:0] instruction,
    output logic [11:0] csr_address, // use for fcsr --- inst[31:20], except for the case of float instruction
    output logic [4:0] ALUsel,
    output logic [1:0] WBsel,
    output logic imALU0_FPU1, csrWBsel, regW_en, Bsel, memW_en, jump, Asel, csrW_en,
    output logic rs1_float, rs2_float, rsW_float // used for fpu // if 1, then rs1, rs2, rsW are float registers
    );

    logic [2:0] func3;
    logic [6:0] func7;
    logic [6:0] opcode;
    
    assign func3 = instruction[14:12];
    assign func7 = instruction[31:25];
    assign opcode = instruction[6:0];

    always_comb begin
        Asel = 1'b0;
        Bsel = 1'b0;
        memW_en = 1'b0;
        regW_en = 1'b0;
        csrWBsel = 1'b0;
        jump = 1'b0;
        imALU0_FPU1 = 1'b0; // used to tell csrc to update flags and for csr forwarding // also to select ALU or FPU
        ALUsel = 5'b00000; // default to add
        WBsel = 1'b1; // default to read ALUout
        csrW_en = 1'b0; // default to not write to csr
        rs1_float = 1'b0; // rs1 is float
        rs2_float = 1'b0; // rs2 is float
        rsW_float = 1'b0; // rsW is float
        csr_address = 0;
        case(opcode)
            // r-type
            7'b0110011: begin
                if(~func7[0]) begin
                    // r-type
                    regW_en = 1'b1;
                    ALUsel = {1'b0 , func7[5], func3};
                    WBsel = 1;
                end else begin
                    // Multiplication and Division
                    regW_en = 1'b1; // write back to reg
                    ALUsel = {1'b1, func7[5], func3};
                    WBsel = 1; // read ALUout
                end                
            end
            // i-rtype
            7'b0010011: begin
                regW_en = 1'b1;
                Bsel = 1'b1;
                // addi x1, x0, -4 <--- !!! done
                ALUsel = (func3) ? {1'b0, func7[5], func3} : {2'b0, func3};
                WBsel = 1;
            end
            // load
            7'b0000011: begin
                regW_en = 1'b1; // write to reg
                Bsel = 1'b1; // select imm
                ALUsel = 5'b00000; // add
                WBsel = 0; // read from dmem
            end
            // store
            7'b0100011: begin
                regW_en = 1'b0; // write to reg
                Bsel = 1'b1; // select imm
                ALUsel = 5'b00000; // add
                WBsel = 1; // this should not be zero --- for lw data hazard
                memW_en = 1'b1; // <<-- unchecked in tb
            end
            // jal
            7'b1101111: begin
                regW_en = 1'b1;
                Bsel = 1'b1;
                ALUsel = 5'b00000; // add pc+imm
                WBsel = 2; // read pc+4
                jump = 1'b1;
                Asel = 1'b1; // sel pc as alu input
            end
            // jalr
            7'b1100111: begin
                regW_en = 1'b1;
                Bsel = 1'b1;
                ALUsel = 5'b00000; // add rs1+imm
                WBsel = 2; // read pc+4
                jump = 1'b1;
            end
            // branch
            7'b1100011: begin
                Bsel = 1'b1; // select imm
                ALUsel = 5'b00000; // add rs1+imm
                WBsel = 2; // read pc+4 (dont care)?
                Asel = 1'b1; // sel pc as alu input (Asel)
            end
            // lui
            7'b0110111: begin
                regW_en = 1'b1; // write back to reg
                Bsel = 1'b1; // select imm
                ALUsel = 5'b01001; // bypass rs2
                WBsel = 1; // read ALUout
                Asel = 1'b1; // data1 sel (dont care?)
            end
            // auipc
            7'b0010111: begin
                regW_en = 1'b1; // write back to reg
                Bsel = 1'b1; // select imm
                ALUsel = 5'b00000; // add imm + pc_curr
                WBsel = 1; // read ALUout
                Asel = 1'b1; // pc_curr value
            end
            7'b1110011:begin // csr_instr
                csrWBsel = 1'b1;
                csr_address = instruction[31:20]; // set csr address
                csrW_en = |instruction[19:15]; // if rs1 == x0, dont write csr
                regW_en = |instruction[11:7]; // if rd == x0, dont read csr
                Bsel = 1'b0;
                ALUsel = 5'b01010; // bypass rs1
                WBsel = 3; // write back from csr_reg
                memW_en = 1'b0; // <<-- unchecked in tb
                jump = 1'b0;
                Asel = 1'b0;
            end
            7'b100_00_11, 7'b100_01_11, 7'b100_10_11, 7'b100_11_11: begin // 3 operand float instructions
                imALU0_FPU1 = 1'b1; // select FPU
                
                // these will be different for each float instruction
                rs1_float = 1'b1; // rs1 is float
                rs2_float = 1'b1; // rs2 is float
                // rs3 is always float
                rsW_float = 1'b1; // write to float register
    
                regW_en = 1'b1; // write back to reg
                Bsel = 1'b0; // select rs2
                ALUsel = {2'b11, opcode[3:2], 1'b1}; // 11xx1
                WBsel = 1; // read ALUout
                memW_en = 1'b0; 
                jump = 1'b0; // don't load pc
                Asel = 1'b0; // select rs1

                csr_address = 12'h003; // to allow the harwdare(alu) to correctly update fcsr 
                csrW_en = 1'b1; // to update flags
            end
            // float ops (2 operand op)
            7'b1010011: begin
                imALU0_FPU1 = 1'b1;
                
                // these will be different for each float instruction (to be implemented)
                rs1_float = 1'b1; // rs1 is float
                rs2_float = 1'b1; // rs2 is float
                rsW_float = 1'b1; // rsW is float
    
                regW_en = 1'b1; // write back to reg
                Bsel = 1'b0; // select rs2
                
                csr_address = 12'h003; // to allow the harwdare(alu) to correctly update fcsr 
                csrW_en = 1'b1; // to update flags

                case(func7[6:2])
                    5'b00000: ALUsel = func7[6:2];// fadd.s
                    5'b00001: ALUsel = func7[6:2];// fsub.s
                    5'b00010: ALUsel = func7[6:2];// fmul.s
                    5'b00011: ALUsel = func7[6:2];// fdiv.s
                    5'b01011: ALUsel = func7[6:2];// fsqrt.s
                    5'b00100: 
                        case(func3)
                            // internal coding
                            3'b000: ALUsel = 5'b00110; // fsgnj.s
                            3'b001: ALUsel = 5'b00111; // fsgnjn.s
                            3'b010: ALUsel = 5'b01000; // fsgnjx.s
                            default: ALUsel = 5'b00000; // default to add
                        endcase                    
                    5'b00101: ALUsel = func3[0] ? 5'b01001 : 5'b01010;// fmin.s (func3[0]=0) // fmax.s (func3[0]=1)
                    5'b11000: begin // fcvt.w.s 0(b01101) / fcvt.wu.s 1(b01100) (float to int)
                        rsW_float = 1'b0; // rsW is integer
                        ALUsel = instruction[20] ? 5'b01100 : 5'b01101;
                    end
                    5'b10100: begin // feq.s 10(5'b10000) // flt.s 01(5'b01111) // fle.s 00(5'b01110)
                        ALUsel = func3 ? (~func3[0] ? 5'b10000 : 5'b01111) : 5'b01110;
                        rsW_float = 1'b0; // rsW is integer
                    end 
                    5'b11100: begin // fmv.x.w 0(b10010) // fclass.s 1(b10001)
                        rsW_float = 1'b0; // rsW is integer for both 
                        if(func3) ALUsel = 5'b10001;
                        else begin
                            imALU0_FPU1 = 1'b0; // select integer ALU
                            ALUsel = 5'b01010; // bypass rs1 through int ALU
                            csrW_en = 1'b0; // fmv.x.w does not update fcsr
                        end
                    end
                    5'b11010: begin // fcvt.s.w 0(b10011) // fcvt.s.wu 1(b10101)
                        rs1_float = 1'b0; // rs1 is integer
                        ALUsel = instruction[20] ? 5'b10101 : 5'b10011;
                    end 
                    5'b11110: begin // fmv.w.x (integer to float)
                        rs1_float = 1'b0; // rs1 is integer
                        imALU0_FPU1 = 1'b0; // select integer ALU
                        ALUsel = 5'b01010; // bypass rs1 through int ALU
                        csrW_en = 1'b0; // fmv.w.x does not update fcsr
                    end
                endcase
                WBsel = 1; // read ALUout
                memW_en = 1'b0; // <<-- unchecked in tb
                jump = 1'b0; // don't load pc
                Asel = 1'b0; // select rs1
            end
            // f load word
            7'b0000111: begin
                imALU0_FPU1 = 1'b0; // select integer ALU to add imm to rs1
                rs1_float = 1'b0; // rs1 is int
                rsW_float = 1'b1; // rsW is float
                ALUsel = 5'b00000; // add
                regW_en = 1'b1; // write to reg
                Bsel = 1'b1; // select imm
                WBsel = 0; // read from dmem
            end
            // f store word
            7'b0100111: begin
                imALU0_FPU1 = 1'b0; // select integer ALU to add imm to rs1
                rs1_float = 1'b0; // rs1 is int
                rs2_float = 1'b1; // rs2 is float
                ALUsel = 5'b00000; // add
                regW_en = 1'b0; // no write to reg
                Bsel = 1'b1; // select imm
                WBsel = 1; // this should not be zero --- for lw data hazard
                memW_en = 1'b1; // <<-- unchecked in tb
            end
            default: begin
                // add x0 x0 x0
                regW_en = 1'b0; 
                Bsel = 1'b0;
                ALUsel = 5'b0000;
                WBsel = 1; // read from dmem
                memW_en = 1'b0; // <<-- unchecked in tb
                jump = 1'b0;
                Asel = 1'b0;
            end
        endcase
    end

endmodule

