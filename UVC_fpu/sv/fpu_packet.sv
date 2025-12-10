class fpu_packet extends uvm_sequence_item;
    `uvm_object_utils(fpu_packet)
    
    //===========================================
    // DUT Interface Signals
    //===========================================
    
    // DUT Inputs (driven by driver)
    rand logic [31:0] instruction;
    rand logic [31:0] dmem_dataIN;
    
    // DUT Outputs (monitored)
    logic [31:0] dmem_addr;
    logic [31:0] pc_curr;
    logic [2:0]  func3_MEM;
    logic        memW_en_MEM;
    logic [31:0] dmem_dataOUT;
    
    //===========================================
    // Expected Outputs (for Scoreboard)
    //===========================================
    logic [31:0] exp_dmem_addr;
    logic [31:0] exp_pc_curr;
    logic [2:0]  exp_func3_MEM;
    logic        exp_memW_en_MEM;
    logic [31:0] exp_dmem_dataOUT;
    
    //===========================================
    // Floating-Point Specific Fields
    //===========================================
    
    // Operands for FP operations (from register file)
    logic [31:0] fp_operand1;  // Value from rs1
    logic [31:0] fp_operand2;  // Value from rs2
    logic [31:0] fp_operand3;  // Value from rs3 (for fused ops)
    logic [4:0]  fp_reg_dest;  // Destination register rd
    
    // Expected FP result (for scoreboard checking)
    logic [31:0] exp_fp_result;
    
    //===========================================
    // Instruction Decoding Fields
    //===========================================
    opcode_e opcode;
    logic [4:0] rs1;      // Source register 1
    logic [4:0] rs2;      // Source register 2
    logic [4:0] rs3;      // Source register 3 (for R4-type)
    logic [4:0] rd;       // Destination register
    logic [2:0] funct3;   // Function field 3
    logic [6:0] funct7;   // Function field 7
    logic [4:0] funct5;   // Function field 5 (bits [31:27])
    rounding_mode_e rm;   // Rounding mode
    
    // High-level instruction classification
    rand instr_category_e instr_category;
    
    // Specific FP operation type (for coverage)
    typedef enum {
        FP_OP_NONE,
        FP_OP_ADD,
        FP_OP_SUB,
        FP_OP_MUL,
        FP_OP_DIV,
        FP_OP_SQRT,
        FP_OP_FMADD,
        FP_OP_FMSUB,
        FP_OP_FNMSUB,
        FP_OP_FNMADD,
        FP_OP_MIN,
        FP_OP_MAX,
        FP_OP_SGNJ,
        FP_OP_SGNJN,
        FP_OP_SGNJX,
        FP_OP_CVT_W,
        FP_OP_CVT_WU,
        FP_OP_CVT_S_W,
        FP_OP_CVT_S_WU,
        FP_OP_MV_X_W,
        FP_OP_MV_W_X,
        FP_OP_CMP_EQ,
        FP_OP_CMP_LT,
        FP_OP_CMP_LE,
        FP_OP_CLASS,
        FP_OP_LOAD,
        FP_OP_STORE
    } fp_operation_e;
    
    fp_operation_e fp_operation;
    
    //===========================================
    // Control and Timing
    //===========================================
    rand int latency;
    rand bit [11:0] imm12;  // 12-bit immediate for load/store
    
    //===========================================
    // Constraints
    //===========================================
    
    constraint valid_latency {
        latency inside {[1:10]};
    }
    
    constraint valid_registers {
        rs1 inside {[0:31]};
        rs2 inside {[0:31]};
        rs3 inside {[0:31]};
        rd inside {[0:31]};
    }
    
    constraint valid_category {
        instr_category dist {
            INSTR_CAT_FLOAT   := 50,
            INSTR_CAT_INTEGER := 20,
            INSTR_CAT_LOAD    := 10,
            INSTR_CAT_STORE   := 10,
            INSTR_CAT_BRANCH  := 10
        };
    }
    
    //===========================================
    // Constructor
    //===========================================
    function new(string name = "fpu_packet");
        super.new(name);
    endfunction
    
    //===========================================
    // Post-Randomize: Generate Valid Instruction
    //===========================================
    function void post_randomize();
        // After randomization, ensure instruction is properly formed
        decode_instruction();
    endfunction
    
    //===========================================
    // Decode Instruction
    //===========================================
    virtual function void decode_instruction();
        // Extract fields from instruction
        opcode = opcode_e'(instruction[6:0]);
        rd = instruction[11:7];
        funct3 = instruction[14:12];
        rs1 = instruction[19:15];
        rs2 = instruction[24:20];
        
        // For R4-type (fused multiply-add)
        rs3 = instruction[31:27];
        
        // For R-type FP operations
        funct7 = instruction[31:25];
        funct5 = instruction[31:27];
        
        // Rounding mode (from funct3 for FP ops)
        rm = rounding_mode_e'(instruction[14:12]);
        
        // Store destination for FP ops
        fp_reg_dest = rd;
        
        // Classify instruction category and operation
        classify_instruction();
    endfunction
    
    //===========================================
    // Classify Instruction Type
    //===========================================
    virtual function void classify_instruction();
        case (opcode)
            OP_LOAD, OP_FLW: begin
                instr_category = INSTR_CAT_LOAD;
                if (opcode == OP_FLW) fp_operation = FP_OP_LOAD;
            end
            
            OP_STORE, OP_FSW: begin
                instr_category = INSTR_CAT_STORE;
                if (opcode == OP_FSW) fp_operation = FP_OP_STORE;
            end
            
            OP_FP: begin
                instr_category = INSTR_CAT_FLOAT;
                classify_fp_operation();
            end
            
            OP_FMADD: begin
                instr_category = INSTR_CAT_FLOAT;
                fp_operation = FP_OP_FMADD;
            end
            
            OP_FMSUB: begin
                instr_category = INSTR_CAT_FLOAT;
                fp_operation = FP_OP_FMSUB;
            end
            
            OP_FNMSUB: begin
                instr_category = INSTR_CAT_FLOAT;
                fp_operation = FP_OP_FNMSUB;
            end
            
            OP_FNMADD: begin
                instr_category = INSTR_CAT_FLOAT;
                fp_operation = FP_OP_FNMADD;
            end
            
            OP_BRANCH: begin
                instr_category = INSTR_CAT_BRANCH;
            end
            
            OP_OP, OP_OP_IMM, OP_LUI, OP_AUIPC: begin
                instr_category = INSTR_CAT_INTEGER;
            end
            
            OP_SYSTEM: begin
                instr_category = INSTR_CAT_SYSTEM;
            end
            
            default: begin
                instr_category = INSTR_CAT_INTEGER;
            end
        endcase
    endfunction
    
    //===========================================
    // Classify Specific FP Operation
    //===========================================
    virtual function void classify_fp_operation();
        case (funct5)
            FADD_S:    fp_operation = FP_OP_ADD;
            FSUB_S:    fp_operation = FP_OP_SUB;
            FMUL_S:    fp_operation = FP_OP_MUL;
            FDIV_S:    fp_operation = FP_OP_DIV;
            FSQRT_S:   fp_operation = FP_OP_SQRT;
            
            FSGNJ_S:   fp_operation = (funct3 == 3'b000) ? FP_OP_SGNJ : FP_OP_NONE;
            FMINMAX_S: fp_operation = (funct3 == 3'b000) ? FP_OP_MIN : FP_OP_MAX;
            
            FCVT_W_S: begin
                fp_operation = (rs2[0] == 0) ? FP_OP_CVT_W : FP_OP_CVT_WU;
            end
            
            FCVT_S_W: begin
                fp_operation = (rs2[0] == 0) ? FP_OP_CVT_S_W : FP_OP_CVT_S_WU;
            end
            
            FCMP_S: begin
                case (funct3)
                    3'b010: fp_operation = FP_OP_CMP_EQ;
                    3'b001: fp_operation = FP_OP_CMP_LT;
                    3'b000: fp_operation = FP_OP_CMP_LE;
                    default: fp_operation = FP_OP_NONE;
                endcase
            end
            
            FCLASS_S:  fp_operation = FP_OP_CLASS;
            FMV_X_W:   fp_operation = FP_OP_MV_X_W;
            FMV_W_X:   fp_operation = FP_OP_MV_W_X;
            
            default:   fp_operation = FP_OP_NONE;
        endcase
    endfunction
    
    //===========================================
    // Calculate Expected Result (Golden Model)
    //===========================================
    virtual function void calculate_expected_result();
        real op1_real, op2_real, op3_real, result_real;
        
        // Convert IEEE 754 to real for calculation
        op1_real = $bitstoshortreal(fp_operand1);
        op2_real = $bitstoshortreal(fp_operand2);
        op3_real = $bitstoshortreal(fp_operand3);
        
        case (fp_operation)
            FP_OP_ADD:    result_real = op1_real + op2_real;
            FP_OP_SUB:    result_real = op1_real - op2_real;
            FP_OP_MUL:    result_real = op1_real * op2_real;
            FP_OP_DIV:    result_real = op1_real / op2_real;
            FP_OP_SQRT:   result_real = $sqrt(op1_real);
            
            FP_OP_FMADD:  result_real = (op1_real * op2_real) + op3_real;
            FP_OP_FMSUB:  result_real = (op1_real * op2_real) - op3_real;
            FP_OP_FNMSUB: result_real = -(op1_real * op2_real) + op3_real;
            FP_OP_FNMADD: result_real = -(op1_real * op2_real) - op3_real;
            
            FP_OP_MIN:    result_real = (op1_real < op2_real) ? op1_real : op2_real;
            FP_OP_MAX:    result_real = (op1_real > op2_real) ? op1_real : op2_real;
            
            default:      result_real = 0.0;
        endcase
        
        // Convert back to IEEE 754
        exp_fp_result = $shortrealtobits(result_real);
    endfunction
    
    //===========================================
    // Get Instruction Name
    //===========================================
    virtual function string get_instruction_name();
        case (opcode)
            OP_FP: begin
                case (fp_operation)
                    FP_OP_ADD:      return "FADD.S";
                    FP_OP_SUB:      return "FSUB.S";
                    FP_OP_MUL:      return "FMUL.S";
                    FP_OP_DIV:      return "FDIV.S";
                    FP_OP_SQRT:     return "FSQRT.S";
                    FP_OP_MIN:      return "FMIN.S";
                    FP_OP_MAX:      return "FMAX.S";
                    FP_OP_SGNJ:     return "FSGNJ.S";
                    FP_OP_SGNJN:    return "FSGNJN.S";
                    FP_OP_SGNJX:    return "FSGNJX.S";
                    FP_OP_CVT_W:    return "FCVT.W.S";
                    FP_OP_CVT_WU:   return "FCVT.WU.S";
                    FP_OP_CVT_S_W:  return "FCVT.S.W";
                    FP_OP_CVT_S_WU: return "FCVT.S.WU";
                    FP_OP_MV_X_W:   return "FMV.X.W";
                    FP_OP_MV_W_X:   return "FMV.W.X";
                    FP_OP_CMP_EQ:   return "FEQ.S";
                    FP_OP_CMP_LT:   return "FLT.S";
                    FP_OP_CMP_LE:   return "FLE.S";
                    FP_OP_CLASS:    return "FCLASS.S";
                    default:        return "FP_UNKNOWN";
                endcase
            end
            OP_FMADD:  return "FMADD.S";
            OP_FMSUB:  return "FMSUB.S";
            OP_FNMSUB: return "FNMSUB.S";
            OP_FNMADD: return "FNMADD.S";
            OP_FLW:    return "FLW";
            OP_FSW:    return "FSW";
            default:   return opcode.name();
        endcase
    endfunction
    
    //===========================================
    // Convert to String (for Debug)
    //===========================================
    virtual function string convert2string();
        string s;
        s = super.convert2string();
        s = {s, "\n=========================================="};
        s = {s, "\n INSTRUCTION DETAILS"};
        s = {s, "\n=========================================="};
        s = {s, $sformatf("\n Instruction:    0x%08h (%s)", instruction, get_instruction_name())};
        s = {s, $sformatf("\n Opcode:         %s (0x%02h)", opcode.name(), opcode)};
        s = {s, $sformatf("\n Category:       %s", instr_category.name())};
        
        if (instr_category == INSTR_CAT_FLOAT) begin
            s = {s, $sformatf("\n FP Operation:   %s", fp_operation.name())};
            s = {s, $sformatf("\n Registers:      rd=f%0d, rs1=f%0d, rs2=f%0d", rd, rs1, rs2)};
            if (opcode inside {OP_FMADD, OP_FMSUB, OP_FNMSUB, OP_FNMADD}) begin
                s = {s, $sformatf(", rs3=f%0d", rs3)};
            end
            s = {s, $sformatf("\n Rounding Mode:  %s", rm.name())};
            s = {s, $sformatf("\n Operand1:       0x%08h (%f)", fp_operand1, $bitstoshortreal(fp_operand1))};
            s = {s, $sformatf("\n Operand2:       0x%08h (%f)", fp_operand2, $bitstoshortreal(fp_operand2))};
            if (opcode inside {OP_FMADD, OP_FMSUB, OP_FNMSUB, OP_FNMADD}) begin
                s = {s, $sformatf("\n Operand3:       0x%08h (%f)", fp_operand3, $bitstoshortreal(fp_operand3))};
            end
        end
        
        s = {s, "\n=========================================="};
        s = {s, "\n DUT OUTPUTS"};
        s = {s, "\n=========================================="};
        s = {s, $sformatf("\n PC:             0x%08h", pc_curr)};
        s = {s, $sformatf("\n DMEM Addr:      0x%08h", dmem_addr)};
        s = {s, $sformatf("\n DMEM DataIN:    0x%08h", dmem_dataIN)};
        s = {s, $sformatf("\n DMEM DataOUT:   0x%08h", dmem_dataOUT)};
        s = {s, $sformatf("\n func3_MEM:      0x%01h", func3_MEM)};
        s = {s, $sformatf("\n memW_en_MEM:    %0b", memW_en_MEM)};
        s = {s, "\n==========================================\n"};
        
        return s;
    endfunction
    
    //===========================================
    // Do Copy (for UVM)
    //===========================================
    virtual function void do_copy(uvm_object rhs);
        fpu_packet rhs_;
        if (!$cast(rhs_, rhs)) begin
            `uvm_fatal("DO_COPY", "Cast failed")
        end
        super.do_copy(rhs);
        
        this.instruction = rhs_.instruction;
        this.dmem_dataIN = rhs_.dmem_dataIN;
        this.fp_operand1 = rhs_.fp_operand1;
        this.fp_operand2 = rhs_.fp_operand2;
        this.fp_operand3 = rhs_.fp_operand3;
        this.fp_reg_dest = rhs_.fp_reg_dest;
        this.latency = rhs_.latency;
    endfunction
    
    //===========================================
    // Do Compare (for UVM)
    //===========================================
    virtual function bit do_compare(uvm_object rhs, uvm_comparer comparer);
        fpu_packet rhs_;
        if (!$cast(rhs_, rhs)) return 0;
        
        return (super.do_compare(rhs, comparer) &&
                (this.instruction == rhs_.instruction) &&
                (this.dmem_addr == rhs_.dmem_addr) &&
                (this.pc_curr == rhs_.pc_curr));
    endfunction
    
endclass
