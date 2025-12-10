`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 07/11/2025 02:36:34 PM
// Design Name: 
// Module Name: float_to_fixed
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

module float_to_fixed(
    input  logic [31:0] float_in,
    input  logic [2:0]  rm,         // Rounding mode: 000=RNE, 001=RTZ, 010=RDN, 011=RUP, 100=RMM, 101=RTZ, 110=RTZ, 111=RTZ
    input  logic        is_unsigned,
    output logic [31:0] int_out,
    output logic        invalid
);
    // Extract IEEE-754 fields
    logic sign;
    logic [7:0]  exp;
    logic [22:0] frac;
    logic guard, round, sticky;
    logic [31:0] pre_round, shifted;
    logic [27:0] mantissa;
    logic [8:0]  E;
    
    // Rounding mode definitions
    localparam RNE = 3'b000; // Round to Nearest, ties to Even
    localparam RTZ = 3'b001; // Round to Zero (truncate)
    localparam RDN = 3'b010; // Round Down (-?)
    localparam RUP = 3'b011; // Round Up (+?)
    localparam RMM = 3'b100; // Round to Nearest, ties to Max Magnitude

    always_comb begin
        invalid = 0;
        int_out = 0;
        guard = 0;
        round = 0;
        sticky = 0;
        pre_round = 0;
        shifted = 0;

        // Extract fields
        sign = float_in[31];
        exp  = float_in[30:23];
        frac = float_in[22:0];

        if (exp == 8'hFF) begin
            // NaN or Infinity
            invalid = 1;
        end else begin
            // Compute exponent offset from 127 bias
            E = exp - 8'd127;

            // Build mantissa (24 bits with implicit 1)
            mantissa = (exp == 0) ? {4'b0, frac} : {3'b0, 1'b1, frac}; // 24 bits

            if (E >= 31) begin
                // Overflow for signed (2^31) or unsigned (2^31 and sign=0)
                invalid = 1;
            end else if ($signed(E) < 0) begin
                int_out = 0; // Less than 1.0, valid case
            end else begin
                // Shift mantissa and capture guard, round, sticky bits
                if (E >= 23) begin
                    shifted = mantissa << (E - 23);
                    guard = 0;
                    round = 0;
                    sticky = 0;
                end else begin
                    // Right shift: capture bits that are shifted out
                    integer shift_amount = 23 - E;
                    shifted = mantissa >> shift_amount;
                    // Guard bit: the bit just beyond the integer part
                    guard = (shift_amount <= 24 && shift_amount > 0) ? mantissa[shift_amount-1] : 0;
                    // Round bit: the bit after guard
                    round = (shift_amount <= 23 && shift_amount > 1) ? mantissa[shift_amount-2] : 0;
                    // Sticky bit: OR of all bits beyond round
                    sticky = 0;
                    for (integer i = 0; i < shift_amount-2 && i < 24; i++) begin
                        sticky |= mantissa[i];
                    end
                end

                // Rounding logic
                pre_round = shifted;
                case (rm)
                    RNE: begin
                        // Round up if guard=1 and (round=1 or sticky=1 or LSB=1)
                        if (guard && (round || sticky || (shifted[0] && !sign))) begin
                            pre_round = shifted + 1;
                        end
                    end
                    RTZ: begin
                        // Truncate (no change needed)
                        pre_round = shifted;
                    end
                    RDN: begin
                        // Round down: increment if negative and (guard=1 or round=1 or sticky=1)
                        if (sign && (guard || round || sticky)) begin
                            pre_round = shifted + 1;
                        end
                    end
                    RUP: begin
                        // Round up: increment if positive and (guard=1 or round=1 or sticky=1)
                        if (!sign && (guard || round || sticky)) begin
                            pre_round = shifted + 1;
                        end
                    end
                    RMM: begin
                        // Round to nearest, ties to max magnitude
                        if (guard && (round || sticky || (!round && !sticky))) begin
                            pre_round = shifted + 1;
                        end
                    end
                    3'b101: begin
                        // Truncate (RTZ)
                        pre_round = shifted;
                    end
                    3'b110: begin
                        // Truncate (RTZ)
                        pre_round = shifted;
                    end
                    3'b111: begin
                        // Truncate (RTZ)
                        pre_round = shifted;
                    end
                endcase

                // Apply sign and handle unsigned case
                if (is_unsigned) begin
                    if (sign) begin
                        invalid = 1;
                        int_out = 0;
                    end else begin
                        int_out = pre_round;
                    end
                end else begin
                    int_out = sign ? (~pre_round + 1) : pre_round;
                end
            end
        end
    end
endmodule


