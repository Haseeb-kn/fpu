`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 06/26/2025 05:09:32 PM
// Design Name: 
// Module Name: fpu_alu
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


module fpu_alu(
      input logic clk, rst, start,
      input logic [2:0] frm, // rounding mode
      input logic [4:0] ALUsel,
      input logic [31:0] operA_float32,
      input logic [31:0] operB_float32,
      input logic [31:0] operC_float32,
      output logic [31:0] result,
      // output logic [3:0] rs1_class
      output logic [4:0] f_flags,
      output logic done
      );
      
      logic NV, DZ, OF, UF, NX;

      // start signals
      logic add_sub_start;
      logic mul_div_start;
      logic fp_sqrt_start;
      logic fpu_fma_start;

      // done signals
      logic add_sub_done;
      logic mul_div_done;
      logic fp_sqrt_done;
      logic fpu_fma_done;

      // flags
      logic flag_nx_add_sub;
      logic flag_nx_mul_div;
      logic flag_nx_fp_sqrt;
      logic flag_nx_fpu_fma;
      
      // outputs
      logic [31:0] add_sub_out;
      logic [31:0] mul_div_out;
      logic [31:0] fp_sqrt_out;
      logic [31:0] fpu_fma_out;
      logic [31:0] fpu_sgnj_out; // for fpu_fma
      logic [31:0] fpu_minmax_out; // for fpu_fminmax
      logic [31:0] float_to_fixed_out; // for float_to_fixed
      logic [31:0] fixed_to_float_out; // for fixed_to_float
      logic [31:0] fpu_class_out; // for fpu_class

      logic [1:0] fsgnj_op; // for fpu_fsgnj
      logic min0_max1; // for fpu_fminmax
      
      fpu_add_sub FP_AS       (.start(add_sub_start), .add0_sub1(ALUsel[0]),  .result(add_sub_out), .done(add_sub_done), .flag_nx(flag_nx_add_sub), .*);
      fpu_mul_div FP_ML       (.start(mul_div_start), .mul0_div1(ALUsel[0]),  .result(mul_div_out), .done(mul_div_done), .flag_nx(flag_nx_mul_div), .*);
      floating_sqrt FP_SQRT   (.start(fp_sqrt_start),                         .result(fp_sqrt_out), .done(fp_sqrt_done), .flag_nx(flag_nx_fp_sqrt), .*);
      fpu_fma FP_FMA_OP       (.start(fpu_fma_start), .opcode(ALUsel[2:1]),   .rd(fpu_fma_out),     .done(fpu_fma_done), .flag_nx(flag_nx_fpu_fma), .*);
      fpu_fsgnj FP_SGNJ       (.rs1(operA_float32),   .rs2(operB_float32),    .opcode(fsgnj_op),     .rd(fpu_sgnj_out)); // 00: fsgnj.s, 01: fsgnjn.s, 10: fsgnjx.s
      fpu_fminmax FP_MINMAX   (.rs1(operA_float32), .rs2(operB_float32), .min0_max1, .rd(fpu_minmax_out));
      float_to_fixed FP_W_S   (.float_in(operA_float32), .rm(frm), .is_unsigned(~ALUsel[0]), .int_out(float_to_fixed_out));
      fpu_class FP_CLASS      (.rs1(operA_float32), .rd(fpu_class_out));
      fixedp2floatp_q32 FP_S_W(.fixedq32(operA_float32), .rm(frm), .is_signed(ALUsel[1]), .float32(fixed_to_float_out));

      always_comb begin
            done = 1'b1; // for single cycle operations
            add_sub_start = 1'b0;
            mul_div_start = 1'b0;
            fp_sqrt_start = 1'b0;
            fpu_fma_start = 1'b0;
            NX = 1'b0;
            fsgnj_op = 2'b00; // default to fsgnj.s
            case (ALUsel) // special case inputs and outputs will be handled here (tbd) 0/0, inf/0 etc
                  5'b00000: begin // fadd.s
                        result = add_sub_out;
                        add_sub_start = ~add_sub_done & start;
                        done = add_sub_done;
                        NX = flag_nx_add_sub;
                  end
                  5'b00001: begin // fsub.s
                        result = add_sub_out;
                        add_sub_start = ~add_sub_done & start;
                        done = add_sub_done;
                        NX = flag_nx_add_sub;
                  end
                  5'b00010: begin // fmul.s
                        result = mul_div_out;
                        mul_div_start = ~mul_div_done & start;
                        done = mul_div_done;
                        NX = flag_nx_mul_div;
                  end
                  5'b00011: begin // fdiv.s
                        result = mul_div_out;
                        mul_div_start = ~mul_div_done & start;
                        done = mul_div_done;
                        NX = flag_nx_mul_div;
                  end
                  5'b01011: begin // fsqrt.s
                        result = fp_sqrt_out;
                        fp_sqrt_start = ~fp_sqrt_done & start;
                        done = fp_sqrt_done;
                        NX = flag_nx_fp_sqrt;
                  end
                  5'b11001, 5'b11011, 5'b11101, 5'b11111: begin // fma.s, fnmadd.s, fnmsub.s, fmsub.s
                        result = fpu_fma_out;
                        fpu_fma_start = ~fpu_fma_done & start;
                        done = fpu_fma_done;
                        NX = flag_nx_fpu_fma;
                  end
                  5'b00110: begin // fsgnj.s
                        result = fpu_sgnj_out;
                        fsgnj_op = 2'b00; // fsgnj.s
                  end
                  5'b00111: begin // fsgnjn.s
                        result = fpu_sgnj_out;
                        fsgnj_op = 2'b01; // fsgnjn.s
                  end
                  5'b01000: begin // fsgnjx.s
                        result = fpu_sgnj_out;
                        fsgnj_op = 2'b10; // fsgnjx.s
                  end
                  5'b01001: begin // fmax.s
                        result = fpu_minmax_out;
                        min0_max1 = 1'b1; // fmin.s
                  end
                  5'b01010: begin // fmin.s
                        result = fpu_minmax_out;
                        min0_max1 = 1'b0; // fmax.s
                  end
                  5'b01101, 5'b01100: result = float_to_fixed_out; // fcvt.w.s, fcvt.wu.s
                  5'b10000: result = {31'b0, (operA_float32 == operB_float32)};
                  5'b01110: begin // fle.s
                        min0_max1 = 1'b0; // fle.s
                        if (fpu_minmax_out == operA_float32) begin // if operA is min or equal to operB
                            result = 32'b1; // operA <= operB // this will be 1 if operA is less than or equal to operB
                        end else begin
                            result = 32'b0; // operA > operB
                        end
                  end
                  5'b01111: begin // flt.s
                        min0_max1 = 1'b0; // flt.s
                        if (fpu_minmax_out == operA_float32) begin // if operA is min and not equal to operB
                            result = (operA_float32 == operB_float32) ? 32'b0 : 32'b1; // operA < operB
                        end else begin
                            result = 32'b0; // operA >= operB
                        end
                  end
                  5'b10001: result = fpu_class_out; // fclass.s
                  5'b10101, 5'b10011: result = fixed_to_float_out; // fcvt.s.w, fcvt.s.wu
                  default: begin
                        result = 32'h10101010; // Default case, should not happen
                  end
            endcase

            // NV = (ALUsel[1] && ALUsel[0] &&  // Division operation
            //       (|operB_float32[30:0] && (operA_float32[30:0] == 31'b0))); // 0/0 case
            // DZ = (ALUsel[1] && ALUsel[0] &&  // Division operation
            //       |operB_float32[30:0] && (operA_float32[30:0] != 31'b0)); // x/0 where x≠0
            // OF = &result[30:23] && !NV && !DZ;
            NV = 0;
            DZ = 0;
            OF = 0;
            UF = (result[30:23] == 8'b0) && !NV && !DZ && NX; 
      end

      assign f_flags = {NV, DZ, OF, UF, NX};


    //====================================\\
    // result classification logic
    //====================================\\
    // 4'b0000: -infinity
    // 4'b0001: negative normal
    // 4'b0010: negative subnormal
    // 4'b0011: -0
    // 4'b0100: +0
    // 4'b0101: positive subnormal
    // 4'b0110: positive normal
    // 4'b0111: +infinity
    // 4'b1000: signaling NaN
    // 4'b1001: quiet NaN
   //===================================\\

    // logic [31:0] rs1;
    // assign rs1 = result;

    // always_comb begin
    //     // default undefined
    //     rs1_class = 4'b1111;
    //     if (rs1[30:23] == 8'hFF) begin
    //         if (rs1[22:0] == 0) begin
    //             // infinity
    //             rs1_class = rs1[31] ? 4'b0000 : 4'b0111;
    //         end else begin
    //             // NaN
    //             if (rs1[22] == 1'b0)
    //                 rs1_class = 4'b1000; // signaling NaN
    //             else
    //                 rs1_class = 4'b1001; // quiet NaN
    //         end
    //     end else if (rs1[30:23] == 8'h00) begin
    //         if (rs1[22:0] == 0) begin
    //             // zero
    //             rs1_class = rs1[31] ? 4'b0011 : 4'b0100;
    //         end else begin
    //             // subnormal
    //             rs1_class = rs1[31] ? 4'b0010 : 4'b0101;
    //         end
    //     end else begin
    //         // normal
    //         rs1_class = rs1[31] ? 4'b0001 : 4'b0110;
    //     end
    // end

endmodule
