// rtl_checker.sv -- ELEC 402 2026 Project 2. Top: mkMultBuff_tb. Copy to submission/testbench/.
// The harness below wires the DUT to the memory and makes a clock (CLK_HALF_NS 1.25 = 400 MHz, 0.625 = 800 MHz).
// Drive fill/drain, scoreboard every product read out. See README "Testbench requirements" for what to cover.

`timescale 1ns/1ps

module mult_16b_tb #(
    parameter real CLK_HALF_NS = 1.25,
    parameter int  N = 32
);

    import env_pkg::*;

    // Interfaces
    mult_16b_if        dut_if();                
    phases             phases();

    // Main DUT stimulus
    mult_16b_test_seq test_seq (.vif(dut_if), .phases(phases));

    // --------------------  DUT INSTANTIATION --------------------
    mult_16b DUT (
        .clk           (dut_if.clk),
        .RST_N         (dut_if.RST_N), 
        .EN_mult       (dut_if.EN_mult),
        .mult_input0   (dut_if.mult_input0), 
        .mult_input1   (dut_if.mult_input1), 
        .RDY_mult      (dut_if.RDY_mult),
        .output_val    (dut_if.output_val)
    );

    initial dut_if.clk = 0;
    always #(CLK_HALF_NS * 1ns) dut_if.clk = ~dut_if.clk;

    // Optional SDF back-annotation hook (used by the SDF checker flow).
    initial begin
        string sdf_path;
        if ($value$plusargs("sdf_file=%s", sdf_path))
            $sdf_annotate(sdf_path, DUT, , , "MAXIMUM");
    end

    initial begin
        setup_phases();
        reset();

        test_seq.start();
        phases.run_phase = 0;

        $stop;
    end

    task setup_phases();
        phases.reset_phase = 0;
        phases.run_phase = 0;
        phases.report_phase = 0;
    endtask

    task reset();
        phases.reset_phase = 1;
        @ (posedge dut_if.clk) dut_if.RST_N = 1'b1;
        @ (posedge dut_if.clk) dut_if.RST_N = 1'b0;
        @ (posedge dut_if.clk) dut_if.RST_N = 1'b1;
        
        phases.reset_phase = 0;
    endtask

    // --------------------  CHECKER --------------------
    initial begin
        @ (posedge phases.run_phase) begin
            
        end
    end

    // --------------------  TIMEOUT CHECK --------------------
    initial begin
        repeat (1000) @(posedge dut_if.clk);
        $error("Simulation Timeout!");
    end


endmodule