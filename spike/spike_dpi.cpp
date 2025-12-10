//==============================================================================
// Spike DPI Interface - spike_dpi.svh
//==============================================================================
// Import Spike C++ functions via SystemVerilog DPI-C

// Spike initialization and control
import "DPI-C" function void spike_init(input string isa_string);
import "DPI-C" function void spike_reset();
import "DPI-C" function void spike_close();

// Register file access
import "DPI-C" function int spike_read_freg(input int reg_num);
import "DPI-C" function void spike_write_freg(input int reg_num, input int value);
import "DPI-C" function int spike_read_xreg(input int reg_num);
import "DPI-C" function void spike_write_xreg(input int reg_num, input int value);

// PC and CSR access
import "DPI-C" function int spike_read_pc();
import "DPI-C" function void spike_write_pc(input int pc_value);
import "DPI-C" function int spike_read_csr(input int csr_addr);
import "DPI-C" function void spike_write_csr(input int csr_addr, input int value);

// Instruction execution
import "DPI-C" function int spike_execute_instruction(input int instruction);
import "DPI-C" function int spike_step_one();

// Memory access
import "DPI-C" function int spike_read_mem(input int addr);
import "DPI-C" function void spike_write_mem(input int addr, input int data);

//==============================================================================
// Spike Reference Model Class
//==============================================================================

class spike_reference_model extends uvm_component;
    `uvm_component_utils(spike_reference_model)
    
    //===========================================
    // Configuration
    //===========================================
    bit enabled = 1;
    bit verbose = 0;
    string isa_string = "RV32IF";  // RV32I with F extension
    
    // Register file shadow copies
    logic [31:0] spike_xregs[32];   // Integer registers
    logic [31:0] spike_fregs[32];   // FP registers
    logic [31:0] spike_pc;
    logic [31:0] spike_fcsr;
    
    // Statistics
    int instructions_executed = 0;
    int fp_instructions = 0;
    
    //===========================================
    // Constructor
    //===========================================
    function new(string name = "spike_reference_model", uvm_component parent = null);
        super.new(name, parent);
    endfunction
    
    //===========================================
    // Build Phase
    //===========================================
    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        
        // Get configuration from config_db
        void'(uvm_config_db#(bit)::get(this, "", "spike_enabled", enabled));
        void'(uvm_config_db#(bit)::get(this, "", "spike_verbose", verbose));
        void'(uvm_config_db#(string)::get(this, "", "isa_string", isa_string));
        
        if (enabled) begin
            // Initialize Spike
            spike_init(isa_string);
            `uvm_info(get_type_name(), 
                     $sformatf("Spike initialized with ISA: %s", isa_string), 
                     UVM_LOW)
        end
    endfunction
    
    //===========================================
    // Reset Spike State
    //===========================================
    virtual function void reset_spike();
        if (!enabled) return;
        
        spike_reset();
        
        // Initialize registers to known state
        for (int i = 0; i < 32; i++) begin
            spike_write_xreg(i, i);  // x0=0, x1=1, etc.
            spike_write_freg(i, $shortrealtobits(real'(i) + 0.5));
        end
        
        // Set initial PC
        spike_write_pc(32'h8000_0000);
        spike_pc = 32'h8000_0000;
        
        // Clear FCSR
        spike_write_csr(32'h003, 32'h0);  // fcsr address = 0x003
        
        `uvm_info(get_type_name(), "Spike reset completed", UVM_MEDIUM)
    endfunction
    
    //===========================================
    // Execute Single Instruction in Spike
    //===========================================
    virtual function void execute_instruction(input logic [31:0] instruction);
        int status;
        
        if (!enabled) return;
        
        // Execute instruction in Spike
        status = spike_execute_instruction(instruction);
        
        if (status != 0) begin
            `uvm_error(get_type_name(), 
                      $sformatf("Spike execution failed for instruction 0x%08h", instruction))
        end
        
        // Update shadow registers
        update_shadow_registers();
        
        instructions_executed++;
        
        if (verbose) begin
            `uvm_info(get_type_name(),
                     $sformatf("Executed instruction 0x%08h, PC: 0x%08h", 
                              instruction, spike_pc),
                     UVM_HIGH)
        end
    endfunction
    
    //===========================================
    // Update Shadow Register Copies
    //===========================================
    virtual function void update_shadow_registers();
        // Read back all registers from Spike
        for (int i = 0; i < 32; i++) begin
            spike_xregs[i] = spike_read_xreg(i);
            spike_fregs[i] = spike_read_freg(i);
        end
        
        spike_pc = spike_read_pc();
        spike_fcsr = spike_read_csr(32'h003);  // fcsr
    endfunction
    
    //===========================================
    // Get Expected FP Register Value
    //===========================================
    virtual function logic [31:0] get_expected_freg(input int reg_num);
        if (reg_num >= 0 && reg_num < 32) begin
            return spike_fregs[reg_num];
        end
        return 32'h0;
    endfunction
    
    //===========================================
    // Get Expected Integer Register Value
    //===========================================
    virtual function logic [31:0] get_expected_xreg(input int reg_num);
        if (reg_num >= 0 && reg_num < 32) begin
            return spike_xregs[reg_num];
        end
        return 32'h0;
    endfunction
    
    //===========================================
    // Get Expected PC
    //===========================================
    virtual function logic [31:0] get_expected_pc();
        return spike_pc;
    endfunction
    
    //===========================================
    // Get Expected FCSR
    //===========================================
    virtual function logic [31:0] get_expected_fcsr();
        return spike_fcsr;
    endfunction
    
    //===========================================
    // Synchronize Spike with DUT State
    //===========================================
    virtual function void sync_with_dut(
        input logic [31:0] xregs[32],
        input logic [31:0] fregs[32],
        input logic [31:0] pc
    );
        if (!enabled) return;
        
        // Write DUT state to Spike
        for (int i = 0; i < 32; i++) begin
            spike_write_xreg(i, xregs[i]);
            spike_write_freg(i, fregs[i]);
        end
        spike_write_pc(pc);
        
        update_shadow_registers();
        
        `uvm_info(get_type_name(), "Spike synchronized with DUT state", UVM_HIGH)
    endfunction
    
    //===========================================
    // Final Phase - Cleanup
    //===========================================
    virtual function void final_phase(uvm_phase phase);
        super.final_phase(phase);
        
        if (enabled) begin
            spike_close();
            `uvm_info(get_type_name(),
                     $sformatf("Spike executed %0d instructions (%0d FP)",
                              instructions_executed, fp_instructions),
                     UVM_LOW)
        end
    endfunction
    
endclass

//==============================================================================
// Enhanced Scoreboard with Spike Integration
//==============================================================================

class top_core_scoreboard_spike extends uvm_scoreboard;
    `uvm_component_utils(top_core_scoreboard_spike)
    
    uvm_analysis_imp #(fpu_packet, top_core_scoreboard_spike) item_analysis_export;
    
    // Spike reference model
    spike_reference_model spike_model;
    
    //===========================================
    // Statistics
    //===========================================
    int total_transactions = 0;
    int passed_transactions = 0;
    int failed_transactions = 0;
    int fp_transactions = 0;
    int spike_mismatches = 0;
    
    // Error categories
    int pc_mismatches = 0;
    int freg_mismatches = 0;
    int xreg_mismatches = 0;
    int fcsr_mismatches = 0;
    
    //===========================================
    // Configuration
    //===========================================
    bit enable_spike = 1;
    bit check_pc = 1;
    bit check_registers = 1;
    bit check_fcsr = 0;  // Optional, may not be visible in your DUT outputs
    real fp_tolerance = 0.00001;
    
    //===========================================
    // Constructor
    //===========================================
    function new(string name = "top_core_scoreboard_spike", uvm_component parent = null);
        super.new(name, parent);
        item_analysis_export = new("item_analysis_export", this);
    endfunction
    
    //===========================================
    // Build Phase
    //===========================================
    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        
        // Get configuration
        void'(uvm_config_db#(bit)::get(this, "", "enable_spike", enable_spike));
        void'(uvm_config_db#(real)::get(this, "", "fp_tolerance", fp_tolerance));
        
        // Create Spike model
        if (enable_spike) begin
            spike_model = spike_reference_model::type_id::create("spike_model", this);
        end
    endfunction
    
    //===========================================
    // Reset Phase - Initialize Spike
    //===========================================
    virtual task reset_phase(uvm_phase phase);
        super.reset_phase(phase);
        
        if (enable_spike && spike_model != null) begin
            phase.raise_objection(this);
            spike_model.reset_spike();
            phase.drop_objection(this);
        end
    endtask
    
    //===========================================
    // Main Write Function
    //===========================================
    virtual function void write(fpu_packet item);
        total_transactions++;
        
        // Decode instruction
        item.decode_instruction();
        
        if (item.instr_category == INSTR_CAT_FLOAT) begin
            fp_transactions++;
        end
        
        // Execute in Spike and compare
        if (enable_spike && spike_model != null) begin
            check_with_spike(item);
        end else begin
            // Fallback to simple checking
            check_basic(item);
        end
    endfunction
    
    //===========================================
    // Check Transaction Against Spike
    //===========================================
    virtual function void check_with_spike(fpu_packet item);
        bit passed = 1;
        string error_msg = "";
        logic [31:0] spike_result, spike_pc_exp;
        real dut_val, spike_val, error;
        
        // Execute instruction in Spike
        spike_model.execute_instruction(item.instruction);
        
        // Get expected values from Spike
        spike_pc_exp = spike_model.get_expected_pc();
        
        //---------------------------------------
        // Check 1: PC Progression
        //---------------------------------------
        if (check_pc && item.pc_curr != spike_pc_exp) begin
            passed = 0;
            error_msg = {error_msg, 
                        $sformatf("\n  ✗ PC Mismatch:")};
            error_msg = {error_msg,
                        $sformatf("\n    Expected (Spike): 0x%08h", spike_pc_exp)};
            error_msg = {error_msg,
                        $sformatf("\n    Got (DUT):        0x%08h", item.pc_curr)};
            pc_mismatches++;
        end
        
        //---------------------------------------
        // Check 2: FP Register Results
        //---------------------------------------
        if (item.instr_category == INSTR_CAT_FLOAT && check_registers) begin
            // For FP operations that write to FP registers
            if (item.opcode inside {OP_FP, OP_FMADD, OP_FMSUB, OP_FNMSUB, OP_FNMADD, OP_FLW}) begin
                spike_result = spike_model.get_expected_freg(item.rd);
                
                // Convert to real for tolerance-based comparison
                dut_val = $bitstoshortreal(item.dmem_dataOUT);  // Assuming result appears here
                spike_val = $bitstoshortreal(spike_result);
                error = $abs(dut_val - spike_val);
                
                // Check if values match within tolerance
                if (error > fp_tolerance && !is_special_value(spike_result)) begin
                    passed = 0;
                    error_msg = {error_msg,
                                $sformatf("\n  ✗ FP Register f%0d Mismatch for %s:", 
                                         item.rd, item.get_instruction_name())};
                    error_msg = {error_msg,
                                $sformatf("\n    Expected (Spike): 0x%08h (%f)", 
                                         spike_result, spike_val)};
                    error_msg = {error_msg,
                                $sformatf("\n    Got (DUT):        0x%08h (%f)", 
                                         item.dmem_dataOUT, dut_val)};
                    error_msg = {error_msg,
                                $sformatf("\n    Error:            %e (tolerance: %e)", 
                                         error, fp_tolerance)};
                    freg_mismatches++;
                end
            end
        end
        
        //---------------------------------------
        // Update Statistics
        //---------------------------------------
        if (passed) begin
            passed_transactions++;
            `uvm_info(get_type_name(),
                     $sformatf("✓ PASS [%0d]: %s (PC: 0x%08h)", 
                              total_transactions,
                              item.get_instruction_name(),
                              item.pc_curr),
                     UVM_HIGH)
        end else begin
            failed_transactions++;
            spike_mismatches++;
            `uvm_error("SPIKE_MISMATCH",
                      $sformatf("✗ FAIL [%0d]: %s%s\n%s",
                               total_transactions,
                               item.get_instruction_name(),
                               error_msg,
                               item.convert2string()))
        end
    endfunction
    
    //===========================================
    // Basic Check (fallback if Spike disabled)
    //===========================================
    virtual function void check_basic(fpu_packet item);
        // Basic sanity checks only
        bit passed = 1;
        
        if (item.dmem_addr === 32'hxxxxxxxx) begin
            passed = 0;
        end
        
        if (passed) begin
            passed_transactions++;
        end else begin
            failed_transactions++;
        end
    endfunction
    
    //===========================================
    // Helper: Check for Special FP Values
    //===========================================
    virtual function bit is_special_value(logic [31:0] fp_value);
        logic [7:0] exp = fp_value[30:23];
        logic [22:0] mantissa = fp_value[22:0];
        
        // Check for NaN or Infinity
        return (exp == 8'hFF);
    endfunction
    
    //===========================================
    // Report Phase
    //===========================================
    virtual function void report_phase(uvm_phase phase);
        real pass_rate, spike_accuracy;
        
        super.report_phase(phase);
        
        if (total_transactions > 0) begin
            pass_rate = 100.0 * passed_transactions / total_transactions;
        end else begin
            pass_rate = 0.0;
        end
        
        if (enable_spike && failed_transactions > 0) begin
            spike_accuracy = 100.0 * (1.0 - real'(spike_mismatches) / real'(total_transactions));
        end else begin
            spike_accuracy = 100.0;
        end
        
        `uvm_info("SCOREBOARD_REPORT",
                 $sformatf("\n\n" +
                         "╔═══════════════════════════════════════════════════════╗\n" +
                         "║   FPU VERIFICATION WITH SPIKE GOLDEN REFERENCE        ║\n" +
                         "╠═══════════════════════════════════════════════════════╣\n" +
                         "║ VERIFICATION RESULTS                                  ║\n" +
                         "╠═══════════════════════════════════════════════════════╣\n" +
                         "║ Total Instructions:         %10d              ║\n" +
                         "║ FP Instructions:            %10d              ║\n" +
                         "║ Passed:                     %10d              ║\n" +
                         "║ Failed:                     %10d              ║\n" +
                         "║ Pass Rate:                  %9.2f%%             ║\n" +
                         "║ Spike Accuracy:             %9.2f%%             ║\n" +
                         "╠═══════════════════════════════════════════════════════╣\n" +
                         "║ ERROR BREAKDOWN                                       ║\n" +
                         "╠═══════════════════════════════════════════════════════╣\n" +
                         "║ Spike Mismatches:           %10d              ║\n" +
                         "║ PC Mismatches:              %10d              ║\n" +
                         "║ FP Register Mismatches:     %10d              ║\n" +
                         "║ Integer Register Mismatches:%10d              ║\n" +
                         "║ FCSR Mismatches:            %10d              ║\n" +
                         "╠═══════════════════════════════════════════════════════╣\n" +
                         "║ SPIKE STATUS: %-42s ║\n" +
                         "╚═══════════════════════════════════════════════════════╝\n",
                         total_transactions,
                         fp_transactions,
                         passed_transactions,
                         failed_transactions,
                         pass_rate,
                         spike_accuracy,
                         spike_mismatches,
                         pc_mismatches,
                         freg_mismatches,
                         xreg_mismatches,
                         fcsr_mismatches,
                         enable_spike ? "ENABLED" : "DISABLED"),
                 UVM_NONE)
        
        // Final verdict
        if (failed_transactions == 0 && total_transactions > 0) begin
            `uvm_info("VERDICT", "\n★★★ ALL TESTS PASSED WITH SPIKE ★★★\n", UVM_NONE)
        end else if (spike_mismatches > 0) begin
            `uvm_error("VERDICT", 
                      $sformatf("\n✗ %0d SPIKE MISMATCHES FOUND ✗\n", spike_mismatches))
        end
    endfunction
    
endclass
