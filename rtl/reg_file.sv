`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 04/22/2025 12:01:39 PM
// Design Name: 
// Module Name: reg_file
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


module reg_file(
    input logic clk,
    input logic rst,
    input logic [31:0] dataW,
    input logic [5:0] rs1,
    input logic [5:0] rs2,
    input logic [5:0] rs3,
    input logic [5:0] rsW,
    input logic regW_en,
    output logic [31:0] data1,
    output logic [31:0] data2,
    output logic [31:0] data3
    );

    logic [31:0] registers [63:0];
    
    always_ff@(negedge clk or negedge rst) begin
        if (rst==1'b0) foreach(registers[i]) registers[i] <= 32'h00000000;
        else if(regW_en) registers[rsW] <= dataW;
    end

    always_comb begin
        data1 <= rs1 ? registers[rs1] : 32'h00000000;
        data2 <= rs2 ? registers[rs2] : 32'h00000000;
        data3 <= rs3 ? registers[rs3] : 32'h00000000;
    end

endmodule
