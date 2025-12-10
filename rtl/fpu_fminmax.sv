`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// Create Date: 07/15/2025
// Design Name: 
// Module Name: fpu_fminmax
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


module fpu_fminmax(
    input  logic [31:0] rs1,
    input  logic [31:0] rs2,
    input  logic min0_max1, // 0: fmin.s, 1: fmax.s
    output logic [31:0] rd
);
    logic s1, s2;
    logic [7:0] e1, e2;
    logic [22:0] m1, m2;
    logic rs1_lt_rs2;

    always_comb begin
        s1 = rs1[31];
        s2 = rs2[31];
        e1 = rs1[30:23];
        e2 = rs2[30:23];
        m1 = rs1[22:0];
        m2 = rs2[22:0];

        // Compare rs1 < rs2 (IEEE-754, ignoring NaN for simplicity)
        if (s1 != s2)
            rs1_lt_rs2 = s1; // negative is less
        else if (e1 != e2)
            rs1_lt_rs2 = (s1 ? (e1 > e2) : (e1 < e2));
        else if (m1 != m2)
            rs1_lt_rs2 = (s1 ? (m1 > m2) : (m1 < m2));
        else
            rs1_lt_rs2 = 1'b0; // equal

        if (min0_max1 == 1'b0)
            rd = rs1_lt_rs2 ? rs1 : rs2; // fmin.s
        else
            rd = rs1_lt_rs2 ? rs2 : rs1; // fmax.s
    end
endmodule
