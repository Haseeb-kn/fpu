class top_core_env extends uvm_env;
    `uvm_component_utils(top_core_env)
    
    top_core_agent agent;
    top_core_scoreboard_simple scoreboard;  // Use simple scoreboard
    top_core_coverage coverage;
    
    function new(string name = "top_core_env", uvm_component parent = null);
        super.new(name, parent);
    endfunction
    
    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        
        agent = top_core_agent::type_id::create("agent", this);
        scoreboard = top_core_scoreboard_simple::type_id::create("scoreboard", this);
        coverage = top_core_coverage::type_id::create("coverage", this);
        
        // Configure
        uvm_config_db#(uvm_active_passive_enum)::set(this, "agent", "is_active", UVM_ACTIVE);
        
        // Set scoreboard tolerance (relaxed for initial testing)
        uvm_config_db#(real)::set(this, "scoreboard", "fp_tolerance", 0.001);
        uvm_config_db#(bit)::set(this, "scoreboard", "check_exact", 0);
    endfunction
    
    virtual function void connect_phase(uvm_phase phase);
        super.connect_phase(phase);
        
        agent.monitor.item_collected_port.connect(scoreboard.item_analysis_export);
        agent.monitor.item_collected_port.connect(coverage.analysis_export);
    endfunction
    
    virtual function void report_phase(uvm_phase phase);
        super.report_phase(phase);
        coverage.report_phase(phase);
    endfunction
    
endclass
