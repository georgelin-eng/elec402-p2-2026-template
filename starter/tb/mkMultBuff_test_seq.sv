`timescale 1ps/1ps

module mkMultBuff_test_seq (
    mkMultBuff_if vif,
    phases phases
);

    import env_pkg::*;

    integer ERROR_COUNT;

    task start();
        @(posedge vif.clk);

        fork
            test_seq();
            monitor();
            // scoreboard();
        join

    endtask // start

    task test_seq();
        integer RDY_timout_count;

        phases.run_phase = 1;
        ERROR_COUNT = 0;
        RDY_timout_count = 0;

        // We're in reset. Check that RDY_mult is 1
        while (~vif.RDY_mult) begin
            // Wait for it to go one. If after 100x clock cycles throw error
            @(posedge vif.clk);
            RDY_timout_count += 1;

            if (RDY_timout_count == 100) begin
                $error("Multiplier is not ready");
                ERROR_COUNT += 1;
            end
        end
        $display("[%0t] Multiplier Ready", $time);

        fill_memory();

        // fill all 64, drain all 64, repeat
        // repeat(8) begin
        //     fill_memory();
        //     drain_memory();
        // end

        // Check that RDY_mult is dropped at the right time
        // Check that RDY_blockRead is low during the fill, high once full, and low again after the 64th read

        phases.run_phase = 0;

        $display("mkMultBuff_test_seq finished");
    endtask

    // During fill memory, mix a random sequence of randomized stimulus and targetted cases
    // randomize the relative ratios of random data vs corner case testing
    // randomly drop EN_mult during FILL and randomly drop EN_blockRead during DRAIN
    task fill_memory();
        integer packet_length; // number of values to send before pausing EN_mult
        integer pause_length;  // cycles to pause

        integer send_count;

        send_count = 0;
        while(vif.RDY_mult) begin
            send_random(8, 3);
            send_corner(4, 2);

            send_count += 1;

            if (send_count == 64) begin
                $error("FILL not working");
                $stop();
            end
        end

        scoreboard(); // run the check after filling

    endtask

    task drain_memory();
        while(vif.RDY_mult) begin
            readout(8, 2) ;  
        end
    endtask

    task readout(input integer packet_length_max, input integer pause_max);
        integer packet_length;
        integer pause_length;

        packet_length = $urandom_range(1, packet_length_max);
        pause_length  = $urandom_range(0, pause_max);

        $display("[Random] Reading %d and pause for %d", packet_length, pause_length);

        // Send random data
        repeat (packet_length) begin
            @(posedge vif.clk);

            vif.EN_blockRead = 1'b1;
        end

        if (pause_length > 0) begin
            repeat (pause_length) begin
                @(posedge vif.clk);
                vif.EN_blockRead = 1'b0;
            end
        end

    endtask

    task send_random(input integer packet_length_max, input integer pause_max);
        integer packet_length;
        integer pause_length;

        packet_length = $urandom_range(1, packet_length_max);
        pause_length  = $urandom_range(0, pause_max);

        $display("[Random] Sending %d and pause for %d", packet_length, pause_length);

        // Send random data
        repeat (packet_length) begin
            @(posedge vif.clk);

            vif.EN_mult     = 1'b1;
            vif.mult_input0 = $signed($urandom());
            vif.mult_input1 = $signed($urandom());
        end

        if (pause_length > 0) begin
            repeat (pause_length) begin
                @(posedge vif.clk);
                vif.EN_mult = 1'b0;

                // During a pause, either choose to hold the value or choose to toggle random
                if ($urandom_range(0,1)) begin
                    vif.mult_input0 = $signed($urandom());
                    vif.mult_input1 = $signed($urandom());
                end
            end
        end
    endtask

    task send_corner(input integer packet_length_max, input integer pause_max);
        integer packet_length;
        integer pause_length;

        // five corner values
        static logic signed [15:0] corners[5] = '{-16'sd1, 16'sd1, 16'sd0, -16'sd32768, 16'sd32767};

        packet_length = $urandom_range(1, packet_length_max);
        pause_length  = $urandom_range(0, pause_max);

        repeat (packet_length) begin
            @(posedge vif.clk);

            vif.EN_mult = 1'b1;
            vif.mult_input0 = corners[$urandom_range(0,4)];
            vif.mult_input1 = corners[$urandom_range(0,4)];
        end

        if (pause_length > 0) begin
            repeat (pause_length) begin
                @(posedge vif.clk);
                vif.EN_mult = 1'b0;

                // During a pause, either choose to hold the value or choose to toggle random
                if ($urandom_range(0,1)) begin
                    vif.mult_input0 = $signed($urandom());
                    vif.mult_input1 = $signed($urandom());
                end
            end
        end
    endtask
    
    env_pkg::mult_packet exp_mem [64]; // ref model outputs
    env_pkg::mult_packet act_mem [64];    // DUT outputs

    // Reference model and sending values to the scoreboard for processing
    task monitor();

        bit header_lock;
        integer write_addr;

        write_addr = 0;
        while (phases.run_phase == 1) begin
            @(negedge vif.clk);

            // Whenver we have EN_mult
            if (vif.EN_mult) begin
                exp_mem[write_addr].mult_input0 = vif.mult_input0;
                exp_mem[write_addr].mult_input1 = vif.mult_input1;
                exp_mem[write_addr].mult_output = vif.mult_input0 * vif.mult_input1;

                write_addr += 1;
            end

            if (vif.EN_writeMem) begin
                act_mem[vif.writeMem_addr].mult_output = vif.writeMem_val;
            end
        end
    endtask

    // Continuously checking the status of EN_writeMem and EN_readMem -> Error if both are high
    task scoreboard();
        foreach (exp_mem[i]) begin
            if (exp_mem[i].mult_output !== act_mem[i].mult_output) begin
                $error("Mem mismatch at %0d: in0=%0d in1=%0d exp=%0d act=%0d",
                    i,
                    exp_mem[i].mult_input0,
                    exp_mem[i].mult_input1,
                    exp_mem[i].mult_output,
                    act_mem[i].mult_output);
                ERROR_COUNT += 1;
            end
        end
    endtask

endmodule