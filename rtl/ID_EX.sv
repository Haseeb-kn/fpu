`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 05/02/2025 11:04:04 AM
// Design Name: 
// Module Name: ID_EX
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


module ID_EX  (
    input clk, rst, en, flush,

    input logic [31:0] pc_curr_ID,
    input logic [31:0] rs1_ID,
    input logic [31:0] rs2_ID,
    input logic [31:0] rs3_ID,
    input logic [31:0] imm_ex_out_ID,
    input logic [31:0] inst_ID,
    input logic [31:0] csr_data_r_ID,

    output logic [31:0] pc_curr_EX,
    output logic [31:0] rs1_EX,
    output logic [31:0] rs2_EX,
    output logic [31:0] rs3_EX,
    output logic [31:0] imm_ex_out_EX,
    output logic [31:0] inst_EX,
    output logic [31:0] csr_data_r_EX,

    // control signals
    input logic [11:0] csr_address_ID,
    input logic [4:0] ALUsel_ID,
    input logic [1:0] WBsel_ID,
    input logic float_inst_ID,
    input logic rs1_float_ID, rs2_float_ID, rsW_float_ID, // used for fpu
    input logic csrWBsel_ID, regW_en_ID, Bsel_ID, memW_en_ID, jump_ID, Asel_ID, csrW_en_ID,

    output logic [11:0] csr_address_EX,
    output logic [4:0] ALUsel_EX,
    output logic [1:0] WBsel_EX,
    output logic float_inst_EX,
    output logic rs1_float_EX, rs2_float_EX, rsW_float_EX, // used for fpu
    output logic csrWBsel_EX, regW_en_EX, Bsel_EX, memW_en_EX, jump_EX, Asel_EX, csrW_en_EX
    );

    always_ff @( posedge clk or negedge rst ) begin
        if(!rst) begin
            pc_curr_EX <= 0;
            rs1_EX <= 0;
            rs2_EX <= 0;
            rs3_EX <= 0;
            imm_ex_out_EX <= 0;
            inst_EX <= 32'h00000013;
            csr_data_r_EX <= 32'd0;

            csr_address_EX <= 0;
            jump_EX <= 0;
            regW_en_EX <= 0;
            ALUsel_EX <= 0;
            float_inst_EX <= 0;
            rs1_float_EX <= 0;
            rs2_float_EX <= 0;
            rsW_float_EX <= 0;
            csrWBsel_EX <= 0;
            WBsel_EX <= 1;
            Bsel_EX <= 0;
            memW_en_EX <= 0;
            Asel_EX <= 0;
            csrW_en_EX <= 0;
        end else begin
            if(en) begin
                pc_curr_EX <= pc_curr_ID;
                rs1_EX <= rs1_ID;
                rs2_EX <= rs2_ID;
                rs3_EX <= rs3_ID;
                imm_ex_out_EX <= imm_ex_out_ID;
                inst_EX <= inst_ID;
                csr_data_r_EX <= csr_data_r_ID;

                csr_address_EX <= csr_address_ID;
                jump_EX <= jump_ID;
                regW_en_EX <= regW_en_ID;
                ALUsel_EX <= ALUsel_ID;
                float_inst_EX <= float_inst_ID;
                rs1_float_EX <= rs1_float_ID;
                rs2_float_EX <= rs2_float_ID;
                rsW_float_EX <= rsW_float_ID;
                csrWBsel_EX <= csrWBsel_ID;
                WBsel_EX <= WBsel_ID;
                Bsel_EX <= Bsel_ID;
                memW_en_EX <= memW_en_ID;
                Asel_EX <= Asel_ID;
                csrW_en_EX <= csrW_en_ID;
            end
            if(flush) begin
                pc_curr_EX <= 0;
                rs1_EX <= 0;
                rs2_EX <= 0;
                rs3_EX <= 0;
                imm_ex_out_EX <= 0;
                inst_EX <= 32'h00000013;
                csr_data_r_EX <= 32'd0;

                csr_address_EX <= 0;
                jump_EX <= 0;
                regW_en_EX <= 0;
                ALUsel_EX <= 0;
                float_inst_EX <= 0;
                rs1_float_EX <= 0;
                rs2_float_EX <= 0;
                rsW_float_EX <= 0;
                csrWBsel_EX <= 0;
                WBsel_EX <= 1;
                Bsel_EX <= 0;
                memW_en_EX <= 0;
                Asel_EX <= 0;
                csrW_en_EX <= 0;
            end 
        end
    end

endmodule
