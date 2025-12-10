class top_core_monitor extends uvm_monitor;
    `uvm_component_utils(top_core_monitor)
    
    virtual top_core_if vif;
    uvm_analysis_port #(fpu_packet) item_collected_port;
    
    // Track register file state
    logic [31:0] fp_reg_file[32];
    logic [31:0] int_reg_file[32];
    logic [31:0] last_pc;
    
    function new(string name = "top_core_monitor", uvm_component parent = null);
        super.new(name, parent);
        item_collected_port = new("item_collected_port", this);
    endfunction
    
    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        if (!uvm_config_db#(virtual top_core_if)::get(this, "", "vif", vif)) begin
            `uvm_fatal("NOVIF", "virtual interface must be set for top_core_monitor")
        end
        
        // Initialize register files
        for (int i = 0; i < 32; i++) begin
            fp_reg_file[i] = $shortrealtobits(real'(i) + 0.5);
            int_reg_file[i] = i;
        end
        last_pc = 32'h8000_0000;
    endfunction
    
    virtual task run_phase(uvm_phase phase);
        fpu_packet monitored_item;
        
        // Wait for reset to be released
        wait(vif.monitor_cb.rst == 1'b0);
        
        forever begin
            monitored_item = fpu_packet::type_id::create("monitored_item");
            collect_transaction(monitored_item);
            
            // Update register file tracking
            update_register_file(monitored_item);
            
            // Send to scoreboard
            item_collected_port.write(monitored_item);
        end
    endtask
    
    virtual task collect_transaction(fpu_packet item);
        // Wait for clock edge
        @(vif.monitor_cb);
        
        // Capture all signals
        item.instruction = vif.monitor_cb.instruction;
        item.dmem_dataIN = vif.monitor_cb.dmem_dataIN;
        item.dmem_addr = vif.monitor_cb.dmem_addr;
        item.pc_curr = vif.monitor_cb.pc_curr;
        item.func3_MEM = vif.monitor_cb.func3_MEM;
        item.memW_en_MEM = vif.monitor_cb.memW_en_MEM;
        item.dmem_dataOUT = vif.monitor_cb.dmem_dataOUT;
        
        // Decode instruction
        item.decode_instruction();
        
        // Get operands from tracked register file
        if (item.instr_category == INSTR_CAT_FLOAT) begin
            item.fp_operand1 = fp_reg_file[item.rs1];
            item.fp_operand2 = fp_reg_file[item.rs2];
            item.fp_operand3 = fp_reg_file[item.rs3];
            item.fp_reg_dest = item.rd;
        end
        
        `uvm_info(get_type_name(), 
                 $sformatf("Monitored: %s at PC=0x%08h", 
                          item.get_instruction_name(), item.pc_curr), 
                 UVM_HIGH)
    endtask
    
    virtual function void update_register_file(fpu_packet item);
        // Update FP register file based on instruction type
        if (item.instr_category == INSTR_CAT_FLOAT) begin
            case (item.opcode)
                OP_FP, OP_FMADD, OP_FMSUB, OP_FNMSUB, OP_FNMADD: begin
                    // For FP operations, assume result appears in dmem_dataOUT
                    // This is DUT-specific - adjust based on your design
                    if (item.rd != 0) begin
                        fp_reg_file[item.rd] = item.dmem_dataOUT;
                        `uvm_info(get_type_name(),
                                 $sformatf("Updated f%0d = 0x%08h", item.rd, item.dmem_dataOUT),
                                 UVM_DEBUG)
                    end
                end
                
                OP_FLW: begin
                    // FP Load
                    if (item.rd != 0) begin
                        fp_reg_file[item.rd] = item.dmem_dataIN;
                    end
                end
            endcase
        end
        
        // Update PC tracking
        last_pc = item.pc_curr;
    endfunction
    
endclass
