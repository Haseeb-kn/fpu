module fixedp2floatp_q32 (
    input logic [31:0] fixedq32,          // Q32.0 fixed-point input
    input logic [2:0] rm,                 // Rounding mode (3-bit)
    input logic is_signed,                // 1 for signed, 0 for unsigned
    output logic [31:0] float32,          // IEEE 754 single-precision output
    output logic f32_invalid              // Invalid operation flag
);

    // Internal signals
    logic [31:0] pos_fixedq32;           // Absolute value of input
    logic [4:0] zero_count;              // Leading zero count
    logic [31:0] pre_mantissa;           // Pre-normalized mantissa
    logic [23:0] mantissa_full;          // 24-bit mantissa (including leading 1)
    logic [22:0] mantissa;               // Final 23-bit mantissa
    logic [8:0] exponent;                // 8-bit exponent
    logic sign_bit;                      // Sign bit for output
    logic guard, round, sticky;          // Rounding bits
    logic [23:0] rounded_mantissa;       // Mantissa after rounding
    logic exponent_overflow;             // Flag for exponent overflow
    logic round_up;                      // Flag to indicate rounding up

    // Rounding mode definitions
    localparam RNE = 3'b000; // Round to nearest, ties to even
    localparam RZ  = 3'b001; // Round towards zero
    localparam RDN = 3'b010; // Round down (towards -infinity)
    localparam RUP = 3'b011; // Round up (towards +infinity)
    localparam RMM = 3'b100; // Round to nearest, ties to max magnitude

    always_comb begin
        // Initialize outputs and flags
        float32 = 32'b0;
        f32_invalid = 1'b0;
        zero_count = 5'b0;
        pos_fixedq32 = 32'b0;
        pre_mantissa = 32'b0;
        mantissa_full = 24'b0;
        mantissa = 23'b0;
        exponent = '0;
        sign_bit = 1'b0;
        guard = 1'b0;
        round = 1'b0;
        sticky = 1'b0;
        rounded_mantissa = 24'b0;
        exponent_overflow = 1'b0;
        round_up = 1'b0;

        // Handle sign and absolute value
        if (is_signed && fixedq32[31]) begin
            sign_bit = 1'b1;
            pos_fixedq32 = ~fixedq32 + 1; // Two's complement for negative numbers
        end else begin
            sign_bit = 1'b0;
            pos_fixedq32 = fixedq32;
        end

        // Check for zero input
        if (pos_fixedq32 == 32'b0) begin
            float32 = {1'b0, 8'b0, 23'b0}; // IEEE 754 zero
            f32_invalid = 1'b0;
        end else begin
            // Count leading zeros for normalization
            for (int i = 31; i >= 0; i = i - 1) begin
                if (pos_fixedq32[i] == 1'b1) break;
                zero_count = zero_count + 1;
            end

            // Normalize: shift left by zero_count + 1 to remove leading 1
            pre_mantissa = pos_fixedq32 << (zero_count);

            // Extract 24-bit mantissa (including implicit leading 1)
            mantissa_full = pre_mantissa[31:8];

            // Extract rounding bits
            guard = pre_mantissa[7];
            round = pre_mantissa[6];
            sticky = |pre_mantissa[5:0]; // OR of all lower bits

            // Calculate exponent (31 - zero_count + 127 for Q32.0)
            exponent = 31 - zero_count + 127;

            // Check for exponent overflow
            if (exponent >= 255) begin
                exponent_overflow = 1'b1;
                f32_invalid = 1'b1;
                float32 = {sign_bit, 8'hFF, 23'b0}; // Infinity
            end else begin
                // Rounding logic based on rm
                case (rm)
                    RNE: // Round to nearest, ties to even
                        round_up = guard && (round || sticky || mantissa_full[8]);
                    RZ:  // Round towards zero
                        round_up = 1'b0;
                    RDN: // Round down
                        round_up = sign_bit && (guard || round || sticky);
                    RUP: // Round up
                        round_up = !sign_bit && (guard || round || sticky);
                    RMM: // Round to nearest, ties to max magnitude
                        round_up = guard && (round || sticky);
                    default: begin
                        round_up = 1'b0;
                        f32_invalid = 1'b1; // Invalid rounding mode
                    end
                endcase

                // Apply rounding
                rounded_mantissa = mantissa_full + (round_up ? 24'b1 : 24'b0);

                // Check for mantissa overflow after rounding
                if (rounded_mantissa[23] && round_up) begin
                    rounded_mantissa = rounded_mantissa >> 1;
                    exponent = exponent + 1;
                    if (exponent >= 255) begin
                        exponent_overflow = 1'b1;
                        f32_invalid = 1'b1;
                        float32 = {sign_bit, 8'hFF, 23'b0}; // Infinity
                    end
                end

                // Final mantissa (discard leading 1)
                mantissa = rounded_mantissa[22:0];

                // Assemble output if no overflow
                if (!exponent_overflow) begin
                    float32 = {sign_bit, exponent[7:0], mantissa};
                end
            end
        end
    end

endmodule