

class top_core_coverage extends uvm_subscriber #(top_core_seq_item);
    `uvm_component_utils(top_core_coverage)
    
    // Coverage groups
    covergroup instruction_cg;
        // Instruction opcode coverage
        opcode_cp: coverpoint trans_item.opcode {
            bins load_op[] = {OP_LOAD, OP_FLW};
            bins store_op[] = {OP_STORE, OP_FSW};
            bins fp_op[] = {OP_FP, OP_FMADD, OP_FMSUB, OP_FNMSUB, OP_FNMADD};
            bins int_op[] = {OP_OP, OP_OP_IMM};
            bins branch_op = {OP_BRANCH};
            bins jump_op[] = {OP_JAL, OP_JALR};
            bins system_op = {OP_SYSTEM};
        }
        
        // Instruction category coverage
        category_cp: coverpoint trans_item.instr_category;
        
        // func3_MEM coverage
        func3_cp: coverpoint trans_item.func3_MEM {
            bins func3_vals[] = {[0:7]};
        }
        
        // Memory write enable transitions
        mem_wen_cp: coverpoint trans_item.memW_en_MEM {
            bins low_to_high = (0 => 1);
            bins high_to_low = (1 => 0);
            bins stable_low = (0 => 0);
            bins stable_high = (1 => 1);
        }
        
        // DMEM address ranges
        dmem_addr_cp: coverpoint trans_item.dmem_addr {
            bins low_range  = {[32'h0000_0000:32'h0000_0FFF]};
            bins mid_range  = {[32'h0000_1000:32'h000F_FFFF]};
            bins high_range = {[32'h0010_0000:32'hFFFF_FFFF]};
        }
        
        // Cross coverage
        opcode_mem_wen: cross opcode_cp, mem_wen_cp;
        category_func3: cross category_cp, func3_cp;
        
    endgroup
    
    covergroup floating_point_cg;
        // Floating-point specific coverage
        fp_opcode_cp: coverpoint trans_item.opcode {
            bins basic_fp = {OP_FP};
            bins fused_fp[] = {OP_FMADD, OP_FMSUB, OP_FNMSUB, OP_FNMADD};
            bins fp_mem[] = {OP_FLW, OP_FSW};
        }
        
        // Rounding mode coverage
        rm_cp: coverpoint trans_item.rm {
            bins rne = {RM_RNE};
            bins rtz = {RM_RTZ};
            bins rdn = {RM_RDN};
            bins rup = {RM_RUP};
            bins rmm = {RM_RMM};
            bins dyn = {RM_DYN};
        }
        
        // Floating-point register usage
        fp_reg_rs1_cp: coverpoint trans_item.rs1 {
            bins fp_regs[] = {[0:31]};
        }
        
        fp_reg_rs2_cp: coverpoint trans_item.rs2 {
            bins fp_regs[] = {[0:31]};
        }
        
        fp_reg_rd_cp: coverpoint trans_item.rd {
            bins fp_regs[] = {[0:31]};
        }
        
        // FP operation types (based on funct7)
        fp_operation_cp: coverpoint trans_item.funct7[6:2] {
            bins fadd = {5'b00000};
            bins fsub = {5'b00001};
            bins fmul = {5'b00010};
            bins fdiv = {5'b00011};
            bins fsqrt = {5'b01011};
            bins fsgnj = {5'b00100}; // with funct3 = 000
            bins fminmax = {5'b00101};
            bins fcmp = {5'b10100};
            bins fcvt = {5'b11000, 5'b11010};
            bins fmv = {5'b11100, 5'b11110};
            bins fclass = {5'b11100}; // with funct3 = 001
        }
        
        // Cross coverage for FP operations
        fp_op_rm: cross fp_operation_cp, rm_cp;
        
    endgroup
    
    top_core_seq_item trans_item;
    
    function new(string name = "top_core_coverage", uvm_component parent = null);
        super.new(name, parent);
        instruction_cg = new();
        floating_point_cg = new();
    endfunction
    
    virtual function void write(top_core_seq_item t);
        trans_item = t;
        
        // Sample coverage
        instruction_cg.sample();
        
        if (trans_item.instr_category == INSTR_CAT_FLOAT) begin
            floating_point_cg.sample();
        end
    endfunction
    
    virtual function void report_phase(uvm_phase phase);
        super.report_phase(phase);
        
        `uvm_info(get_type_name(), "Coverage Report:", UVM_LOW)
        `uvm_info(get_type_name(), $sformatf("Instruction Coverage: %0.2f%%", 
                  instruction_cg.get_coverage()), UVM_LOW)
        `uvm_info(get_type_name(), $sformatf("Floating-Point Coverage: %0.2f%%", 
                  floating_point_cg.get_coverage()), UVM_LOW)
    endfunction
    
endclass

