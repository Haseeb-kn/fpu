`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 07/24/2025 05:41:24 PM
// Design Name: 
// Module Name: fpu_div
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


module fpu_div (
    input  logic clk_i, reset_i, start_i,
    input  logic [2:0] frm,         // 000=RNE, 001=RTZ, 010=RDN, 011=RUP, 100=RMM
    input  logic [31:0] a,          // Dividend
    input  logic [31:0] b,          // Divisor
    output logic [31:0] y,          // Result
    output logic valid, nx          // Valid flag, inexact flag
);
    // Extract fields
    logic sa, sb;
    logic [7:0] ea, eb;
    logic [22:0] ma, mb;
    logic [23:0] ma_full, mb_full;  
    assign sa = a[31];
    assign sb = b[31];
    assign ea = a[30:23];
    assign eb = b[30:23];
    assign ma = a[22:0];
    assign mb = b[22:0];
    assign ma_full = (ea == 0) ? {1'b0, ma} : {1'b1, ma}; // Handle subnormals
    assign mb_full = (eb == 0) ? {1'b0, mb} : {1'b1, mb}; // Handle subnormals

    // Special cases
    logic a_zero, b_zero, a_inf, b_inf, a_nan, b_nan;
    assign a_zero = (ea == 0) & (ma == 0);
    assign b_zero = (eb == 0) & (mb == 0);
    assign a_inf = (ea == 255) & (ma == 0);
    assign b_inf = (eb == 255) & (mb == 0);
    assign a_nan = (ea == 255) & (ma != 0);
    assign b_nan = (eb == 255) & (mb != 0);

    // Fixed-point division (64-bit)
    logic [63:0] dividend, divisor, quotient;
    logic div_start, div_valid;
    
    divider64 div (
        .clk_i(clk_i),
        .reset_i(reset_i),
        .stall_i(1'b0),
        .sign_i(1'b0), // Unsigned division
        .start_i(div_start),
        .dividend_i(dividend),
        .divider_i(divisor),
        .quotient_o(quotient),
        .valid_o(div_valid)
    );

    // State machine
    enum {IDLE, PREPARE, DIVIDE, NORM, ROUND, DONE} state;
    logic [8:0] e;
    logic [24:0] m;  // 1.m format (25 bits: 1 + 24)
    logic s;
    logic [5:0] norm_shift; // To track normalization shift

    // Combinatorial rounding signals
    logic guard, sticky, tie, round_up;
    always_comb begin
        guard = m[0];
        sticky = 1'b0;
        case (1'b1)
            quotient[63]: sticky = |quotient[38:0];
            quotient[62]: sticky = |quotient[37:0];
            quotient[61]: sticky = |quotient[36:0];
            default: sticky = |quotient[24:0];
        endcase
        tie = guard & ~sticky & m[1]; // Tie case for RNE: guard=1, sticky=0, LSB=1
        case (frm)
            3'b000: round_up = guard & (sticky | tie); // RNE
            3'b001: round_up = 1'b0;                  // RTZ
            3'b010: round_up = s & (guard | sticky);  // RDN
            3'b011: round_up = ~s & (guard | sticky); // RUP
            3'b100: round_up = guard;                 // RMM
            default: round_up = 1'b0;
        endcase
    end

    always_ff @(posedge clk_i or negedge reset_i) begin
        if (!reset_i) begin
            state <= IDLE;
            valid <= 0;
            nx <= 0;
            y <= 0;
            div_start <= 0;
            e <= 0;
            m <= 0;
            s <= 0;
            norm_shift <= 0;
        end else begin
            case (state)
                IDLE: begin
                    valid <= 0;
                    nx <= 0;
                    div_start <= 0;
                    if (start_i) state <= PREPARE;
                end
                
                PREPARE: begin
                    s <= sa ^ sb;
                    if (a_nan | b_nan | (a_zero & b_zero) | (a_inf & b_inf)) begin
                        y <= {1'b0, 8'hFF, 23'h7FFFFF}; // qNaN
                        state <= DONE;
                    end else if (a_zero | b_inf) begin
                        y <= {s, 8'h00, 23'd0}; // Zero
                        state <= DONE;
                    end else if (b_zero | a_inf) begin
                        y <= {s, 8'hFF, 23'd0}; // Infinity
                        state <= DONE;
                    end else begin
                        dividend <= {1'b0, ma_full, 39'd0}; // Q1.63 format
                        divisor <= {1'b0, mb_full, 39'd0};  // Q1.63 format
                        e <= {1'b0, ea} - {1'b0, eb} + 9'd127; // eA - eB + bias
                        div_start <= 1;
                        state <= DIVIDE;
                    end
                end
                
                DIVIDE: begin
                    div_start <= 0;
                    if (div_valid) state <= NORM;
                end
                
                NORM: begin
                    // Find leading 1 with more robust search
                    if (quotient[63]) begin
                        m <= quotient[63:39];
                        norm_shift <= 0;
                    end else if (quotient[62]) begin
                        m <= quotient[62:38];
                        e <= e - 1;
                        norm_shift <= 1;
                    end else if (quotient[61]) begin
                        m <= quotient[61:37];
                        e <= e - 2;
                        norm_shift <= 2;
                    end else begin
                        // Search for leading 1
                        integer i;
                        norm_shift <= 39;
                        for (i = 60; i >= 0; i--) begin
                            if (quotient[i]) begin
                                m <= 0; // m <= quotient[i -: 25]; // unsynthesizeable in vivado //quotient[i : i - 25]; //
                                norm_shift <= 63 - i;
                                e <= e - (63 - i);
                                break;
                            end
                        end
                    end
                    state <= ROUND;
                end
                
                ROUND: begin
                    m[24:1] <= m[24:1] + round_up;
                    nx <= guard | sticky;
                    if (m[24]) begin
                        m <= m >> 1;
                        e <= e + 1;
                    end
                    if (e[8] || e[7:0] >= 255) begin // Overflow
                        case (frm)
                            3'b010: y <= {1'b1, 8'hFF, 23'd0}; // RDN: -Inf
                            3'b011: y <= {1'b0, 8'hFF, 23'd0}; // RUP: +Inf
                            default: y <= {s, 8'hFF, 23'd0};   // Infinity
                        endcase
                    end else if (e[7:0] == 0) begin       // Subnormal
                        y <= {s, 8'h00, m[23:1] >> (1 - e[7:0])};
                    end else begin                        // Normal
                        y <= {s, e[7:0], m[23:1]};
                    end
                    state <= DONE;
                end
                
                DONE: begin
                    valid <= 1;
                    state <= IDLE;
                end
            endcase
        end
    end
endmodule
