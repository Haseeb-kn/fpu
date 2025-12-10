`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 07/15/2025 12:08:55 PM
// Design Name: 
// Module Name: csr_compute
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


module csr_compute(
    input logic float_inst,
    input logic [4:0] f_flags,
    input logic [1:0] csr_mode,
    input logic [31:0] csr_data_in_old,
    input logic [31:0] csr_data_in_new,
    output logic [31:0] csr_data_out
    );

    // csr only get updated by hardware if fpu is selected in alu
    // (check incase of bypass instructions if csr needs to be updated e.g. fmv.x.w does not update fcsr) << possible issue
    always_comb begin 
        if (float_inst) csr_data_out = csr_data_in_old | {{27'b0}, f_flags}; // to update flags by hardware
        else begin
            unique case (csr_mode)
                2'd1: csr_data_out = csr_data_in_new; // csrrw
                2'd2: csr_data_out = csr_data_in_old | csr_data_in_new; // csrrs
                2'd3: csr_data_out = csr_data_in_old & ~csr_data_in_new; // csrrc
                default: csr_data_out = csr_data_in_old;
            endcase
        end
    end


endmodule
