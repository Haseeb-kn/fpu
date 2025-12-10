// 64 bit option for AWS labs
-64
-uvmhome /home/cc/mnt/XCELIUM2309/tools/methodology/UVM/CDNS-1.1d



// include directories
-incdir /home/cc/fpu_uvm/UVC_fpu/sv
-incdir /home/cc/fpu_uvm/UVC_fpu/tb
-incdir /home/cc/fpu_uvm/rtl



// Coverage options - ADD THESE
-coverage all
-covoverwrite
-covtest coverage_test
-covdut top_core



// compile files

/home/cc/fpu_uvm/UVC_fpu/sv/fpu_pkg.sv
/home/cc/fpu_uvm/UVC_fpu/tb/fpu_if.sv
/home/cc/fpu_uvm/rtl/top_core.sv
// Then compile the top module
/home/cc/fpu_uvm/UVC_fpu/tb/fpu_top.sv
// UVM test configuration
+UVM_TESTNAME=top_core_load_test
+UVM_VERBOSITY=UVM_LOW
