

class top_core_monitor extends uvm_monitor;
    `uvm_component_utils(top_core_monitor)
    
    virtual top_core_if vif;
    uvm_analysis_port #(top_core_seq_item) item_collected_port;
    
    // Coverage (connected in env)
    uvm_analysis_imp #(top_core_seq_item, top_core_monitor) cov_export;
    
    function new(string name = "top_core_monitor", uvm_component parent = null);
        super.new(name, parent);
        item_collected_port = new("item_collected_port", this);
        cov_export = new("cov_export", this);
    endfunction
    
    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        if (!uvm_config_db#(virtual top_core_if)::get(this, "", "vif", vif)) begin
            `uvm_fatal("NOVIF", "virtual interface must be set for top_core_monitor")
        end
    endfunction
    
    virtual task run_phase(uvm_phase phase);
        top_core_seq_item monitored_item;
        
        // Wait for reset to be released
        wait(vif.monitor_cb.rst == 1'b0);
        
        forever begin
            monitored_item = top_core_seq_item::type_id::create("monitored_item");
            collect_transaction(monitored_item);
            item_collected_port.write(monitored_item);
            cov_export.write(monitored_item);  // Send to coverage
        end
    endtask
    
    virtual task collect_transaction(top_core_seq_item item);
        // Wait for valid transaction (simplified - always sample)
        @(vif.monitor_cb);
        
        // Capture all signals
        item.instruction = vif.monitor_cb.instruction;
        item.dmem_dataIN = vif.monitor_cb.dmem_dataIN;
        item.dmem_addr = vif.monitor_cb.dmem_addr;
        item.pc_curr = vif.monitor_cb.pc_curr;
        item.func3_MEM = vif.monitor_cb.func3_MEM;
        item.memW_en_MEM = vif.monitor_cb.memW_en_MEM;
        item.dmem_dataOUT = vif.monitor_cb.dmem_dataOUT;
        
        // Decode instruction for analysis
        item.decode_instruction();
        
        `uvm_info(get_type_name(), $sformatf("Monitored transaction:\n%s", item.convert2string()), UVM_HIGH)
    endtask
    
    // Write function for coverage
    virtual function void write(top_core_seq_item item);
        // This is called by the coverage component
        // Coverage collection happens in the coverage component
    endfunction
    
endclass

