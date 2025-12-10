`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 07/18/2025 08:36:04 PM
// Design Name: 
// Module Name: floating_sqrt
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


module floating_sqrt (
    input  logic clk,
    input  logic rst,
    input  logic start,
    input  logic [31:0] operA_float32,
    output logic [31:0] result,
    output logic done, flag_nx
);

    assign flag_nx = 1'b0; // No NaN or overflow handling in this simple sqrt implementation

    // Internal signals
    logic [23:0] sqrt_input;
    logic [23:0] sqrt_result;
    logic [23:0] sqrt_result_out;
    logic [23:0] sqrt_rem;

    logic [7:0] exp;
    logic [23:0] mant;
    logic sign;

    logic [8:0] unbiased_exp;

    logic [8:0] r_exp, r_exp_next;
    logic [23:0] r_mant, r_mant_next;
    logic [4:0] zero_count, zero_count_next;

    logic [31:0] result_next, result_next2;
    logic done_next, done_next2;

    logic start_sqrt;

    // sqrt module 
    logic done_sqrt;
    sqrt #(
        .WIDTH(24),
        .FBITS(23)
    ) sqrt_unit (
        .clk(clk),
        .start(start_sqrt),
        .valid(done_sqrt),
        .rad(sqrt_input),
        .root(sqrt_result),
        .rem(sqrt_rem)
    );

    // FSM states
    typedef enum logic [1:0] {
        IDLE = 2'd0,
        PROCESS = 2'd1,
        COMPUTE_SQRT = 2'd2,
        NORMALIZE = 2'd3
    } state_t;

    state_t state, next_state;

    // Sequential logic
    always_ff @(posedge clk or negedge rst) begin
        if (!rst) begin
            state <= IDLE;
            r_exp <= 0;
            r_mant <= 0;
            zero_count_next <= 0;
            exp <= 0;
            mant <= 0;
            sign <= 0;
            result_next <= 0;
            done_next <= 0;
        end else begin
            state <= next_state;
            r_exp <= r_exp_next;
            r_mant <= r_mant_next;
            zero_count_next <= zero_count;
            result_next <= result_next2;
            done_next <= done_next2;

            //  initializing
            if (state == IDLE && start) begin
                exp <= operA_float32[30:23];
                mant <= (|operA_float32[30:23]) ? {1'b1, operA_float32[22:0]} : {1'b0, operA_float32[22:0]};
                sign <= operA_float32[31];
            end
        end
    end

    // Combinational logic
    always_comb begin
        // Default assignments
        next_state = state;
        sqrt_input = r_mant; 
        r_exp_next = r_exp;
        r_mant_next = r_mant;
        result_next2 = result_next;
        done_next2 = 1'b0;
        start_sqrt = 1'b0;
        zero_count = zero_count_next; // hold value by default

        case (state)
            IDLE: begin
                if (start)
                    next_state = PROCESS;
            end

            PROCESS: begin
                unbiased_exp = exp - 126;

                if (unbiased_exp[0]) begin
                    unbiased_exp = (unbiased_exp + 1) >> 1;
                    r_mant_next = mant >> 1;
                end else begin
                    unbiased_exp = unbiased_exp >> 1;
                    r_mant_next = mant;
                end

                r_exp_next = unbiased_exp + 127;
                sqrt_input = r_mant_next;
                start_sqrt = 1'b1; // start sqrt on this cycle
                next_state = COMPUTE_SQRT;
            end

            COMPUTE_SQRT: begin
                if (done_sqrt) begin
                    zero_count = 0;
                    for (int i = 23; i >= 0; i--) begin
                        if (sqrt_result[i] == 1) break;
                        zero_count = zero_count + 1;
                    end
                    next_state = NORMALIZE;
                end
            end

            NORMALIZE: begin
                sqrt_result_out = sqrt_result << zero_count_next;
                r_exp_next = r_exp - zero_count_next; // shift affects exponent
               
                if (r_exp_next[8] || r_exp_next > 254) begin
                    r_exp_next = 254; // exponent to avoid overflow
                end

                result_next2 = {sign, r_exp_next[7:0], sqrt_result_out[22:0]};
                done_next2 = 1'b1;
                next_state = IDLE;
            end

            default: next_state = IDLE;
        endcase
    end

    // Output stage
    always_ff @(posedge clk or negedge rst) begin
        if (!rst) begin
            done <= 0;
        end
        else begin
            done <= done_next2; // Register done signal
        end
    end

    assign result = result_next;

endmodule