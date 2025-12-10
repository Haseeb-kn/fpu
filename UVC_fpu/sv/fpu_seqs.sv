
class top_core_base_seq extends uvm_sequence #(fpu_packet);
    `uvm_object_utils(top_core_base_seq)
    
    // Configuration
    int num_transactions = 100;
    bit enable_fp_ops = 1;
    
    // Register file state (simplified)
    logic [31:0] int_regs[32];
    logic [31:0] fp_regs[32];
    
    function new(string name = "top_core_base_seq");
        super.new(name);
        // Initialize register files
        foreach (int_regs[i]) int_regs[i] = i;
        foreach (fp_regs[i]) fp_regs[i] = {i, 24'h0};
    endfunction
    
    virtual task body();
        fpu_packet item;
        
        `uvm_info(get_type_name(), $sformatf("Starting base sequence with %0d transactions", num_transactions), UVM_LOW)
        
        for (int i = 0; i < num_transactions; i++) begin
            item = fpu_packet::type_id::create($sformatf("item_%0d", i));
            start_item(item);
            
            if (!item.randomize() with {
                // Randomize with some constraints
                latency inside {[1:5]};
                
                // Bias toward floating-point operations if enabled
                if (enable_fp_ops) {
                    instr_category dist {
                        INSTR_CAT_FLOAT   :/ 3,
                        INSTR_CAT_INTEGER :/ 2,
                        INSTR_CAT_LOAD    :/ 1,
                        INSTR_CAT_STORE   :/ 1,
                        INSTR_CAT_BRANCH  :/ 1
                    };
                } else {
                    instr_category dist {
                        INSTR_CAT_INTEGER :/ 3,
                        INSTR_CAT_LOAD    :/ 2,
                        INSTR_CAT_STORE   :/ 2,
                        INSTR_CAT_BRANCH  :/ 1
                    };
                }
            }) begin
                `uvm_error("RAND_FAIL", "Randomization failed")
            end
            
            // Generate instruction based on category
            generate_instruction(item);
            
            finish_item(item);
            
            // Wait between transactions
            #10;
        end
        
        `uvm_info(get_type_name(), "Base sequence completed", UVM_LOW)
    endtask
    
    // Generate specific instruction
    virtual function void generate_instruction(fpu_packet item);
        case (item.instr_category)
            INSTR_CAT_FLOAT: generate_fp_instruction(item);
            INSTR_CAT_LOAD:  generate_load_instruction(item);
            INSTR_CAT_STORE: generate_store_instruction(item);
            INSTR_CAT_BRANCH: generate_branch_instruction(item);
            default: generate_integer_instruction(item);
        endcase
        
        // Decode the generated instruction
        item.decode_instruction();
    endfunction
    
    // Generate floating-point instruction
    virtual function void generate_fp_instruction(fpu_packet item);
        randcase
            // Basic FP ops
            30: generate_fp_arithmetic(item);
            20: generate_fp_fused(item);
            15: generate_fp_conversion(item);
            15: generate_fp_compare(item);
            10: generate_fp_move(item);
            5:  generate_fp_classify(item);
            5:  generate_fp_minmax(item);
        endcase
    endfunction
    
    // Generate FP arithmetic (FADD.S, FSUB.S, FMUL.S, FDIV.S)
    virtual function void generate_fp_arithmetic(fpu_packet item);
        static string ops[] = {"FADD", "FSUB", "FMUL", "FDIV"};
        string op = ops[$urandom_range(0, 3)];
        logic [4:0] rs1 = $urandom_range(0, 31);
        logic [4:0] rs2 = $urandom_range(0, 31);
        logic [4:0] rd = $urandom_range(0, 31);
        rounding_mode_e rm = rounding_mode_e'($urandom_range(0, 4));
        
        case (op)
            "FADD": item.instruction = encode_fpu_r(rd, rs1, rs2, FADD_S, rm);
            "FSUB": item.instruction = encode_fpu_r(rd, rs1, rs2, FSUB_S, rm);
            "FMUL": item.instruction = encode_fpu_r(rd, rs1, rs2, FMUL_S, rm);
            "FDIV": item.instruction = encode_fpu_r(rd, rs1, rs2, FDIV_S, rm);
        endcase
        
        // Set operands and expected result
        item.fp_operand1 = fp_regs[rs1];
        item.fp_operand2 = fp_regs[rs2];
        item.fp_reg_dest = rd;
        
        `uvm_info("GEN_INST", $sformatf("Generated FP %s.S: f%0d = f%0d %s f%0d (rm=%0d)", 
                  op, rd, rs1, op, rs2, rm), UVM_HIGH)
    endfunction
    
    // Generate fused multiply-add instructions
    virtual function void generate_fp_fused(fpu_packet item);
        static opcode_e ops[] = {OP_FMADD, OP_FMSUB, OP_FNMSUB, OP_FNMADD};
        opcode_e op = ops[$urandom_range(0, 3)];
        logic [4:0] rs1 = $urandom_range(0, 31);
        logic [4:0] rs2 = $urandom_range(0, 31);
        logic [4:0] rs3 = $urandom_range(0, 31);
        logic [4:0] rd = $urandom_range(0, 31);
        rounding_mode_e rm = rounding_mode_e'($urandom_range(0, 4));
        
        item.instruction = encode_fpu_r4(rd, rs1, rs2, rs3, op, rm);
        
        item.fp_operand1 = fp_regs[rs1];
        item.fp_operand2 = fp_regs[rs2];
        item.fp_operand3 = fp_regs[rs3];
        item.fp_reg_dest = rd;
        
        `uvm_info("GEN_INST", $sformatf("Generated %s.S: f%0d = (f%0d * f%0d) op f%0d", 
                  op.name(), rd, rs1, rs2, rs3), UVM_HIGH)
    endfunction
    
    // Generate load instruction
    virtual function void generate_load_instruction(fpu_packet item);
        // Simple ADDI for address calculation
        item.instruction = {12'h100, 5'd1, 3'b000, 5'd2, 7'b0010011}; // addi x2, x1, 0x100
        item.dmem_dataIN = $urandom();
        
        `uvm_info("GEN_INST", "Generated LOAD instruction", UVM_HIGH)
    endfunction
    
    // Generate store instruction
    virtual function void generate_store_instruction(fpu_packet item);
        // Simple SW instruction
        item.instruction = {7'h00, 5'd2, 5'd1, 3'b010, 5'h00, 7'b0100011}; // sw x2, 0(x1)
        
        `uvm_info("GEN_INST", "Generated STORE instruction", UVM_HIGH)
    endfunction
    
    // Generate branch instruction
    virtual function void generate_branch_instruction(fpu_packet item);
        // BEQ instruction
        item.instruction = {7'h00, 5'd2, 5'd1, 3'b000, 4'h0, 1'b1, 6'h00, 7'b1100011}; // beq x1, x2, +4
        
        `uvm_info("GEN_INST", "Generated BRANCH instruction", UVM_HIGH)
    endfunction
    
    // Generate integer instruction
    virtual function void generate_integer_instruction(fpu_packet item);
        // Simple ADD instruction
        item.instruction = {7'h00, 5'd2, 5'd1, 3'b000, 5'd3, 7'b0110011}; // add x3, x1, x2
        
        `uvm_info("GEN_INST", "Generated INTEGER instruction", UVM_HIGH)
    endfunction
    
    // Additional FP instruction generators (stubs - implement as needed)
    virtual function void generate_fp_conversion(fpu_packet item);
        item.instruction = {5'b11000, 5'd0, 5'd1, 3'b000, 5'd2, OP_FP}; // FCVT.W.S
    endfunction
    
    virtual function void generate_fp_compare(fpu_packet item);
        item.instruction = {5'b10100, 5'd2, 5'd1, 3'b010, 5'd3, OP_FP}; // FEQ.S
    endfunction
    
    virtual function void generate_fp_move(fpu_packet item);
        item.instruction = {5'b11100, 5'd0, 5'd1, 3'b000, 5'd2, OP_FP}; // FMV.X.W
    endfunction
    
    virtual function void generate_fp_classify(fpu_packet item);
        item.instruction = {5'b11100, 5'd0, 5'd1, 3'b001, 5'd2, OP_FP}; // FCLASS.S
    endfunction
    
    virtual function void generate_fp_minmax(fpu_packet item);
        item.instruction = {5'b00101, 5'd2, 5'd1, 3'b000, 5'd3, OP_FP}; // FMIN.S
    endfunction
    
endclass







class top_core_load_seq extends top_core_base_seq;
    `uvm_object_utils(top_core_load_seq)
    
    int num_loads = 20;
    
    function new(string name = "top_core_load_seq");
        super.new(name);
    endfunction
    
    virtual task body();
        fpu_packet item;
        
        `uvm_info(get_type_name(), $sformatf("Starting load sequence with %0d loads", num_loads), UVM_LOW)
        
        for (int i = 0; i < num_loads; i++) begin
            item = fpu_packet::type_id::create($sformatf("load_item_%0d", i));
            start_item(item);
            
            if (!item.randomize() with {
                instr_category == INSTR_CAT_LOAD;
                latency inside {[2:4]};
            }) begin
                `uvm_error("RAND_FAIL", "Randomization failed for load")
            end
            
            generate_load_instruction(item);
            finish_item(item);
            
            #10;
        end
        
        `uvm_info(get_type_name(), "Load sequence completed", UVM_LOW)
    endtask
    
endclass







class top_core_store_seq extends top_core_base_seq;
    `uvm_object_utils(top_core_store_seq)
    
    int num_stores = 20;
    
    function new(string name = "top_core_store_seq");
        super.new(name);
    endfunction
    
    virtual task body();
        fpu_packet item;
        
        `uvm_info(get_type_name(), $sformatf("Starting store sequence with %0d stores", num_stores), UVM_LOW)
        
        for (int i = 0; i < num_stores; i++) begin
            item = fpu_packet::type_id::create($sformatf("store_item_%0d", i));
            start_item(item);
            
            if (!item.randomize() with {
                instr_category == INSTR_CAT_STORE;
                latency inside {[2:4]};
            }) begin
                `uvm_error("RAND_FAIL", "Randomization failed for store")
            end
            
            generate_store_instruction(item);
            finish_item(item);
            
            #10;
        end
        
        `uvm_info(get_type_name(), "Store sequence completed", UVM_LOW)
    endtask
    
endclass


class top_core_branch_seq extends top_core_base_seq;
    `uvm_object_utils(top_core_branch_seq)
    
    int num_branches = 15;
    
    function new(string name = "top_core_branch_seq");
        super.new(name);
    endfunction
    
    virtual task body();
        fpu_packet item;
        
        `uvm_info(get_type_name(), $sformatf("Starting branch sequence with %0d branches", num_branches), UVM_LOW)
        
        for (int i = 0; i < num_branches; i++) begin
            item = fpu_packet::type_id::create($sformatf("branch_item_%0d", i));
            start_item(item);
            
            if (!item.randomize() with {
                instr_category == INSTR_CAT_BRANCH;
                latency inside {[1:3]};
            }) begin
                `uvm_error("RAND_FAIL", "Randomization failed for branch")
            end
            
            generate_branch_instruction(item);
            finish_item(item);
            
            #10;
        end
        
        `uvm_info(get_type_name(), "Branch sequence completed", UVM_LOW)
    endtask
    
endclass


class riscv_f_extension_seq extends top_core_base_seq;
    `uvm_object_utils(riscv_f_extension_seq)
    
    // Test configuration
    int num_fp_tests = 50;
    bit test_all_ops = 1;
    
    function new(string name = "riscv_f_extension_seq");
        super.new(name);
        enable_fp_ops = 1;
    endfunction
    
    virtual task body();
        fpu_packet item;
        
        `uvm_info(get_type_name(), "Starting comprehensive F-extension test sequence", UVM_LOW)
        
        if (test_all_ops) begin
            test_fp_arithmetic();
            test_fp_fused_ops();
            test_fp_conversions();
            test_fp_comparisons();
            test_fp_moves();
            test_fp_load_store();
            test_fp_special();
        end
        
        `uvm_info(get_type_name(), "F-extension test sequence completed", UVM_LOW)
    endtask
    
    virtual task test_fp_arithmetic();
        string ops[] = {"FADD", "FSUB", "FMUL", "FDIV"};
        fpu_packet item;
        
        foreach (ops[op]) begin
            for (int i = 0; i < num_fp_tests/ops.size(); i++) begin
                item = fpu_packet::type_id::create($sformatf("fp_arith_%s_%0d", ops[op], i));
                start_item(item);
                
                item.latency = $urandom_range(3, 8);
                generate_fp_instruction_specific(item, ops[op]);
                
                finish_item(item);
                #10;
            end
        end
    endtask
    
    virtual task test_fp_fused_ops();
        string ops[] = {"FMADD", "FMSUB", "FNMSUB", "FNMADD"};
        fpu_packet item;
        
        foreach (ops[op]) begin
            for (int i = 0; i < num_fp_tests/ops.size(); i++) begin
                item = fpu_packet::type_id::create($sformatf("fp_fused_%s_%0d", ops[op], i));
                start_item(item);
                
                item.latency = $urandom_range(4, 10);
                generate_fp_fused_specific(item, ops[op]);
                
                finish_item(item);
                #10;
            end
        end
    endtask
    
    virtual function void generate_fp_instruction_specific(fpu_packet item, string op);
        logic [4:0] rs1 = $urandom_range(1, 30);
        logic [4:0] rs2 = $urandom_range(1, 30);
        logic [4:0] rd = $urandom_range(1, 30);
        rounding_mode_e rm = rounding_mode_e'($urandom_range(0, 4));
        
        case (op)
            "FADD": item.instruction = encode_fpu_r(rd, rs1, rs2, FADD_S, rm);
            "FSUB": item.instruction = encode_fpu_r(rd, rs1, rs2, FSUB_S, rm);
            "FMUL": item.instruction = encode_fpu_r(rd, rs1, rs2, FMUL_S, rm);
            "FDIV": item.instruction = encode_fpu_r(rd, rs1, rs2, FDIV_S, rm);
            default: item.instruction = encode_fpu_r(rd, rs1, rs2, FADD_S, rm);
        endcase
    endfunction
    
    virtual function void generate_fp_fused_specific(fpu_packet item, string op);
        logic [4:0] rs1 = $urandom_range(1, 30);
        logic [4:0] rs2 = $urandom_range(1, 30);
        logic [4:0] rs3 = $urandom_range(1, 30);
        logic [4:0] rd = $urandom_range(1, 30);
        rounding_mode_e rm = rounding_mode_e'($urandom_range(0, 4));
        
        case (op)
            "FMADD":   item.instruction = encode_fpu_r4(rd, rs1, rs2, rs3, OP_FMADD, rm);
            "FMSUB":   item.instruction = encode_fpu_r4(rd, rs1, rs2, rs3, OP_FMSUB, rm);
            "FNMSUB":  item.instruction = encode_fpu_r4(rd, rs1, rs2, rs3, OP_FNMSUB, rm);
            "FNMADD":  item.instruction = encode_fpu_r4(rd, rs1, rs2, rs3, OP_FNMADD, rm);
            default:   item.instruction = encode_fpu_r4(rd, rs1, rs2, rs3, OP_FMADD, rm);
        endcase
    endfunction
    
    // Stub implementations for other test methods
    virtual task test_fp_conversions();
        // Implement conversion tests
    endtask
    
    virtual task test_fp_comparisons();
        // Implement comparison tests
    endtask
    
    virtual task test_fp_moves();
        // Implement move tests
    endtask
    
    virtual task test_fp_load_store();
        // Implement load/store tests
    endtask
    
    virtual task test_fp_special();
        // Implement special instruction tests (FCLASS, FSQRT, etc.)
    endtask
    
endclass

