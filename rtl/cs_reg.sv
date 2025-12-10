`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 07/14/2025 04:50:43 PM
// Design Name: 
// Module Name: cs_reg
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


module cs_reg(
    input logic clk,
    input logic rst, // active low
    input logic csrW_en,
    input logic [11:0] csr_address_w,
    input logic [11:0] csr_address_r,
    input logic [31:0] csr_data_w,
    output logic [31:0] csr_data_r
);

    // Machine Trap CSR
    logic [31:0] mstatus, mtvec, mepc, mcause, mtval;

    // Floating-Point CSR
    logic [7:0] fcsr; // [7:0] 

    always_comb begin
        unique case (csr_address_r)
            12'h300: csr_data_r = mstatus;
            12'h305: csr_data_r = mtvec;
            12'h341: csr_data_r = mepc;
            12'h342: csr_data_r = mcause;
            12'h343: csr_data_r = mtval;
            12'h001: csr_data_r = {27'b0, fcsr[4:0]}; // fflags
            12'h002: csr_data_r = {29'b0, fcsr[7:5]}; // frm
            12'h003: csr_data_r = {24'b0, fcsr};
            default: csr_data_r = 32'b0;
        endcase
    end

    always_ff@(negedge clk or negedge rst) begin 
        if(!rst) begin
            mstatus <= 32'b0;
            mtvec <= 32'b0; 
            mepc <= 32'b0; 
            mcause <= 32'b0;
            mtval <= 32'b0;
            fcsr <= 8'b0;
        end
        else if (csrW_en) begin

            unique case (csr_address_w)
                12'h300: mstatus <= csr_data_w;
                12'h305: mtvec <= csr_data_w;
                12'h341: mepc <= csr_data_w;
                12'h342: mcause <= csr_data_w;
                12'h343: mtval <= csr_data_w;
                12'h001: fcsr[4:0] <= csr_data_w[4:0]; // fflags
                12'h002: fcsr[7:5] <= csr_data_w[2:0]; // frm
                12'h003: fcsr <= csr_data_w[7:0];
                default: ;
            endcase
        end
    end

endmodule