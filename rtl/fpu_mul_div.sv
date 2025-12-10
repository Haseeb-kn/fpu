`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 07/09/2025 04:08:14 PM
// Design Name: 
// Module Name: fpu_mul_div
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


module fpu_mul_div(
    input logic clk, rst, start,
    input logic mul0_div1,
    input logic [2:0] frm, // rounding mode
    input logic [31:0] operA_float32,
    input logic [31:0] operB_float32,
    output logic [31:0] result, 
    output logic flag_nx, done
    );
    
    logic mul_done, div_done;
    logic flag_nx_mul, flag_nx_div;
    logic [31:0] mul_result, div_result;

    fpu_mul F_MUL(.start(start & ~mul0_div1), .done(mul_done), .result(mul_result), .flag_nx(flag_nx_mul), .*);
    fpu_div F_DIV(.start_i(start & mul0_div1),  .valid(div_done), .y(div_result), .nx(flag_nx_div), .a(operA_float32), .b(operB_float32), .reset_i(rst), .clk_i(clk), .frm);

    always_comb begin
        done = 1'b0;
        result = 32'd0;
        case(mul0_div1)
            1'b0: begin
                done = mul_done;
                result = mul_result;
            end
            1'b1: begin
                done = div_done;
                result = div_result;
            end
            default: begin
                done = 1'b0;
                result = 32'd0;
            end
        endcase
    end

   
endmodule



