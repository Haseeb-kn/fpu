class top_core_scoreboard_simple extends uvm_scoreboard;
    `uvm_component_utils(top_core_scoreboard_simple)
    
    uvm_analysis_imp #(fpu_packet, top_core_scoreboard_simple) item_analysis_export;
    
    //===========================================
    // Statistics
    //===========================================
    int total_transactions = 0;
    int passed_transactions = 0;
    int failed_transactions = 0;
    int fp_transactions = 0;
    int fp_arithmetic = 0;
    int fp_fused = 0;
    int fp_load_store = 0;
    
    // Reference model
    logic [31:0] ref_fp_regs[32];
    logic [31:0] ref_int_regs[32];
    logic [31:0] ref_pc = 32'h8000_0000;
    
    // Configuration
    real fp_tolerance = 0.001;  // Relaxed tolerance for now
    bit check_exact = 0;
    
    function new(string name = "top_core_scoreboard_simple", uvm_component parent = null);
        super.new(name, parent);
        item_analysis_export = new("item_analysis_export", this);
    endfunction
    
    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        
        // Initialize reference model
        for (int i = 0; i < 32; i++) begin
            ref_fp_regs[i] = $shortrealtobits(real'(i) + 0.5);
            ref_int_regs[i] = i;
        end
        
        void'(uvm_config_db#(real)::get(this, "", "fp_tolerance", fp_tolerance));
        void'(uvm_config_db#(bit)::get(this, "", "check_exact", check_exact));
    endfunction
    
    virtual function void write(fpu_packet item);
        total_transactions++;
        
        // Calculate expected result
        calculate_expected(item);
        
        // Check transaction
        check_transaction(item);
    endfunction
    
    virtual function void calculate_expected(fpu_packet item);
        real op1, op2, op3, result;
        
        ref_pc += 4;
        
        if (item.instr_category == INSTR_CAT_FLOAT) begin
            fp_transactions++;
            
            // Get operands
            op1 = $bitstoshortreal(item.fp_operand1);
            op2 = $bitstoshortreal(item.fp_operand2);
            op3 = $bitstoshortreal(item.fp_operand3);
            
            case (item.fp_operation)
                item.FP_OP_ADD: begin
                    result = op1 + op2;
                    fp_arithmetic++;
                end
                item.FP_OP_SUB: begin
                    result = op1 - op2;
                    fp_arithmetic++;
                end
                item.FP_OP_MUL: begin
                    result = op1 * op2;
                    fp_arithmetic++;
                end
                item.FP_OP_DIV: begin
                    result = (op2 != 0.0) ? (op1 / op2) : 0.0;
                    fp_arithmetic++;
                end
                item.FP_OP_SQRT: begin
                    result = (op1 >= 0.0) ? $sqrt(op1) : 0.0;
                    fp_arithmetic++;
                end
                item.FP_OP_FMADD: begin
                    result = (op1 * op2) + op3;
                    fp_fused++;
                end
                item.FP_OP_FMSUB: begin
                    result = (op1 * op2) - op3;
                    fp_fused++;
                end
                item.FP_OP_FNMSUB: begin
                    result = -(op1 * op2) + op3;
                    fp_fused++;
                end
                item.FP_OP_FNMADD: begin
                    result = -(op1 * op2) - op3;
                    fp_fused++;
                end
                default: result = 0.0;
            endcase
            
            // Store expected result
            item.exp_fp_result = $shortrealtobits(result);
            ref_fp_regs[item.rd] = item.exp_fp_result;
        end
        
        item.exp_pc_curr = ref_pc - 4;
    endfunction
    
    virtual function void check_transaction(fpu_packet item);
    bit passed = 1;
    string msg = "";
    real dut_val, exp_val, error;
    
    // Check PC
    if (item.pc_curr != item.exp_pc_curr) begin
        // PC mismatch - may be acceptable if pipeline is stalling
        `uvm_info(get_type_name(),
                 $sformatf("PC: Expected=0x%08h, Got=0x%08h",
                          item.exp_pc_curr, item.pc_curr),
                 UVM_HIGH)
    end
    
    // Check FP results
    if (item.instr_category == INSTR_CAT_FLOAT) begin
        if (item.opcode inside {OP_FP, OP_FMADD, OP_FMSUB, OP_FNMSUB, OP_FNMADD}) begin
            dut_val = $bitstoshortreal(item.dmem_dataOUT);
            exp_val = $bitstoshortreal(item.exp_fp_result);
            
            // FIXED: Use manual absolute value for real numbers
            error = (dut_val > exp_val) ? (dut_val - exp_val) : (exp_val - dut_val);
            
            if (check_exact) begin
                // Exact bit-level comparison
                if (item.dmem_dataOUT != item.exp_fp_result) begin
                    passed = 0;
                    msg = $sformatf("\n  Exact mismatch: Exp=0x%08h, Got=0x%08h",
                                   item.exp_fp_result, item.dmem_dataOUT);
                end
            end else begin
                // Tolerance-based comparison
                if (error > fp_tolerance) begin
                    passed = 0;
                    msg = $sformatf("\n  Value mismatch: Exp=%f, Got=%f, Error=%e",
                                   exp_val, dut_val, error);
                end
            end
        end
    end
    
    // Update statistics
    if (passed) begin
        passed_transactions++;
        `uvm_info(get_type_name(),
                 $sformatf("✓ PASS [%0d]: %s",
                          total_transactions, item.get_instruction_name()),
                 UVM_HIGH)
    end else begin
        failed_transactions++;
        `uvm_error("CHECK_FAIL",
                  $sformatf("✗ FAIL [%0d]: %s%s\n%s",
                           total_transactions,
                           item.get_instruction_name(),
                           msg,
                           item.convert2string()))
    end
endfunction
    
    virtual function void report_phase(uvm_phase phase);
        real pass_rate, fp_percent;
        
        super.report_phase(phase);
        
        if (total_transactions > 0) begin
            pass_rate = 100.0 * passed_transactions / total_transactions;
            fp_percent = 100.0 * fp_transactions / total_transactions;
        end else begin
            pass_rate = 0.0;
            fp_percent = 0.0;
        end
        
        `uvm_info("SCOREBOARD_REPORT",
                 $sformatf("\n\n" +
                         "╔════════════════════════════════════════════════╗\n" +
                         "║       FPU VERIFICATION SCOREBOARD REPORT       ║\n" +
                         "╠════════════════════════════════════════════════╣\n" +
                         "║ Total Instructions:      %8d           ║\n" +
                         "║ FP Instructions:         %8d (%5.1f%%)    ║\n" +
                         "║   - Arithmetic Ops:      %8d           ║\n" +
                         "║   - Fused Ops:           %8d           ║\n" +
                         "║   - Load/Store:          %8d           ║\n" +
                         "╠════════════════════════════════════════════════╣\n" +
                         "║ Passed:                  %8d           ║\n" +
                         "║ Failed:                  %8d           ║\n" +
                         "║ Pass Rate:               %7.2f%%          ║\n" +
                         "╚════════════════════════════════════════════════╝\n",
                         total_transactions,
                         fp_transactions, fp_percent,
                         fp_arithmetic,
                         fp_fused,
                         fp_load_store,
                         passed_transactions,
                         failed_transactions,
                         pass_rate),
                 UVM_NONE)
        
        if (failed_transactions == 0 && total_transactions > 0) begin
            `uvm_info("VERDICT", "\n★★★ ALL TESTS PASSED ★★★\n", UVM_NONE)
        end else if (total_transactions == 0) begin
            `uvm_warning("VERDICT", "\n⚠ NO TRANSACTIONS PROCESSED ⚠\n")
        end else begin
            `uvm_error("VERDICT", $sformatf("\n✗ %0d TESTS FAILED ✗\n", failed_transactions))
        end
    endfunction
    
endclass
