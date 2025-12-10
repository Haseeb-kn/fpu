`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 05/05/2025 02:04:00 PM
// Design Name: 
// Module Name: hazard_detection_unit
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


module hazard_detection_unit(
    
    input logic [31:0] inst_ID,
    input logic [31:0] inst_EX,
    input logic [31:0] inst_MEM,
    input logic [31:0] inst_WB,

    input logic [11:0] csr_address_EX,
    input logic [11:0] csr_address_MEM,
    input logic [11:0] csr_address_WB,
    
    input logic rs1_float, rs2_float,
    input logic rs1_float_EX, rs2_float_EX, rsW_float_EX,
    input logic rsW_float_MEM, rsW_float_WB, 
    input logic float_inst_MEM, float_inst_WB,
    input logic csrW_en_MEM, csrW_en_WB,
    input logic regW_en_MEM, regW_en_WB, load_pc, done,
    input logic [1:0] WBsel_EX,

    output logic [1:0] fwd_csr,
 
    output logic [1:0] fwd_A,
    output logic [1:0] fwd_B,
    output logic [1:0] fwd_C,
    output logic pc_en, IF_ID_en, ID_EX_en, EX_MEM_en, MEM_WB_en,

    output logic IF_ID_flush,
    output logic ID_EX_flush,
    output logic EX_MEM_flush
    );

    logic [5:0] rs1_ID;
    logic [5:0] rs2_ID;
    logic [5:0] rs3_ID;

    logic [5:0] rs1_EX;
    logic [5:0] rs2_EX;
    logic [5:0] rs3_EX;

    logic [5:0] rsW_EX;
    logic [5:0] rsW_WB;
    logic [5:0] rsW_MEM;

    assign rs1_ID = {rs1_float, inst_ID[19:15]};
    assign rs2_ID = {rs2_float, inst_ID[24:20]};
    assign rs3_ID = {1'b1, inst_ID[31:27]};  

    assign rs1_EX = {rs1_float_EX, inst_EX[19:15]};
    assign rs2_EX = {rs2_float_EX, inst_EX[24:20]};
    assign rs3_EX = {1'b1, inst_EX[31:27]};  

    assign rsW_EX = {rsW_float_EX, inst_EX[11:7]};
    assign rsW_WB = {rsW_float_WB, inst_WB[11:7]};
    assign rsW_MEM = {rsW_float_MEM, inst_MEM[11:7]};

    // forwarding unit
    always_comb begin
            // rs1(i) == rsW(i-1) && regW_en(i-1) == 1 && rs1 != 0
        if((rsW_MEM == rs1_EX) && regW_en_MEM && rsW_MEM) fwd_A = 2'b01;
            // rsW(i) == rs1(i-2) && regW_en(i-2) == 1 && rs1 != 0
        else if ((rsW_WB == rs1_EX) && regW_en_WB && rsW_WB) fwd_A = 2'b10;
        else fwd_A = 2'b00;

            // rsW(i) == rs2(i-1) && regW_en(i-1) == 1 && rs2 != 0
        if((rsW_MEM == rs2_EX) && regW_en_MEM && rsW_MEM) fwd_B = 2'b01;
            // rsW(i) == rs2(i-2) && regW_en(i-2) == 1 && rs2 != 0
        else if ((rsW_WB == rs2_EX) && regW_en_WB && rsW_WB) fwd_B = 2'b10;
        else fwd_B = 2'b00;

            // rsW(i) == rs3(i-1) && regW_en(i-1) == 1 && rs3 != 0
        if((rsW_MEM == rs3_EX) && regW_en_MEM && rsW_MEM && ~|inst_MEM[5:4] && float_inst_MEM) fwd_C = 2'b01;
            // rsW(i) == rs3(i-2) && regW_en(i-2) == 1 && rs3 != 0
        else if ((rsW_WB == rs3_EX) && regW_en_WB && rsW_WB && ~|inst_WB[5:4] && float_inst_WB) fwd_C = 2'b10;
        else fwd_C = 2'b00;
        // ~|inst[5:4] -->> this is only true for 3 operand float instructions 
    end

    // forwarding unit
    always_comb begin
            // csr_address(i) == csr_address(i-1) && csrW_en(i-1) == 1
        if((csr_address_MEM == csr_address_EX) && csrW_en_MEM) fwd_csr = 2'b01;
            // csr_address(i) == csr_address(i-2) && csrW_en(i-2) == 1
        else if ((csr_address_WB == csr_address_EX) && csrW_en_WB) fwd_csr = 2'b10;
        else fwd_csr = 2'b00;

    end

    // stalling and flushing unit
    always_comb begin

        // flush for branch and jump
        if(load_pc) begin
            IF_ID_flush = 1;
            EX_MEM_flush = 1;
        end else begin
            IF_ID_flush = 0;
            EX_MEM_flush = 0;
        end

        // stall for load // alu_multicycle_op
        if((!WBsel_EX && ((rsW_EX==rs1_ID) || (rsW_EX==rs2_ID))) || !done) begin
            pc_en = 0;
            IF_ID_en = 0;
            ID_EX_en = 0;
        end else begin
            pc_en = 1;
            IF_ID_en = 1;
            ID_EX_en = 1;
        end

        if(load_pc || (!WBsel_EX && ((rsW_EX==rs1_ID) || (rsW_EX==rs2_ID))))
            ID_EX_flush = 1;
        else
            ID_EX_flush = 0;

        if(done) begin
            EX_MEM_en = 1'b1;
            MEM_WB_en = 1'b1;
        end else begin
            EX_MEM_en = 1'b0;
            MEM_WB_en = 1'b0;
        end
    end

endmodule