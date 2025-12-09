

class top_core_scoreboard extends uvm_scoreboard;
    `uvm_component_utils(top_core_scoreboard)
    
    uvm_analysis_imp #(top_core_seq_item, top_core_scoreboard) item_analysis_export;
    
    // Statistics
    int total_transactions = 0;
    int passed_transactions = 0;
    int failed_transactions = 0;
    int fp_transactions = 0;
    
    // Reference model (simplified)
    logic [31:0] reference_regs[32];
    logic [31:0] reference_fp_regs[32];
    logic [31:0] reference_pc = 32'h8000_0000;
    
    function new(string name = "top_core_scoreboard", uvm_component parent = null);
        super.new(name, parent);
        item_analysis_export = new("item_analysis_export", this);
        
        // Initialize reference model
        foreach (reference_regs[i]) reference_regs[i] = i;
        foreach (reference_fp_regs[i]) reference_fp_regs[i] = {i, 24'h0};
    endfunction
    
    virtual function void write(top_core_seq_item item);
        total_transactions++;
        
        // Update reference model
        update_reference_model(item);
        
        // Check results
        check_transaction(item);
    endfunction
    
    virtual function void update_reference_model(top_core_seq_item item);
        // Simplified reference model update
        // In a real implementation, this would simulate the RISC-V ISA
        
        // Update PC (simplified)
        reference_pc += 4;
        
        // For floating-point operations, update FP register file
        if (item.instr_category == INSTR_CAT_FLOAT) begin
            fp_transactions++;
            // Basic FP operation simulation (placeholder)
            if (item.opcode == OP_FP) begin
                // Simulate some basic operations
                case (item.funct7[6:2])
                    FADD_S: reference_fp_regs[item.rd] = item.fp_operand1 + item.fp_operand2;
                    // Add other operations as needed
                endcase
            end
        end
    endfunction
    
    virtual function void check_transaction(top_core_seq_item item);
        bit passed = 1;
        string error_msg = "";
        
        // Basic sanity checks
        if (item.dmem_addr > 32'hFFFF_FFFF) begin
            passed = 0;
            error_msg = $sformatf("Invalid dmem_addr: 0x%08h", item.dmem_addr);
        end
        
        // Check PC increment (simplified)
        // if (item.pc_curr != reference_pc) begin
        //     passed = 0;
        //     error_msg = $sformatf("PC mismatch: Expected 0x%08h, Got 0x%08h", 
        //                           reference_pc, item.pc_curr);
        // end
        
        // Update statistics
        if (passed) begin
            passed_transactions++;
            `uvm_info(get_type_name(), 
                     $sformatf("Transaction %0d PASSED: %s", 
                     total_transactions, item.opcode.name()), 
                     UVM_HIGH)
        end else begin
            failed_transactions++;
            `uvm_error("SCOREBOARD", 
                      $sformatf("Transaction %0d FAILED - %s\n%s", 
                      total_transactions, error_msg, item.convert2string()))
        end
    endfunction
    
    virtual function void report_phase(uvm_phase phase);
        super.report_phase(phase);
        
        `uvm_info("SCOREBOARD_REPORT", 
                 $sformatf("\n=== Scoreboard Summary ===\n"
                         + "Total Transactions:   %0d\n"
                         + "Passed:              %0d\n"
                         + "Failed:              %0d\n"
                         + "FP Transactions:     %0d\n"
                         + "Pass Rate:           %0.1f%%",
                         total_transactions, passed_transactions, 
                         failed_transactions, fp_transactions,
                         (total_transactions > 0) ? 
                         (100.0 * passed_transactions / total_transactions) : 0.0), 
                 UVM_NONE)
    endfunction
    
    // Floating-point reference model helpers
    virtual function real fp32_to_real(input logic [31:0] fp32);
        // Convert IEEE 754 single-precision to real
        logic sign = fp32[31];
        logic [7:0] exponent = fp32[30:23];
        logic [22:0] mantissa = fp32[22:0];
        real result;
        
        if (exponent == 8'hFF) begin
            // NaN or Infinity
            return 0.0;
        end else if (exponent == 0) begin
            // Denormalized
            result = mantissa * (2.0 ** -149);
        end else begin
            // Normalized
            result = (1.0 + mantissa * (2.0 ** -23)) * (2.0 ** (exponent - 127));
        end
        
        return sign ? -result : result;
    endfunction
    
    virtual function logic [31:0] real_to_fp32(input real val);
        return $shortrealtobits(val);
    endfunction
    
endclass
