


class top_core_env extends uvm_env;
    `uvm_component_utils(top_core_env)
    
    top_core_agent agent;
    top_core_scoreboard scoreboard;
    top_core_coverage coverage;
    
    function new(string name = "top_core_env", uvm_component parent = null);
        super.new(name, parent);
    endfunction
    
    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        
        // Create components using factory
        agent = top_core_agent::type_id::create("agent", this);
        scoreboard = top_core_scoreboard::type_id::create("scoreboard", this);
        coverage = top_core_coverage::type_id::create("coverage", this);
        
        // Set agent to active mode
        uvm_config_db#(uvm_active_passive_enum)::set(this, "agent", "is_active", UVM_ACTIVE);
    endfunction
    
    virtual function void connect_phase(uvm_phase phase);
        super.connect_phase(phase);
        
        // Connect monitor analysis port to scoreboard and coverage
        agent.monitor_ap.connect(scoreboard.item_analysis_export);
        agent.monitor.cov_export.connect(coverage.analysis_export);
    endfunction
    
    virtual function void report_phase(uvm_phase phase);
        super.report_phase(phase);
        
        // Report coverage and scoreboard results
        coverage.report();
        scoreboard.report();
    endfunction
    
endclass

