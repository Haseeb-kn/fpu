module fpu_class(
    input logic [31:0] rs1,         
    output logic [31:0] rd    
    );       

    logic sign;
    logic [7:0] exp;
    logic [22:0] frac;

    logic is_exp_zero, is_exp_ones;
    logic is_frac_zero;
    
    assign sign = rs1[31];
    assign exp = rs1[30:23];
    assign frac = rs1[22:0];
    
    assign is_exp_zero = (exp == 8'b0);
    assign is_exp_ones = &exp;
    assign is_frac_zero = ~|frac;
    
    // classification logic
    always_comb begin
        rd = '0;  
        
        if (is_exp_ones) begin
            if (is_frac_zero) begin
                // Infinity
                rd[sign ? 0 : 7] = 1'b1;
            end else begin
                // NaN
                rd[frac[22] ? 8 : 9] = 1'b1;  // Quiet NaN has MSB of fraction set
            end
        end else if (is_exp_zero) begin
            if (is_frac_zero) begin
                // Zero
                rd[sign ? 3 : 4] = 1'b1;
            end else begin
                // Subnormal
                rd[sign ? 2 : 5] = 1'b1;
            end
        end else begin
            // Normal
            rd[sign ? 1 : 6] = 1'b1;
        end
    end

endmodule