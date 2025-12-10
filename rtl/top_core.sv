`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 04/22/2025 12:02:03 PM
// Design Name: 
// Module Name: top
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////

`include "alu_logic.sv"
`include "branch_comp.sv"

// Control and CSR modules
`include "control.sv"
`include "csr_compute.sv"
`include "cs_reg.sv"

// Arithmetic modules
`include "divider64.sv"
`include "divider.sv"
`include "mul_2cycle.sv"
`include "sqrt.sv"

// Floating-point unit modules
`include "fpu_add_sub.sv"
`include "fpu_mul.sv"
`include "fpu_div.sv"
`include "fpu_fma.sv"
`include "fpu_fsgnj.sv"
`include "fpu_fminmax.sv"
`include "fpu_mul_div.sv"
`include "fpu_alu.sv"

// Floating-point conversion modules
`include "fclass.sv"
`include "fixedp2floatp.sv"
`include "fixedp2floatp_q32.sv"
`include "float_to_fixed.sv"
`include "floating_sqrt.sv"

// Pipeline registers
`include "IF_ID.sv"
`include "ID_EX.sv"
`include "EX_MEM.sv"
`include "MEM_WB.sv"

// Other core modules
`include "hazard_detection_unit.sv"
`include "imm_gen.sv"
`include "program_counter.sv"
`include "reg_file.sv"
module top_core (
    input logic clk, rst,
    
    input logic [31:0] dmem_dataIN,    
    input logic [31:0] instruction,
    
    output logic [31:0] dmem_addr,
    output logic [31:0] pc_curr,
    
    output logic [2:0] func3_MEM,
    output logic memW_en_MEM,
    output logic [31:0] dmem_dataOUT
    );


    logic [31:0] data1_out;
    logic [31:0] data2_out;
    logic [31:0] data3_out;
    logic [31:0] imm_ex_out;
    logic [31:0] d_mem_out;
    logic [31:0] ALUd1_in;
    logic [31:0] ALUd2_in;
    logic [31:0] regD_in;
    logic [31:0] csr_data_out;
    logic [31:0] csr_data_in_new;
    logic [31:0] csr_data_r;
    logic [31:0] csr_data_r_fwd;
    logic [31:0] ALUout;
 

    // pc depends on imem depth
    //logic [31:0] pc_curr;
    logic [31:0] pc_curr_p4;
    logic [31:0] pc_next; // for tracer

    // control signals
    logic [11:0] csr_address;
    logic [4:0] ALUsel;
    logic [1:0] WBsel;
    logic regW_en, Bsel, memW_en, load_pc, Asel, jump, valid_branch;
    // for csr
    logic csrW_en;
    logic [4:0] f_flags;
    logic [2:0] f_rm; // rounding mode
    logic float_inst;
    logic csrWBsel;
    logic rs1_float, rs2_float, rsW_float; // used for fpu

    // ID signals
    logic [31:0] pc_curr_ID;
    logic [31:0] inst_ID;

    // EX signals
    logic [31:0] pc_curr_EX;
    logic [31:0] rs1_EX;
    logic [31:0] rs2_EX;
    logic [31:0] rs3_EX;
    logic [31:0] imm_ex_out_EX;
    logic [31:0] inst_EX;
    logic [31:0] csr_data_r_EX;
        //
    logic rs1_float_EX, rs2_float_EX, rsW_float_EX; // used for fpu
    logic [11:0] csr_address_EX;
    logic [4:0] ALUsel_EX;
    logic [1:0] WBsel_EX;
    logic float_inst_EX;
    logic csrWBsel_EX, regW_en_EX, Bsel_EX, memW_en_EX, jump_EX, Asel_EX, csrW_en_EX;

    // MEM signals
    logic [31:0] pc_curr_MEM;
    logic [31:0] pc_next_MEM; // output of adder in MEM stage !
    logic [31:0] ALUout_MEM;
    logic [31:0] csr_data_r_MEM;
    logic [31:0] csr_data_out_MEM;
    logic [31:0] rs2_MEM;
    logic [31:0] inst_MEM;
        //
    logic rsW_float_MEM; // used for fpu
    logic [11:0] csr_address_MEM;
    logic [1:0] WBsel_MEM;
    logic float_inst_MEM;
    logic csrWBsel_MEM, regW_en_MEM, jump_MEM, csrW_en_MEM, valid_branch_MEM; // memW_en_MEM,

    // WB signals
    logic [31:0] pc_next_WB;
    logic [31:0] ALUout_WB;
    logic [31:0] csr_data_r_WB;
    logic [31:0] csr_data_out_WB;
    logic [31:0] d_mem_out_WB;
    logic [31:0] inst_WB;
    //
    logic rsW_float_WB; // used for fpu
    logic [11:0] csr_address_WB;
    logic [1:0] WBsel_WB;
    logic float_inst_WB;
    logic csrW_en_WB;
    logic regW_en_WB;
    logic csrWBsel_WB;

    // for HCU
    logic [31:0] data1_EX;
    logic [31:0] data2_EX;
    logic [31:0] data3_EX;
    // HCU control
    logic [1:0] fwd_csr;
    logic [1:0] fwd_A;
    logic [1:0] fwd_B;
    logic [1:0] fwd_C;
    logic pc_en;
    logic IF_ID_en;
    logic ID_EX_en;
    logic EX_MEM_en;
    logic MEM_WB_en;
    // logic EX_MEM_en;
    logic IF_ID_flush;
    logic ID_EX_flush;
    logic EX_MEM_flush;
    logic done;


    // pc loading done here
    assign load_pc = jump_MEM || valid_branch_MEM; //// <<<------ jump from WB and branch from MEM

    assign pc_next = load_pc ? ALUout_MEM[31:0] : pc_curr_p4;

    program_counter PC (.clk(clk), .rst(rst), .en(pc_en), .pc_next(pc_curr_p4),
        .load_en(load_pc), .load_val(ALUout_MEM[31:0]), // <<<----- ALUout from MEM stage
        .pc_curr(pc_curr));

    //inst_mem IMEM (.addr(pc_curr[15:0]), .data(instruction));
    // enternal IMEM module -----
    // pc_curr <- output
    // instruction <- input
    // --------------------------
    
    // ------------------------------------ IF/ID --------------------------------- //
    IF_ID IF_ID (.clk(clk), .rst(rst), .en(IF_ID_en), .flush(IF_ID_flush),

        .pc_curr_IF(pc_curr),
        .inst_IF(instruction),

        .pc_curr_ID(pc_curr_ID),
        .inst_ID(inst_ID)
    );
    // ----
    
    // control signals generated here
    control CU(.instruction(inst_ID),
        .csr_address,
        .ALUsel,
        .WBsel,
        .imALU0_FPU1(float_inst), .rs2_float, .rs1_float, .rsW_float,
        .csrWBsel, .regW_en, .Bsel, .memW_en, .jump, .Asel, .csrW_en
    );

    cs_reg CSR(
        .clk,
        .rst, // active low
        .csrW_en(csrW_en_WB), .csr_address_w(csr_address_WB), .csr_data_w(csr_data_out_WB), // <<<--------- will update csr (from WB stage)
        
        .csr_address_r(csr_address), .csr_data_r
    );
    
    reg_file RF(.clk(clk), .rst(rst),
        .dataW(regD_in), // <<<--- this is coming from WB stage
        .rs1({rs1_float, inst_ID[19:15]}), .rs2({rs2_float, inst_ID[24:20]}), .rs3({1'b1, inst_ID[31:27]}), // <<<--- rs3 is used for fpu
        .rsW({rsW_float_WB, inst_WB[11:7]}), .regW_en(regW_en_WB),  // <<<--------- for write back rsW (from WB stage)
        
        .data1(data1_out), .data2(data2_out), .data3(data3_out) // <<<--- data3 is used for fpu
        );

    imm_gen IG(.inst(inst_ID), .imm_ex(imm_ex_out));

    // ------------------------------------ ID/EX --------------------------------- //
    ID_EX ID_EX (.clk(clk), .rst(rst), .en(ID_EX_en), .flush(ID_EX_flush),

        // inputs
            // data signals
        .pc_curr_ID,
        .rs1_ID(data1_out),
        .rs2_ID(data2_out),
        .rs3_ID(data3_out),
        .imm_ex_out_ID(imm_ex_out),
        .inst_ID,
        .csr_data_r_ID(csr_data_r),
            // control signals
        .rs2_float_ID(rs2_float), .rs1_float_ID(rs1_float), .rsW_float_ID(rsW_float), // float
        .csr_address_ID(csr_address),
        .ALUsel_ID(ALUsel),
        .WBsel_ID(WBsel),
        .float_inst_ID(float_inst),
        .csrWBsel_ID(csrWBsel), .regW_en_ID(regW_en), .Bsel_ID(Bsel), .memW_en_ID(memW_en), .jump_ID(jump), .Asel_ID(Asel), .csrW_en_ID(csrW_en),

        // outputs
            // data signals
        .pc_curr_EX,
        .rs1_EX,
        .rs2_EX,
        .rs3_EX,
        .imm_ex_out_EX,
        .inst_EX,
        .csr_data_r_EX,
            // control signals
        .rs2_float_EX, .rs1_float_EX, .rsW_float_EX, // float
        .csr_address_EX,
        .ALUsel_EX,
        .WBsel_EX,
        .float_inst_EX,
        .csrWBsel_EX, .regW_en_EX, .Bsel_EX, .memW_en_EX, .jump_EX, .Asel_EX, .csrW_en_EX
    );
    // ----

    // forwarding mux for csr --- 0: csr_data_r_EX - 1: csr_data_out_MEM - 2: csr_data_out_WB
    assign csr_data_r_fwd = fwd_csr ? (fwd_csr[0] ? csr_data_out_MEM : csr_data_out_WB) : csr_data_r_EX;
    // forwarding mux for A --- 0: rs1_EX - 1: ALUout_MEM - 2: regD_in
    assign data1_EX = fwd_A ? (fwd_A[0] ? ALUout_MEM : regD_in) : rs1_EX;
    // forwarding mux for B --- 0: rs2_EX - 1: ALUout_MEM - 2: regD_in
    assign data2_EX = fwd_B ? (fwd_B[0] ? ALUout_MEM : regD_in) : rs2_EX;
    // forwarding mux for C --- 0: rs3_EX - 1: ALUout_MEM - 2: regD_in
    assign data3_EX = fwd_C ? (fwd_C[0] ? ALUout_MEM : regD_in) : rs3_EX;

    branch_comp BC(.A(data1_EX), .B(data2_EX), .opcode(inst_EX[6:0]), .func3(inst_EX[14:12]), .valid_branch(valid_branch));

    // alu 1 mux -->> 1 - pc_curr | 0 - reg (rs1)
    assign ALUd1_in = Asel_EX ? pc_curr_EX : data1_EX; // <<!!----!! pc_curr_EX unmatched bits (!32)

    // alu 2 mux -->> 1 - imm gen | 0 - reg (rs2)
    assign ALUd2_in = Bsel_EX ? imm_ex_out_EX : data2_EX;

    // func3[2] (=inst_EX[14]) defines wheather to select imm or rs1
    assign csr_data_in_new = (inst_EX[14] ? imm_ex_out_EX : data1_EX);

    // if dynamic rounding mode is set, use csr_data_r_EX[7:5] else use inst_EX[14:12]
    assign f_rm = &inst_EX[14:12] ? csr_data_r_EX[7:5] : inst_EX[14:12]; 

    // addi x1, x0, -4 <--- !!! done
    alu_logic ALU(.clk, .rst, .float_inst(float_inst_EX), .f_rm, .data1(ALUd1_in), .data2(ALUd2_in), .data3(data3_EX), .ALUsel(ALUsel_EX),
        .ALUout(ALUout), .f_flags, .done);
    
    csr_compute CSRC(    
        .f_flags,
        .float_inst(float_inst_EX),
        .csr_mode(inst_EX[13:12]), // func3[1:0]
        .csr_data_in_old(csr_data_r_fwd),
        .csr_data_in_new,
        .csr_data_out
        );

    // ------------------------------------ EX/MEM --------------------------------- //
    EX_MEM EX_MEM(.clk(clk), .rst(rst), .en(EX_MEM_en), .flush(EX_MEM_flush),

        .pc_curr_EX,
        .ALUout_EX(ALUout),
        .csr_data_r_EX(csr_data_r_fwd),
        .csr_data_out_EX(csr_data_out),
        .rs2_EX(data2_EX), // for mem
        .inst_EX,
            //
        .rsW_float_EX, // float
        .csr_address_EX,
        .WBsel_EX,
        .float_inst_EX,
        .csrWBsel_EX, .regW_en_EX, .memW_en_EX, .jump_EX, .csrW_en_EX, .valid_branch_EX(valid_branch),

        .pc_curr_MEM,
        .ALUout_MEM,
        .csr_data_r_MEM,
        .csr_data_out_MEM,
        .rs2_MEM,
        .inst_MEM,
            //
        .rsW_float_MEM, // float
        .csr_address_MEM,
        .WBsel_MEM,
        .float_inst_MEM,
        .csrWBsel_MEM, .regW_en_MEM, .memW_en_MEM, .jump_MEM, .csrW_en_MEM, .valid_branch_MEM(valid_branch_MEM)
        // -------------------->> valid_branch_MEM is sent to pc_load from here !!
        // -------------------->> jump_MEM is sent to pc_load from here !!
    );

    assign pc_next_MEM = pc_curr_MEM + 4; // adder in MEM stage

    // data_mem DMEM (.clk(clk), .memW_en(memW_en_MEM),
    //    .data_in(rs2_MEM), .addr(ALUout_MEM), .func3(inst_MEM[14:12]),
    //    .data(d_mem_out) // <--
    //);
    
    // enternal DMEM module -----
    assign dmem_addr = ALUout_MEM; // <- output
    assign dmem_dataOUT = rs2_MEM; // <- output
    assign func3_MEM = inst_MEM[14:12];
    // func3_MEM <- output
    // memW_en_MEM <- output
    assign d_mem_out = dmem_dataIN; // <- input 
    // --------------------------
    // ------------------------------------ MEM/WB --------------------------------- //
    MEM_WB MEM_WB(.clk(clk), .rst(rst), .en(MEM_WB_en),
        .pc_next_MEM(pc_next_MEM),
        .ALUout_MEM,
        .csr_data_r_MEM,
        .csr_data_out_MEM,
        .d_mem_out_MEM(d_mem_out),
        .inst_MEM,

        .rsW_float_MEM, // float
        .csr_address_MEM,
        .WBsel_MEM,
        .float_inst_MEM,
        .csrWBsel_MEM, .regW_en_MEM, .csrW_en_MEM,

        .pc_next_WB,
        .ALUout_WB,
        .csr_data_r_WB,
        .csr_data_out_WB,
        .d_mem_out_WB,
        .inst_WB,
        
        .rsW_float_WB, // float
        .csr_address_WB, // ---------------->> sent to csr_reg from here
        .WBsel_WB,
        .float_inst_WB,
        .csrWBsel_WB,
        .regW_en_WB,
        .csrW_en_WB
    );

    // mux -->> 0 - d_mem_out_WB | 1 - ALUout_WB | 2 - pc_next_WB | 3 - csr_data_r_WB /// csr_data_out_WB /// <----this should be csr_data_r (old) -- for atomic operation, reg must have the prev value of csr
    assign regD_in = WBsel_WB ? (&WBsel_WB ? csr_data_r_WB : (WBsel_WB[0] ? ALUout_WB : pc_next_WB)) : d_mem_out_WB;

    hazard_detection_unit HCU(.*);


        // //logics for IP tracer//
                    
        // logic [31:0] data1_1;
        // logic [31:0] data1_2;
        // logic [31:0] data1_3;

        // logic [31:0] data2_1;
        // logic [31:0] data2_2;
        // logic [31:0] data2_3;
                    
                    
        // logic [31:0] next_addr1;
        // logic [31:0] next_addr2;
        // logic [31:0] next_addr3;
        // logic [31:0] next_addr4;
    
        // logic [31:0] im_adress1;
        // logic [31:0] im_adress2;
        // logic [31:0] im_adress3;
        // logic [31:0] im_adress4;                    
                    


// tracer tracer_ip (
// 	.clk_i(clk),
// 	.rst_ni(rst),
// 	.hart_id_i(32'b0),
// 	.rvfi_valid(1'b1),
// 	.rvfi_insn_t(inst_WB),
//         .rvfi_rs1_addr_t(inst_WB[19:15]),
//  	.rvfi_rs2_addr_t(inst_WB[24:20]),
// 	.rvfi_rs1_rdata_t(data1_3),
//  	.rvfi_rs2_rdata_t(data2_3),
// 	.rvfi_rd_addr_t(inst_WB[11:7]),
//  	.rvfi_rd_wdata_t(regD_in),
// 	.rvfi_pc_rdata_t(im_adress4),
// 	.rvfi_pc_wdata_t(next_addr4),
// 	.rvfi_mem_addr(0),
// 	.rvfi_mem_rmask(0),
// 	.rvfi_mem_wmask(0),
// 	.rvfi_mem_rdata(0),
// 	.rvfi_mem_wdata(0)
//     );


// always_ff@(posedge clk)
//     begin

// //        //data_1
//        data1_1<=data1_EX;
//        data1_2<=data1_1;
//        data1_3<=data1_2;

// //        //data_2    
//         data2_1<=data1_EX;
//         data2_2<=data2_1;
//         data2_3<=data2_2;

// //        //next_adress
//        next_addr1<=pc_curr;
//        next_addr2<=next_addr1;
//        next_addr3<=next_addr2;
//        next_addr4<=next_addr3;

// //        // im_adress
//         im_adress1<=pc_next;
//         im_adress2<=im_adress1;
//         im_adress3<=im_adress2;
//         im_adress4<=im_adress3;

//      end
endmodule
