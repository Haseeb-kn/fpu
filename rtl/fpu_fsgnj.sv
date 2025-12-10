`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// Create Date: 07/15/2025
// Design Name: 
// Module Name: fpu_fsgnj
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// Dependencies: 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////

module fpu_fsgnj(
    input  logic [31:0] rs1,
    input  logic [31:0] rs2,
    input  logic [1:0] opcode, // 00: fsgnj.s, 01: fsgnjn.s, 10: fsgnjx.s
    output logic [31:0] rd
);
    always_comb begin
        case (opcode)
            2'b00: rd = {rs2[31], rs1[30:0]}; // fsgnj.s
            2'b01: rd = {~rs2[31], rs1[30:0]}; // fsgnjn.s
            2'b10: rd = {rs1[31] ^ rs2[31], rs1[30:0]}; // fsgnjx.s
            default: rd = 32'b0;
        endcase
    end
endmodule
