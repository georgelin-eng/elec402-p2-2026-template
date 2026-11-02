// mkMultBuff.sv -- ELEC 402 2026 Project 2: fill/drain signed 16x16 multiplier buffer.
// Stores products into 64-entry memory (RDY_mult low when full); EN_blockRead & RDY_blockRead drain all 64 in order.
// Active-low synchronous reset (RST_N); latency-insensitive, any multiplier pipeline depth OK.

module mkMultBuff #(parameter N = 32) (
    input logic clk,
    input logic RST_N, // active-low synchronous reset

    // Multiplier / write side
    input logic EN_mult,
    input logic [15:0] mult_input0, // signed operand A (two's complement)
    input logic [15:0] mult_input1, // signed operand B (two's complement)
    output logic RDY_mult,

    // Read / drain side
    input logic EN_blockRead,
    output logic RDY_blockRead,
    output logic VALID_memVal,
    output logic [N-1:0] memVal_data, // signed product read from memory

    // MEMORY

    // write port 
    output logic EN_writeMem,
    output logic [5:0] writeMem_addr,
    output logic [N-1:0] writeMem_val,

    //Memory read port
    output logic EN_readMem,
    output logic [5:0] readMem_addr,
    input logic [N-1:0] readMem_val
);

    // TODO: implement the fill/drain control logic and instantiate your
    //       pipelined signed multiplier here.

    logic            EN_mult_pipelined;
    logic [N-1:0]    output_val;

    mult_16b #(
        .N              (32),
        .PIPELINE_DEPTH (2)
    ) u_mult_16b (
        .clk                (clk),
        .RST_N              (RST_N),

        // Multiplier / write side
        .EN_mult            (EN_mult),
        .mult_input0        (mult_input0),   // signed [15:0]
        .mult_input1        (mult_input1),   // signed [15:0]

        .EN_mult_pipelined  (EN_mult_pipelined),

        .output_val         (output_val)     // [N-1:0]
    ); 

    assign writeMem_val = output_val;
    assign memVal_data = readMem_val;

    mult_cntrl #(
        .MEM_DEPTH (64)
    ) u_mult_cntrl (
        .clk                (clk),
        .RST_N              (RST_N),

        .EN_mult            (EN_mult),
        .EN_mult_pipelined  (EN_mult_pipelined),
        .RDY_mult           (RDY_mult),

        // Read / drain side
        .EN_blockRead       (EN_blockRead),
        .RDY_blockRead      (RDY_blockRead),
        .VALID_memVal       (VALID_memVal),

        // Memory write port
        .EN_writeMem        (EN_writeMem),
        .writeMem_addr      (writeMem_addr),

        // Memory read port
        .EN_readMem         (EN_readMem),
        .readMem_addr       (readMem_addr)
    );



endmodule : mkMultBuff
