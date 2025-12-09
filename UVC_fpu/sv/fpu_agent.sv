

class top_core_agent extends uvm_agent;
    `uvm_component_utils(top_core_agent)
    
    top_core_driver driver;
    top_core_monitor monitor;
    uvm_sequencer #(top_core_seq_item) sequencer;
    
    uvm_analysis_port #(top_core_seq_item) monitor_ap;
    
    function new(string name = "top_core_agent", uvm_component parent = null);
        super.new(name, parent);
        monitor_ap = new("monitor_ap", this);
    endfunction
    
    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        
        monitor = top_core_monitor::type_id::create("monitor", this);
        
        if (get_is_active() == UVM_ACTIVE) begin
            driver = top_core_driver::type_id::create("driver", this);
            sequencer = uvm_sequencer#(top_core_seq_item)::type_id::create("sequencer", this);
        end
    endfunction
    
    virtual function void connect_phase(uvm_phase phase);
        super.connect_phase(phase);
        
        // Connect monitor analysis port to agent analysis port
        monitor.item_collected_port.connect(monitor_ap);
        
        if (get_is_active() == UVM_ACTIVE) begin
            driver.seq_item_port.connect(sequencer.seq_item_export);
        end
    endfunction
    
endclass

