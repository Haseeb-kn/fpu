`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 05/02/2025 11:06:42 AM
// Design Name: 
// Module Name: MEM_WB
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


module MEM_WB  (
    input clk, rst, en,

    input logic [31:0] pc_next_MEM,
    input logic [31:0] ALUout_MEM,
    input logic [31:0] csr_data_r_MEM,
    input logic [31:0] csr_data_out_MEM,
    input logic [31:0] d_mem_out_MEM,
    input logic [31:0] inst_MEM,

    input logic [11:0] csr_address_MEM,
    input logic [1:0] WBsel_MEM,
    input logic rsW_float_MEM,
    input logic float_inst_MEM,
    input logic csrWBsel_MEM, regW_en_MEM, csrW_en_MEM,

    output logic [31:0] pc_next_WB,
    output logic [31:0] ALUout_WB,
    output logic [31:0] csr_data_r_WB,
    output logic [31:0] csr_data_out_WB,
    output logic [31:0] d_mem_out_WB,
    output logic [31:0] inst_WB,

    output logic [11:0] csr_address_WB,
    output logic [1:0] WBsel_WB,
    output logic rsW_float_WB,
    output logic float_inst_WB,
    output logic regW_en_WB,
    output logic csrW_en_WB,
    output logic csrWBsel_WB
    );

    always_ff @(posedge clk or negedge rst) begin
        if(!rst) begin
            pc_next_WB <= 0;
            ALUout_WB <= 0;
            csr_data_r_WB <= 0;
            csr_data_out_WB <= 0;
            d_mem_out_WB <= 0;
            inst_WB <= 32'h00000013;

            csr_address_WB <= 0;
            WBsel_WB <= 1;
            rsW_float_WB <= 0;
            float_inst_WB <= 0;
            regW_en_WB <= 0;
            csrW_en_WB <= 0;
            csrWBsel_WB <= 0;
        end else if (en) begin
            pc_next_WB <= pc_next_MEM;
            ALUout_WB <= ALUout_MEM;
            csr_data_r_WB <= csr_data_r_MEM;
            csr_data_out_WB <= csr_data_out_MEM;
            d_mem_out_WB <= d_mem_out_MEM;
            inst_WB <= inst_MEM;

            csr_address_WB <= csr_address_MEM;
            WBsel_WB <= WBsel_MEM;
            rsW_float_WB <= rsW_float_MEM;
            float_inst_WB <= float_inst_MEM;
            regW_en_WB <= regW_en_MEM;
            csrW_en_WB <= csrW_en_MEM;
            csrWBsel_WB <= csrWBsel_MEM;
        end
    end
endmodule
