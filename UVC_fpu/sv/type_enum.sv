package riscv_instruction_pkg;
    
    // RISC-V F Extension Opcodes
    typedef enum logic [6:0] {
        // Floating-Point Instructions
        OP_FP      = 7'b1010011,  // Floating-point arithmetic
        OP_FMADD   = 7'b1000011,  // Fused multiply-add
        OP_FMSUB   = 7'b1000111,  // Fused multiply-sub
        OP_FNMSUB  = 7'b1001011,  // Fused negative multiply-sub
        OP_FNMADD  = 7'b1001111,  // Fused negative multiply-add
        OP_FLW     = 7'b0000111,  // Floating-point load word
        OP_FSW     = 7'b0100111,  // Floating-point store word
        
        // Integer Instructions (for completeness)
        OP_LOAD    = 7'b0000011,
        OP_STORE   = 7'b0100011,
        OP_OP      = 7'b0110011,  // R-type
        OP_OP_IMM  = 7'b0010011,  // I-type
        OP_BRANCH  = 7'b1100011,
        OP_JAL     = 7'b1101111,
        OP_JALR    = 7'b1100111,
        OP_LUI     = 7'b0110111,
        OP_AUIPC   = 7'b0010111,
        OP_SYSTEM  = 7'b1110011
    } opcode_e;
    
    // Floating-point instruction funct7 codes - FIXED DUPLICATE VALUES
    typedef enum logic [6:2] {
        FADD_S     = 5'b00000,
        FSUB_S     = 5'b00001,
        FMUL_S     = 5'b00010,
        FDIV_S     = 5'b00011,
        FSQRT_S    = 5'b01011,
        FSGNJ_S    = 5'b00100,  // funct3 = 000
        FSGNJN_S   = 5'b00101,  // CHANGED: Different value (funct3 = 001)
        FSGNJX_S   = 5'b00110,  // CHANGED: Different value (funct3 = 010)
        FMINMAX_S  = 5'b00111,  // funct3 = 000 for FMIN, 001 for FMAX
        FCVT_W_S   = 5'b11000,
        FCVT_S_W   = 5'b11010,
        FCMP_S     = 5'b10100,  // funct3 = 010 for FEQ, 001 for FLT, 000 for FLE
        FCLASS_S   = 5'b11100,  // funct3 = 001
        FMV_X_W    = 5'b11101,  // CHANGED: Different value (funct3 = 000)
        FMV_W_X    = 5'b11110   // funct3 = 000
    } funct7_e;
    
    // Rounding modes
    typedef enum logic [2:0] {
        RM_RNE = 3'b000,  // Round to Nearest, ties to Even
        RM_RTZ = 3'b001,  // Round towards Zero
        RM_RDN = 3'b010,  // Round Down
        RM_RUP = 3'b011,  // Round Up
        RM_RMM = 3'b100,  // Round to Nearest, ties to Max Magnitude
        RM_DYN = 3'b111   // Dynamic rounding mode (from frm)
    } rounding_mode_e;
    
    // Floating-point register numbers
    parameter int FP_REG_COUNT = 32;
    
    // Exception flags for FCSR
    typedef struct packed {
        logic NV;  // Invalid operation
        logic DZ;  // Divide by zero
        logic OF;  // Overflow
        logic UF;  // Underflow
        logic NX;  // Inexact
    } fflags_t;
    
    // FCSR structure
    typedef struct packed {
        logic [31:8] reserved;
        fflags_t     fflags;
        logic [2:0]  frm;
    } fcsr_t;
    
    // Instruction categories for coverage
    typedef enum {
        INSTR_CAT_INTEGER,
        INSTR_CAT_FLOAT,
        INSTR_CAT_LOAD,
        INSTR_CAT_STORE,
        INSTR_CAT_BRANCH,
        INSTR_CAT_SYSTEM
    } instr_category_e;
    
    // Helper functions
    function automatic logic [31:0] encode_fpu_r4(
        input logic [4:0] rd,
        input logic [4:0] rs1,
        input logic [4:0] rs2,
        input logic [4:0] rs3,
        input opcode_e opcode,
        input rounding_mode_e rm
    );
        return {rs3, rs2, rs1, rm, rd, opcode};
    endfunction
    
    function automatic logic [31:0] encode_fpu_r(
        input logic [4:0] rd,
        input logic [4:0] rs1,
        input logic [4:0] rs2,
        input funct7_e func5,
        input rounding_mode_e rm
    );
        return {func5, rs2, rs1, rm, rd, OP_FP};
    endfunction
    
    function automatic string opcode_to_string(opcode_e opcode);
        case (opcode)
            OP_FP:      return "FP";
            OP_FMADD:   return "FMADD";
            OP_FMSUB:   return "FMSUB";
            OP_FNMSUB:  return "FNMSUB";
            OP_FNMADD:  return "FNMADD";
            OP_FLW:     return "FLW";
            OP_FSW:     return "FSW";
            OP_LOAD:    return "LOAD";
            OP_STORE:   return "STORE";
            OP_OP:      return "OP";
            OP_OP_IMM:  return "OP_IMM";
            OP_BRANCH:  return "BRANCH";
            OP_JAL:     return "JAL";
            OP_JALR:    return "JALR";
            OP_LUI:     return "LUI";
            OP_AUIPC:   return "AUIPC";
            OP_SYSTEM:  return "SYSTEM";
            default:    return "UNKNOWN";
        endcase
    endfunction
    
endpackage


