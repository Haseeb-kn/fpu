

interface top_core_if(input logic clk);
    logic rst;
    logic [31:0] dmem_dataIN;
    logic [31:0] instruction;
    logic [31:0] dmem_addr;
    logic [31:0] pc_curr;
    logic [2:0]  func3_MEM;
    logic        memW_en_MEM;
    logic [31:0] dmem_dataOUT;
    
    // Clocking blocks for driver and monitor
    clocking driver_cb @(posedge clk);
        default input #1ns output #1ns;
        output rst;
        output dmem_dataIN;
        output instruction;
        input dmem_addr;
        input pc_curr;
        input func3_MEM;
        input memW_en_MEM;
        input dmem_dataOUT;
    endclocking
    
    clocking monitor_cb @(posedge clk);
        default input #1ns;
        input rst;
        input dmem_dataIN;
        input instruction;
        input dmem_addr;
        input pc_curr;
        input func3_MEM;
        input memW_en_MEM;
        input dmem_dataOUT;
    endclocking
    
    // Modports
    modport driver_mp(
        clocking driver_cb
    );
    
    modport monitor_mp(
        clocking monitor_cb
    );
    
    modport dut_mp(
        input clk,
        input rst,
        input dmem_dataIN,
        input instruction,
        output dmem_addr,
        output pc_curr,
        output func3_MEM,
        output memW_en_MEM,
        output dmem_dataOUT
    );
    
endinterface

