
import riscv_instruction_pkg::*;

class top_core_seq_item extends uvm_sequence_item;
    `uvm_object_utils(top_core_seq_item)
    
    // DUT Inputs (randomized)
    rand logic [31:0] instruction;
    rand logic [31:0] dmem_dataIN;
    
    // DUT Outputs (monitored)
    logic [31:0] dmem_addr;
    logic [31:0] pc_curr;
    logic [2:0]  func3_MEM;
    logic        memW_en_MEM;
    logic [31:0] dmem_dataOUT;
    
    // Expected outputs (for scoreboard)
    logic [31:0] exp_dmem_addr;
    logic [31:0] exp_pc_curr;
    logic [2:0]  exp_func3_MEM;
    logic        exp_memW_en_MEM;
    logic [31:0] exp_dmem_dataOUT;
    
    // Timing
    rand int latency;
    
    // Instruction decoding
    opcode_e opcode;
    logic [4:0] rs1;
    logic [4:0] rs2;
    logic [4:0] rd;
    logic [2:0] funct3;
    logic [6:0] funct7;
    rounding_mode_e rm;
    
    // Floating-point specific
    rand logic [31:0] fp_operand1;
    rand logic [31:0] fp_operand2;
    rand logic [31:0] fp_operand3;  // For FMADD etc.
    rand logic [31:0] fp_result;
    rand logic [4:0]  fp_reg_dest;
    
    // Control
    rand instr_category_e instr_category;
    
    // Constraints
    constraint valid_latency {
        latency inside {[1:10]};
    }
    
    constraint fp_constraints {
        if (instr_category == INSTR_CAT_FLOAT) {
            instruction[6:0] inside {OP_FP, OP_FMADD, OP_FMSUB, OP_FNMSUB, OP_FNMADD};
        }
    }
    
    function new(string name = "top_core_seq_item");
        super.new(name);
    endfunction
    
    // Decode instruction
    virtual function void decode_instruction();
        opcode = opcode_e'(instruction[6:0]);
        rs1 = instruction[19:15];
        rs2 = instruction[24:20];
        rd = instruction[11:7];
        funct3 = instruction[14:12];
        funct7 = instruction[31:25];
        rm = rounding_mode_e'(instruction[14:12]);
        
        // Determine instruction category
        case (opcode)
            OP_LOAD, OP_FLW:      instr_category = INSTR_CAT_LOAD;
            OP_STORE, OP_FSW:     instr_category = INSTR_CAT_STORE;
            OP_FP, OP_FMADD, OP_FMSUB, OP_FNMSUB, OP_FNMADD: 
                instr_category = INSTR_CAT_FLOAT;
            OP_BRANCH:            instr_category = INSTR_CAT_BRANCH;
            OP_OP, OP_OP_IMM, OP_LUI, OP_AUIPC: 
                instr_category = INSTR_CAT_INTEGER;
            OP_SYSTEM:            instr_category = INSTR_CAT_SYSTEM;
            default:              instr_category = INSTR_CAT_INTEGER;
        endcase
    endfunction
    
    // UVM field automation
    `uvm_object_utils_begin(top_core_seq_item)
        `uvm_field_int(instruction, UVM_ALL_ON)
        `uvm_field_int(dmem_dataIN, UVM_ALL_ON)
        `uvm_field_int(dmem_addr, UVM_ALL_ON)
        `uvm_field_int(pc_curr, UVM_ALL_ON)
        `uvm_field_int(func3_MEM, UVM_ALL_ON)
        `uvm_field_int(memW_en_MEM, UVM_ALL_ON)
        `uvm_field_int(dmem_dataOUT, UVM_ALL_ON)
        `uvm_field_int(latency, UVM_ALL_ON)
        `uvm_field_enum(opcode_e, opcode, UVM_ALL_ON)
        `uvm_field_enum(instr_category_e, instr_category, UVM_ALL_ON)
    `uvm_object_utils_end
    
    // Copy function
    virtual function void do_copy(uvm_object rhs);
        top_core_seq_item rhs_;
        if (!$cast(rhs_, rhs)) begin
            `uvm_fatal("do_copy", "cast failed")
        end
        super.do_copy(rhs);
        
        // Copy all fields
        instruction = rhs_.instruction;
        dmem_dataIN = rhs_.dmem_dataIN;
        dmem_addr = rhs_.dmem_addr;
        pc_curr = rhs_.pc_curr;
        func3_MEM = rhs_.func3_MEM;
        memW_en_MEM = rhs_.memW_en_MEM;
        dmem_dataOUT = rhs_.dmem_dataOUT;
        
        exp_dmem_addr = rhs_.exp_dmem_addr;
        exp_pc_curr = rhs_.exp_pc_curr;
        exp_func3_MEM = rhs_.exp_func3_MEM;
        exp_memW_en_MEM = rhs_.exp_memW_en_MEM;
        exp_dmem_dataOUT = rhs_.exp_dmem_dataOUT;
        
        latency = rhs_.latency;
        opcode = rhs_.opcode;
        rs1 = rhs_.rs1;
        rs2 = rhs_.rs2;
        rd = rhs_.rd;
        funct3 = rhs_.funct3;
        funct7 = rhs_.funct7;
        rm = rhs_.rm;
        
        fp_operand1 = rhs_.fp_operand1;
        fp_operand2 = rhs_.fp_operand2;
        fp_operand3 = rhs_.fp_operand3;
        fp_result = rhs_.fp_result;
        fp_reg_dest = rhs_.fp_reg_dest;
        
        instr_category = rhs_.instr_category;
    endfunction
    
    // Compare function
    virtual function bit do_compare(uvm_object rhs, uvm_comparer comparer);
        top_core_seq_item rhs_;
        bit status = super.do_compare(rhs, comparer);
        
        if (!$cast(rhs_, rhs)) begin
            `uvm_error("do_compare", "cast failed")
            return 0;
        end
        
        status &= (dmem_addr === rhs_.dmem_addr);
        status &= (pc_curr === rhs_.pc_curr);
        status &= (func3_MEM === rhs_.func3_MEM);
        status &= (memW_en_MEM === rhs_.memW_en_MEM);
        status &= (dmem_dataOUT === rhs_.dmem_dataOUT);
        
        return status;
    endfunction
    
    // Convert to string
    virtual function string convert2string();
        string s = super.convert2string();
        s = {s, $sformatf("\nInstruction: 0x%08h (%s)", instruction, opcode_to_string(opcode))};
        s = {s, $sformatf("\n  rs1: f%0d, rs2: f%0d, rd: f%0d", rs1, rs2, rd)};
        s = {s, $sformatf("\n  funct3: %3b, funct7: %7b, rm: %3b", funct3, funct7, rm)};
        s = {s, $sformatf("\nDMEM Data IN:  0x%08h", dmem_dataIN)};
        s = {s, $sformatf("\nDMEM Addr:     0x%08h", dmem_addr)};
        s = {s, $sformatf("\nDMEM Data OUT: 0x%08h", dmem_dataOUT)};
        s = {s, $sformatf("\nPC Current:    0x%08h", pc_curr)};
        s = {s, $sformatf("\nFunc3 MEM:     %0d", func3_MEM)};
        s = {s, $sformatf("\nMEM Write En:  %0b", memW_en_MEM)};
        s = {s, $sformatf("\nLatency:       %0d cycles", latency)};
        return s;
    endfunction
    
    // Print function
    virtual function void print();
        `uvm_info("SEQ_ITEM", convert2string(), UVM_MEDIUM)
    endfunction
    
endclass

