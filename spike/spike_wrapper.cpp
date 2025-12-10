/*******************************************************************************
 * Spike DPI Wrapper for UVM Verification
 * 
 * This file provides SystemVerilog DPI-C interface to Spike ISA simulator
 * for use as a golden reference model in UVM testbenches.
 * 
 * Compile: g++ -shared -fPIC -o libspike_wrapper.so spike_wrapper.cpp \
 *          -I$RISCV/include -L$RISCV/lib -lriscv
 ******************************************************************************/

#include <iostream>
#include <vector>
#include <cstring>
#include "svdpi.h"

// Spike headers
#include "riscv/sim.h"
#include "riscv/mmu.h"
#include "riscv/processor.h"
#include "riscv/decode.h"

// Global Spike simulator instance
static sim_t* g_spike_sim = nullptr;
static processor_t* g_spike_proc = nullptr;
static bool g_spike_initialized = false;

//==============================================================================
// Helper Functions
//==============================================================================

static void check_initialized() {
    if (!g_spike_initialized) {
        std::cerr << "ERROR: Spike not initialized! Call spike_init() first." << std::endl;
    }
}

static processor_t* get_processor() {
    check_initialized();
    return g_spike_proc;
}

static state_t* get_state() {
    return get_processor()->get_state();
}

//==============================================================================
// DPI-C Exported Functions
//==============================================================================

extern "C" {

/**
 * Initialize Spike simulator
 * @param isa_string - ISA string (e.g., "RV32IF", "RV64IMAFD")
 */
void spike_init(const char* isa_string) {
    try {
        if (g_spike_initialized) {
            std::cout << "WARNING: Spike already initialized, re-initializing..." << std::endl;
            spike_close();
        }
        
        // Create memory region (128MB at 0x80000000)
        std::vector<std::pair<reg_t, mem_t*>> mems;
        mems.push_back(std::make_pair(reg_t(0x80000000), new mem_t(0x8000000)));
        
        // Create simulator
        std::vector<std::string> htif_args;
        g_spike_sim = new sim_t(
            isa_string,           // ISA string
            1,                    // Number of cores
            false,                // Halted
            0x80000000,           // Start PC
            mems,                 // Memory regions
            htif_args,            // HTIF arguments
            std::vector<int>()    // Hartids
        );
        
        // Get processor handle
        g_spike_proc = g_spike_sim->get_core(0);
        g_spike_initialized = true;
        
        std::cout << "Spike initialized with ISA: " << isa_string << std::endl;
        
    } catch (const std::exception& e) {
        std::cerr << "ERROR initializing Spike: " << e.what() << std::endl;
        g_spike_initialized = false;
    }
}

/**
 * Reset Spike state
 */
void spike_reset() {
    check_initialized();
    
    try {
        state_t* state = get_state();
        
        // Reset integer registers
        for (int i = 0; i < NXPR; i++) {
            state->XPR.write(i, 0);
        }
        
        // Reset FP registers
        for (int i = 0; i < NFPR; i++) {
            state->FPR.write(i, 0);
        }
        
        // Reset PC
        state->pc = 0x80000000;
        
        // Reset FCSR
        state->fcsr = 0;
        
        std::cout << "Spike reset completed" << std::endl;
        
    } catch (const std::exception& e) {
        std::cerr << "ERROR resetting Spike: " << e.what() << std::endl;
    }
}

/**
 * Close and cleanup Spike
 */
void spike_close() {
    if (g_spike_sim != nullptr) {
        delete g_spike_sim;
        g_spike_sim = nullptr;
        g_spike_proc = nullptr;
        g_spike_initialized = false;
        std::cout << "Spike closed" << std::endl;
    }
}

/**
 * Read floating-point register
 * @param reg_num - Register number (0-31)
 * @return Register value as 32-bit integer
 */
int spike_read_freg(int reg_num) {
    check_initialized();
    
    if (reg_num < 0 || reg_num >= NFPR) {
        std::cerr << "ERROR: Invalid FP register number: " << reg_num << std::endl;
        return 0;
    }
    
    try {
        // Read FP register and return as 32-bit value
        freg_t fp_value = get_state()->FPR[reg_num];
        return fp_value.v[0] & 0xFFFFFFFF;  // Get lower 32 bits
    } catch (const std::exception& e) {
        std::cerr << "ERROR reading FP register: " << e.what() << std::endl;
        return 0;
    }
}

/**
 * Write floating-point register
 * @param reg_num - Register number (0-31)
 * @param value - 32-bit value to write
 */
void spike_write_freg(int reg_num, int value) {
    check_initialized();
    
    if (reg_num < 0 || reg_num >= NFPR) {
        std::cerr << "ERROR: Invalid FP register number: " << reg_num << std::endl;
        return;
    }
    
    try {
        // Create freg_t with 32-bit value (NaN-boxed for RV64)
        freg_t fp_value;
        fp_value.v[0] = value;
        fp_value.v[1] = 0xFFFFFFFFFFFFFFFFULL;  // NaN-box upper bits
        get_state()->FPR.write(reg_num, fp_value);
    } catch (const std::exception& e) {
        std::cerr << "ERROR writing FP register: " << e.what() << std::endl;
    }
}

/**
 * Read integer register
 * @param reg_num - Register number (0-31)
 * @return Register value
 */
int spike_read_xreg(int reg_num) {
    check_initialized();
    
    if (reg_num < 0 || reg_num >= NXPR) {
        std::cerr << "ERROR: Invalid integer register number: " << reg_num << std::endl;
        return 0;
    }
    
    try {
        return get_state()->XPR[reg_num];
    } catch (const std::exception& e) {
        std::cerr << "ERROR reading integer register: " << e.what() << std::endl;
        return 0;
    }
}

/**
 * Write integer register
 * @param reg_num - Register number (0-31)
 * @param value - Value to write
 */
void spike_write_xreg(int reg_num, int value) {
    check_initialized();
    
    if (reg_num < 0 || reg_num >= NXPR) {
        std::cerr << "ERROR: Invalid integer register number: " << reg_num << std::endl;
        return;
    }
    
    try {
        get_state()->XPR.write(reg_num, value);
    } catch (const std::exception& e) {
        std::cerr << "ERROR writing integer register: " << e.what() << std::endl;
    }
}

/**
 * Read program counter
 * @return Current PC value
 */
int spike_read_pc() {
    check_initialized();
    
    try {
        return get_state()->pc;
    } catch (const std::exception& e) {
        std::cerr << "ERROR reading PC: " << e.what() << std::endl;
        return 0;
    }
}

/**
 * Write program counter
 * @param pc_value - New PC value
 */
void spike_write_pc(int pc_value) {
    check_initialized();
    
    try {
        get_state()->pc = pc_value;
    } catch (const std::exception& e) {
        std::cerr << "ERROR writing PC: " << e.what() << std::endl;
    }
}

/**
 * Read CSR (Control and Status Register)
 * @param csr_addr - CSR address
 * @return CSR value
 */
int spike_read_csr(int csr_addr) {
    check_initialized();
    
    try {
        // Special handling for FCSR (0x003)
        if (csr_addr == 0x003) {
            return get_state()->fcsr;
        }
        // Add other CSRs as needed
        return 0;
    } catch (const std::exception& e) {
        std::cerr << "ERROR reading CSR: " << e.what() << std::endl;
        return 0;
    }
}

/**
 * Write CSR (Control and Status Register)
 * @param csr_addr - CSR address
 * @param value - Value to write
 */
void spike_write_csr(int csr_addr, int value) {
    check_initialized();
    
    try {
        // Special handling for FCSR (0x003)
        if (csr_addr == 0x003) {
            get_state()->fcsr = value;
        }
        // Add other CSRs as needed
    } catch (const std::exception& e) {
        std::cerr << "ERROR writing CSR: " << e.what() << std::endl;
    }
}

/**
 * Execute a single instruction
 * @param instruction - 32-bit instruction encoding
 * @return 0 on success, non-zero on error
 */
int spike_execute_instruction(int instruction) {
    check_initialized();
    
    try {
        // Store instruction in memory at current PC
        reg_t pc = get_state()->pc;
        mmu_t* mmu = get_processor()->get_mmu();
        
        // Write instruction to memory
        mmu->store_uint32(pc, instruction);
        
        // Execute one instruction
        get_processor()->step(1);
        
        return 0;
    } catch (const std::exception& e) {
        std::cerr << "ERROR executing instruction 0x" << std::hex << instruction 
                  << ": " << e.what() << std::endl;
        return -1;
    }
}

/**
 * Step one instruction (without specifying instruction)
 * @return 0 on success, non-zero on error
 */
int spike_step_one() {
    check_initialized();
    
    try {
        get_processor()->step(1);
        return 0;
    } catch (const std::exception& e) {
        std::cerr << "ERROR stepping: " << e.what() << std::endl;
        return -1;
    }
}

/**
 * Read memory
 * @param addr - Memory address
 * @return 32-bit value from memory
 */
int spike_read_mem(int addr) {
    check_initialized();
    
    try {
        mmu_t* mmu = get_processor()->get_mmu();
        return mmu->load_uint32(addr);
    } catch (const std::exception& e) {
        std::cerr << "ERROR reading memory at 0x" << std::hex << addr 
                  << ": " << e.what() << std::endl;
        return 0;
    }
}

/**
 * Write memory
 * @param addr - Memory address
 * @param data - 32-bit value to write
 */
void spike_write_mem(int addr, int data) {
    check_initialized();
    
    try {
        mmu_t* mmu = get_processor()->get_mmu();
        mmu->store_uint32(addr, data);
    } catch (const std::exception& e) {
        std::cerr << "ERROR writing memory at 0x" << std::hex << addr 
                  << ": " << e.what() << std::endl;
    }
}

} // extern "C"
