


class top_core_driver extends uvm_driver #(top_core_seq_item);
    `uvm_component_utils(top_core_driver)
    
    virtual top_core_if vif;
    
    function new(string name = "top_core_driver", uvm_component parent = null);
        super.new(name, parent);
    endfunction
    
    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        if (!uvm_config_db#(virtual top_core_if)::get(this, "", "vif", vif)) begin
            `uvm_fatal("NOVIF", "virtual interface must be set for top_core_driver")
        end
    endfunction
    
    virtual task run_phase(uvm_phase phase);
        // Apply initial reset
        apply_reset();
        
        // Main driver loop
        forever begin
            seq_item_port.get_next_item(req);
            drive_transaction(req);
            seq_item_port.item_done();
        end
    endtask
    
    virtual task apply_reset();
        `uvm_info(get_type_name(), "Applying reset", UVM_LOW)
        vif.driver_cb.rst <= 1'b1;
        vif.driver_cb.instruction <= '0;
        vif.driver_cb.dmem_dataIN <= '0;
        repeat(5) @(vif.driver_cb);
        vif.driver_cb.rst <= 1'b0;
        @(vif.driver_cb);
        `uvm_info(get_type_name(), "Reset released", UVM_LOW)
    endtask
    
    virtual task drive_transaction(top_core_seq_item item);
        `uvm_info(get_type_name(), $sformatf("Driving transaction:\n%s", item.convert2string()), UVM_HIGH)
        
        // Drive inputs
        vif.driver_cb.instruction <= item.instruction;
        vif.driver_cb.dmem_dataIN <= item.dmem_dataIN;
        
        // Wait for transaction latency
        repeat(item.latency) @(vif.driver_cb);
        
        // Sample outputs (optional - monitor will handle this)
        // item.dmem_addr = vif.driver_cb.dmem_addr;
        // item.pc_curr = vif.driver_cb.pc_curr;
        // item.func3_MEM = vif.driver_cb.func3_MEM;
        // item.memW_en_MEM = vif.driver_cb.memW_en_MEM;
        // item.dmem_dataOUT = vif.driver_cb.dmem_dataOUT;
        
        `uvm_info(get_type_name(), "Transaction driven", UVM_MEDIUM)
    endtask
    
endclass

