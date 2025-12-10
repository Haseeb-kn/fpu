`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 04/22/2025 12:01:39 PM
// Design Name: 
// Module Name: alu_logic
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


module alu_logic(
    input logic clk, rst,
    input logic float_inst, // indicates if the instruction is a floating point operation
    input logic signed [31:0] data1,
    input logic signed [31:0] data2,
    input logic signed [31:0] data3,
    input logic [4:0] ALUsel, // func3 = ALUsel[2:0], func7[5] = ALUsel[3], func7[0] = ALUsel[4]
    input logic [2:0] f_rm,
    output logic [31:0] ALUout,
    output logic [4:0] f_flags,
    output logic done
    );

    logic [31:0] temp1;
    logic [31:0] temp2;

    logic [31:0] im_ALUout; 
    logic [31:0] f_ALUout;

    logic [31:0] mulout;
    logic mul_start;
    logic mul_done;
    logic fpu_start;

    logic [31:0] quotient;
    logic [31:0] remainder;
    logic div_start;
    logic div_done;

    logic im_done;
    logic fpu_done;

    assign temp1 = data1;
    assign temp2 = data2;

    mul_2cycle mul_inst(
        .clk, 
        .rst, 
        .start(mul_start), // Not used in this context
        .operA(data1),      // operA is data1
        .operB(data2),      // operB is data2
        .func3({1'b0, ALUsel[1:0]}), // func3 input to select multiply
        .done(mul_done),            // done signal not used here
        .result(mulout)     // result is the output of the multiplier
    );

    divider div_inst(
            .clk_i(clk),
            .reset_i(rst),
            .sign_i(~ALUsel[0]),
            .stall_i(1'b0), // stall_i is not used in this context
            .start_i(div_start),
            .dividend_i(data1), 
            .divider_i(data2),

            .quotient_o(quotient), 
            .remainder_o(remainder),
            .valid_o(div_done) // valid_o indicates if the division is done
    );
    
    always_comb begin
        im_ALUout = 32'h00000000;
        mul_start = 1'b0; // Default case, no multiplication
        div_start = 1'b0; // Default case, no division
        im_done = 1'b1; // Indicate done for default case
        case({ALUsel[4], ALUsel[2:0]})
            4'b0_000: im_ALUout = ALUsel[3] ? data1 - data2 : data1 + data2;             // sub/add
            4'b0_001: im_ALUout = ALUsel[3] ? data2 : data1 << data2[4:0];               // bypass data2 (for lui) / sll
            4'b0_010: im_ALUout = ALUsel[3] ? data1 : ((data1 < data2) ? 1 : 0);         // bypass data1 (for csr) / slt
            4'b0_011: im_ALUout = (temp1 < temp2) ? 1 : 0;                               // sltu
            4'b0_100: im_ALUout = data1 ^ data2;                                         // xor
            4'b0_101: im_ALUout = ALUsel[3] ? data1 >>> data2[4:0] : data1 >> data2[4:0];// sra/srl
            4'b0_110: im_ALUout = data1 | data2;                                         // or
            4'b0_111: im_ALUout = data1 & data2;                                         // and

            4'b1_000, // mul
            4'b1_001, // mulh
            4'b1_010, // mulhsu
            4'b1_011: begin im_ALUout = mulout;    mul_start = ~mul_done & ~float_inst; im_done = mul_done; end    // mulhu
            4'b1_100: begin im_ALUout = quotient;  div_start = ~div_done & ~float_inst; im_done = div_done; end    // div 
            4'b1_101: begin im_ALUout = quotient;  div_start = ~div_done & ~float_inst; im_done = div_done; end    // divu   
            4'b1_110: begin im_ALUout = remainder; div_start = ~div_done & ~float_inst; im_done = div_done; end    // rem                  
            4'b1_111: begin im_ALUout = remainder; div_start = ~div_done & ~float_inst; im_done = div_done; end    // remu                                                                      
            default: begin
                im_ALUout = 32'h00000000;
                mul_start = 1'b0; // Default case, no multiplication
                div_start = 1'b0; // Default case, no division
                im_done = 1'b1; // Indicate done for default case
            end
        endcase
    end

    assign fpu_start = float_inst & ~fpu_done;

    fpu_alu FPU (
        .clk, .rst, .start(fpu_start),
        .frm(f_rm), // rounding mode
        .ALUsel,
        .operA_float32(data1),
        .operB_float32(data2),
        .operC_float32(data3),
        .result(f_ALUout),
        .f_flags,
        .done(fpu_done)
    );

    assign ALUout = float_inst ? f_ALUout : im_ALUout; 
    assign done = float_inst ? fpu_done : im_done;
    
endmodule
