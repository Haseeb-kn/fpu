`timescale 1ns/1ps

`include "uvm_macros.svh"
`include "fpu_test.sv"
module top_tb;
    
    import uvm_pkg::*;
    import riscv_instruction_pkg::*;
    import fpu_pkg::*;
    // Clock and reset
    logic clk;
    logic rst;
    
    // Clock generation
    initial begin
        clk = 0;
        forever #5 clk = ~clk;
    end
    
    // Interface instantiation
    top_core_if vif(clk);
    
    // DUT instantiation
    top_core dut (
        .clk(vif.clk),
        .rst(vif.rst),
        .dmem_dataIN(vif.dmem_dataIN),
        .instruction(vif.instruction),
        .dmem_addr(vif.dmem_addr),
        .pc_curr(vif.pc_curr),
        .func3_MEM(vif.func3_MEM),
        .memW_en_MEM(vif.memW_en_MEM),
        .dmem_dataOUT(vif.dmem_dataOUT)
    );
    
    // Initial block for UVM
    initial begin
        // Set virtual interface in config db
        uvm_config_db#(virtual top_core_if)::set(null, "*", "vif", vif);
        
        // Run test
        run_test();
    end
    
  
    // Simulation timeout
    initial begin
        #1000000;
        $display("Simulation timeout!");
        $finish;
    end
    
endmodule
