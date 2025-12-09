package fpu_pkg;
    import uvm_pkg::*;
    `include "uvm_macros.svh"
    
    // Include all type definitions
    `include "type_enum.sv"
    
    // Include all UVM components
    `include "fpu_packet.sv"
    `include "fpu_seqs.sv"
    `include "fpu_driver.sv"
    `include "fpu_moniter.sv"
    `include "fpu_agent.sv"
    `include "fpu_scoreboard.sv"
    `include "fpu_coverage.sv"
    `include "fpu_env.sv"
    
endpackage
