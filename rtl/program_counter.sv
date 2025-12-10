`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 04/22/2025 12:00:37 PM
// Design Name: 
// Module Name: program_counter
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


module program_counter(
    input logic clk,
    input logic rst,
    input logic en,
    input logic load_en,
    input logic [31:0] load_val,
    output logic [31:0] pc_next,
    output logic [31:0] pc_curr
    );

    always_ff@(posedge clk or negedge rst) begin
        if(rst==1'b0) pc_curr <= 32'h80000000;
        else begin
            if (load_en) pc_curr <= load_val;
            else if(en) pc_curr <= pc_next;
        end
    end

    assign pc_next = pc_curr + 4;

endmodule
