`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 06/26/2025 03:08:30 PM
// Design Name: 
// Module Name: fixedp2floatp
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


module fixedp2floatp(
    input logic [31:0] fixedq16, 
    output logic [31:0] float32 
    );

    logic [31:0] pos_fixedq16;
    logic [4:0] zero_count;
    logic [31:0] pre_mantissa;
    logic [22:0] mantissa;
    logic [7:0] exponent;
    
    always_comb begin
        zero_count = 0;

        if(fixedq16[31]) pos_fixedq16 = ~fixedq16 + 1;
        else pos_fixedq16 = fixedq16;

        for(int i = 31; i >= 0; i = i - 1) begin
            if(pos_fixedq16[i] == 1) break;
            zero_count = zero_count + 1'b1;
        end

        pre_mantissa = pos_fixedq16 << (zero_count + 1); // +1 to remove leading 1
        mantissa = pre_mantissa[31:9];
        exponent = 15 - zero_count + 127; // (4*4)-1

        float32 = {fixedq16[31], exponent, mantissa};
    end

endmodule
