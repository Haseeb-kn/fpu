import uvm_pkg::*;
`include "uvm_macros.svh"
import fpu_pkg::*;
class top_core_base_test extends uvm_test;
    `uvm_component_utils(top_core_base_test)
    
    top_core_env env;
    virtual top_core_if vif;
    
    // Test configuration
    int num_transactions = 100;
    
    function new(string name = "top_core_base_test", uvm_component parent = null);
        super.new(name, parent);
    endfunction
    
    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        
        // Create environment
        env = top_core_env::type_id::create("env", this);
        
        // Get virtual interface
        if (!uvm_config_db#(virtual top_core_if)::get(this, "", "vif", vif)) begin
            `uvm_fatal("NOVIF", "virtual interface must be set")
        end
        
        // Configure test parameters
        uvm_config_db#(int)::set(this, "env.agent.sequencer.*", "num_transactions", num_transactions);
    endfunction
    
    virtual task run_phase(uvm_phase phase);
        top_core_base_seq base_seq;
        
        phase.raise_objection(this);
        
        `uvm_info(get_type_name(), "Starting base test", UVM_LOW)
        
        // Create and start sequence
        base_seq = top_core_base_seq::type_id::create("base_seq");
        base_seq.num_transactions = num_transactions;
        base_seq.start(env.agent.sequencer);
        
        // Wait for completion
        #1000;
        
        `uvm_info(get_type_name(), "Base test completed", UVM_LOW)
        phase.drop_objection(this);
    endtask
    
endclass



class top_core_load_test extends top_core_base_test;
    `uvm_component_utils(top_core_load_test)
    
    function new(string name = "top_core_load_test", uvm_component parent = null);
        super.new(name, parent);
        num_transactions = 50;
    endfunction
    
    virtual task run_phase(uvm_phase phase);
        top_core_load_seq load_seq;
        
        phase.raise_objection(this);
        
        `uvm_info(get_type_name(), "Starting load test", UVM_LOW)
        
        // Create and start load sequence
        load_seq = top_core_load_seq::type_id::create("load_seq");
        load_seq.num_loads = num_transactions;
        load_seq.start(env.agent.sequencer);
        
        // Wait for completion
        #1000;
        
        `uvm_info(get_type_name(), "Load test completed", UVM_LOW)
        phase.drop_objection(this);
    endtask
    
endclass


class top_core_store_test extends top_core_base_test;
    `uvm_component_utils(top_core_store_test)
    
    function new(string name = "top_core_store_test", uvm_component parent = null);
        super.new(name, parent);
        num_transactions = 50;
    endfunction
    
    virtual task run_phase(uvm_phase phase);
        top_core_store_seq store_seq;
        
        phase.raise_objection(this);
        
        `uvm_info(get_type_name(), "Starting store test", UVM_LOW)
        
        // Create and start store sequence
        store_seq = top_core_store_seq::type_id::create("store_seq");
        store_seq.num_stores = num_transactions;
        store_seq.start(env.agent.sequencer);
        
        // Wait for completion
        #1000;
        
        `uvm_info(get_type_name(), "Store test completed", UVM_LOW)
        phase.drop_objection(this);
    endtask
    
endclass



class riscv_f_extension_test extends top_core_base_test;
    `uvm_component_utils(riscv_f_extension_test)
    
    function new(string name = "riscv_f_extension_test", uvm_component parent = null);
        super.new(name, parent);
        num_transactions = 200;
    endfunction
    
    virtual task run_phase(uvm_phase phase);
        riscv_f_extension_seq f_seq;
        
        phase.raise_objection(this);
        
        `uvm_info(get_type_name(), "Starting F-extension comprehensive test", UVM_LOW)
        
        // Create and start F-extension sequence
        f_seq = riscv_f_extension_seq::type_id::create("f_seq");
        f_seq.num_fp_tests = num_transactions;
        f_seq.start(env.agent.sequencer);
        
        // Wait for completion
        #2000;
        
        `uvm_info(get_type_name(), "F-extension test completed", UVM_LOW)
        phase.drop_objection(this);
    endtask
    
endclass

