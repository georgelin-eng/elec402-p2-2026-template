// rtl_checker.sv -- ELEC 402 2026 Project 2. Top: mkMultBuff_tb. Copy to submission/testbench/.
// The harness below wires the DUT to the memory and makes a clock (CLK_HALF_NS 1.25 = 400 MHz, 0.625 = 800 MHz).
// Drive fill/drain, scoreboard every product read out. See README "Testbench requirements" for what to cover.

`timescale 1ns/1ps

module mkMultBuff_tb #(
    parameter real CLK_HALF_NS = 1.25,
    parameter int  N = 32
);

    integer ERROR_COUNT;

    logic clk, RST_N;

    logic EN_mult;
    logic [15:0] mult_input0, mult_input1;
    logic RDY_mult;

    logic EN_blockRead;
    logic RDY_blockRead;
    logic VALID_memVal;
    logic [N-1:0] memVal_data;

    logic EN_writeMem, EN_readMem;
    logic [5:0] writeMem_addr, readMem_addr;
    logic [N-1:0] writeMem_val, readMem_val;


    // Interfaces
    mkMultBuff_if      dut_if();
    phases             phases();

    // Main DUT stimulus
    mkMultBuff_test_seq test_seq (.vif(dut_if), .phases(phases), .ERROR_COUNT(ERROR_COUNT));

    // These are set in TB so handle seperately from input and output wiring
    assign dut_if.clk = clk;
    assign dut_if.RST_N = RST_N;
    assign dut_if.readMem_val = readMem_val;

    // Input connections

    assign EN_mult       = dut_if.EN_mult;
    assign mult_input0   = dut_if.mult_input0;
    assign mult_input1   = dut_if.mult_input1;

    assign EN_blockRead  = dut_if.EN_blockRead;


    // Output connections
    assign dut_if.RDY_mult      = RDY_mult;

    assign dut_if.RDY_blockRead = RDY_blockRead;
    assign dut_if.VALID_memVal  = VALID_memVal;
    assign dut_if.memVal_data   = memVal_data;

    assign dut_if.EN_writeMem   = EN_writeMem;
    assign dut_if.writeMem_addr = writeMem_addr;
    assign dut_if.writeMem_val  = writeMem_val;

    assign dut_if.EN_readMem    = EN_readMem;
    assign dut_if.readMem_addr  = readMem_addr; 

    mkMultBuff #(.N(N)) DUT (
        .clk(clk), .RST_N(RST_N),
        .EN_mult(EN_mult),
        .mult_input0(mult_input0), .mult_input1(mult_input1),
        .RDY_mult(RDY_mult),
        .EN_blockRead(EN_blockRead), .RDY_blockRead(RDY_blockRead),
        .VALID_memVal(VALID_memVal), .memVal_data(memVal_data),
        .EN_writeMem(EN_writeMem), .writeMem_addr(writeMem_addr),
        .writeMem_val(writeMem_val),
        .EN_readMem(EN_readMem), .readMem_addr(readMem_addr),
        .readMem_val(readMem_val)
    );

    // The memory belongs to the testbench, not to mkMultBuff.
    memory_wrapper_2port #(
        .DEPTH(64), .LOGDEPTH(6), .WIDTH(N), .MEMTYPE(0)
    ) MEM (
        .clkA(clk), .aA(readMem_addr), .cenA(~EN_readMem), .q(readMem_val),
        .clkB(clk), .aB(writeMem_addr), .cenB(~EN_writeMem), .d(writeMem_val)
    );

    initial clk = 0;
    always #(CLK_HALF_NS * 1ns) clk = ~clk;

    // Optional SDF back-annotation hook (used by the SDF checker flow).
    initial begin
        string sdf_path;
        if ($value$plusargs("sdf_file=%s", sdf_path))
            $sdf_annotate(sdf_path, DUT, , , "MAXIMUM");
    end

    initial begin
        // TODO: reset, fill the memory with signed products, drain and check,
        //       print "ALL PASS" on success. bob.py greps for "ALL PASS".

        setup_phases();
        reset();

        test_seq.start();
        phases.run_phase = 0;


        $display("ERROR COUNT = %d", ERROR_COUNT);
        if (ERROR_COUNT == 0) $display("ALL PASS");
        else                  $display("** TEST FAILED! **");

        $stop;
    end

    task setup_phases();
        phases.reset_phase = 0;
        phases.run_phase = 0;
        phases.report_phase = 0;
    endtask

    task reset();
        phases.reset_phase = 1;
        @ (posedge clk) RST_N = 1'b1;
        @ (posedge clk) RST_N = 1'b0;
        @ (posedge clk) RST_N = 1'b1;
        
        phases.reset_phase = 0;
    endtask

endmodule
