class top_core_agent extends uvm_agent;
    `uvm_component_utils(top_core_agent)
    
    top_core_driver driver;
    top_core_monitor monitor;
    uvm_sequencer #(fpu_packet) sequencer;
    
    function new(string name = "top_core_agent", uvm_component parent = null);
        super.new(name, parent);
    endfunction
    
    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        
        monitor = top_core_monitor::type_id::create("monitor", this);
        
        if (get_is_active() == UVM_ACTIVE) begin
            driver = top_core_driver::type_id::create("driver", this);
            sequencer = uvm_sequencer#(fpu_packet)::type_id::create("sequencer", this);
        end
    endfunction
    
    virtual function void connect_phase(uvm_phase phase);
        super.connect_phase(phase);
        
        if (get_is_active() == UVM_ACTIVE) begin
            driver.seq_item_port.connect(sequencer.seq_item_export);
        end
    endfunction
    
endclass
