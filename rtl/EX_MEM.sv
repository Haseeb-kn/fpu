`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 05/02/2025 11:05:52 AM
// Design Name: 
// Module Name: EX_MEM
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


module EX_MEM (
    input clk, rst, en, flush,

    input logic [31:0] pc_curr_EX,
    input logic [31:0] ALUout_EX,
    input logic [31:0] csr_data_r_EX,
    input logic [31:0] csr_data_out_EX,
    input logic [31:0] rs2_EX,
    input logic [31:0] inst_EX,

    input logic [11:0] csr_address_EX,
    input logic [2:0] func3_EX,
    input logic [1:0] WBsel_EX,
    input logic rsW_float_EX, //
    input logic float_inst_EX, //
    input logic csrWBsel_EX, regW_en_EX, memW_en_EX, jump_EX, csrW_en_EX, valid_branch_EX,

    output logic [31:0] pc_curr_MEM,
    output logic [31:0] ALUout_MEM,
    output logic [31:0] csr_data_r_MEM,
    output logic [31:0] csr_data_out_MEM,
    output logic [31:0] rs2_MEM,
    output logic [31:0] inst_MEM,

    output logic [11:0] csr_address_MEM,
    output logic [2:0] func3_MEM,
    output logic [1:0] WBsel_MEM,
    output logic rsW_float_MEM, //
    output logic float_inst_MEM, //
    output logic csrWBsel_MEM, regW_en_MEM, memW_en_MEM, jump_MEM, csrW_en_MEM, valid_branch_MEM
    );

    always_ff @(posedge clk or negedge rst) begin
        if(!rst) begin
            pc_curr_MEM <= 0;
            ALUout_MEM <= 0;
            csr_data_r_MEM <= 0;
            csr_data_out_MEM <= 0;
            rs2_MEM <= 0;
            inst_MEM <= 32'h00000013;

            csr_address_MEM <= 0;
            func3_MEM <= 0;
            WBsel_MEM <= 1;
            rsW_float_MEM <= 0; //
            float_inst_MEM <= 0; //
            csrWBsel_MEM <= 0;
            regW_en_MEM <= 0;
            memW_en_MEM <= 0;
            jump_MEM <= 0;
            csrW_en_MEM <= 0;
            valid_branch_MEM <= 0;
        end else begin
            if(en) begin
                pc_curr_MEM <= pc_curr_EX;
                ALUout_MEM <= ALUout_EX;
                csr_data_r_MEM <= csr_data_r_EX;
                csr_data_out_MEM <= csr_data_out_EX;
                rs2_MEM <= rs2_EX;
                inst_MEM <= inst_EX;

                csr_address_MEM <= csr_address_EX;
                func3_MEM <= func3_EX;
                WBsel_MEM <= WBsel_EX;
                rsW_float_MEM <= rsW_float_EX; //
                float_inst_MEM <= float_inst_EX; //
                csrWBsel_MEM <= csrWBsel_EX;
                regW_en_MEM <= regW_en_EX;
                memW_en_MEM <= memW_en_EX;
                jump_MEM <= jump_EX;
                csrW_en_MEM <= csrW_en_EX;
                valid_branch_MEM <= valid_branch_EX;
            end
            if(flush) begin
                pc_curr_MEM <= 0;
                ALUout_MEM <= 0;
                csr_data_r_MEM <= 0;
                csr_data_out_MEM <= 0;
                rs2_MEM <= 0;
                inst_MEM <= 32'h00000013;

                csr_address_MEM <= 0;
                func3_MEM <= 0;
                WBsel_MEM <= 1;
                rsW_float_MEM <= 0; //
                float_inst_MEM <= 0; //
                csrWBsel_MEM <= 0;
                regW_en_MEM <= 0;
                memW_en_MEM <= 0;
                jump_MEM <= 0;
                csrW_en_MEM <= 0;
                valid_branch_MEM <= 0;
            end 
        end
    end

endmodule
