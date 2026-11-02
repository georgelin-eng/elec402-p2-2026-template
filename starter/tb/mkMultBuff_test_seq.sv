`timescale 1ps/1ps

module mkMultBuff_test_seq (
    mkMultBuff_if vif,
    phases phases,
    output integer ERROR_COUNT
);

    import env_pkg::*;

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

        repeat (8) begin
            fill_memory();
            drain_memory();
        end

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

    typedef enum {RANDOM, CORNER, READ} transaction_type;

    // During fill memory, mix a random sequence of randomized stimulus and targetted cases
    // randomize the relative ratios of random data vs corner case testing
    // randomly drop EN_mult during FILL and randomly drop EN_blockRead during DRAIN
    task fill_memory();
        integer send_count;

        send_count = 0;
        while(vif.RDY_mult) begin
            do_transaction(1, 0, RANDOM);
            // do_transaction(8, 2, RANDOM);
            // do_transaction(8,  20, CORNER);

            // send_count += 1;

            // if (send_count == 80) begin
            //     $error("FILL timeout!");
            //     $stop();
            // end
        end

        // $display("FILL done");

        scoreboard(); // run the check after filling
    endtask

    task drain_memory();
        integer send_count;

        send_count = 0;

        if (~vif.RDY_blockRead) begin
            @(vif.RDY_blockRead);
        end

        while(vif.RDY_blockRead) begin
            do_transaction(10, 2, READ);
            send_count += 1;

            // if (send_count == 64) begin
            //     $error("DRAIN timeout reached");
            //     $stop();
            // end
        end

        memory_check(); // run the check after filling
    endtask

    task send_random();
        vif.mult_input0 = $signed($urandom());
        vif.mult_input1 = $signed($urandom());
    endtask 

    task send_corner();
        automatic logic [15:0] corners[5] = '{-16'sd1, 16'sd1, 16'sd0, -16'sd32768, 16'sd32767};

        vif.mult_input0 = corners[$urandom_range(0, 4)];
        vif.mult_input1 = corners[$urandom_range(0, 4)];
    endtask 

    task do_transaction(input integer packet_length_max, input integer pause_max, input transaction_type transaction_type);
        integer packet_length;
        integer pause_length;

        packet_length = $urandom_range(1, packet_length_max);
        pause_length  = $urandom_range(0, pause_max);

        $display("Performing %s for %0dcycles and pause for %0d", transaction_type.name, packet_length, pause_length);

        repeat (packet_length) begin
            @(posedge vif.clk);

            if (transaction_type == READ) begin
                vif.EN_mult      = 1'b0;
                vif.EN_blockRead = 1'b1;
            end
            else begin
                case(transaction_type)
                    RANDOM: send_random();
                    CORNER: send_corner();
                    default : $error("Invalid transaction type");
                endcase
                vif.EN_mult      = 1'b1;
                vif.EN_blockRead = 1'b0;

                if (~vif.RDY_mult) break;
            end
        end

        if (pause_length > 0) begin
            repeat (pause_length) begin
                @(posedge vif.clk);

                if (transaction_type == READ) 
                    vif.EN_blockRead = 1'b0;
                else begin // FILL 
                    vif.EN_mult = 1'b0;

                    // During a pause, either choose to hold the value or choose to toggle random
                    if ($urandom_range(0,1)) begin
                        vif.mult_input0 = $signed($urandom());
                        vif.mult_input1 = $signed($urandom());
                    end
                end

            end
        end
    endtask

    env_pkg::mult_packet exp_mem [64]; // ref model outputs
    env_pkg::mult_packet act_mem [64]; // DUT outputs

    env_pkg::mult_packet read_mem [64]; // Track what is readout. Should match what is read in.

    // Reference model and sending values to the scoreboard for processing
    task monitor();

        bit header_lock;
        integer write_addr;
        integer read_addr;

        write_addr = 0;
        while (phases.run_phase == 1) begin
            @(negedge vif.clk);
            // @(posedge vif.clk);

            if (vif.RDY_blockRead == 1'b1) write_addr = 0;
            if (vif.EN_mult       == 1'b1) read_addr  = 0;

            // Whenver we have EN_mult
            if (vif.EN_mult && vif.RDY_mult) begin
                exp_mem[write_addr].mult_input0 = vif.mult_input0;
                exp_mem[write_addr].mult_input1 = vif.mult_input1;
                exp_mem[write_addr].mult_output = vif.mult_input0 * vif.mult_input1;

                write_addr += 1;
            end

            if (vif.EN_writeMem) begin
                act_mem[vif.writeMem_addr].mult_output = vif.writeMem_val;
            end

            if (vif.VALID_memVal) begin
                // $display("[%d] val = %d", read_addr, vif.memVal_data);
                read_mem[read_addr].mult_output = vif.memVal_data;
                read_addr += 1;
            end
        end
    endtask

    // Continuously checking the status of EN_writeMem and EN_readMem -> Error if both are high

    // Check that the memory contents are matching
    task scoreboard();
        // foreach (exp_mem[i]) begin
        //         $display("[%0d]: in0=%0d in1=%0d exp=%0d act=%0d",
        //             i,
        //             exp_mem[i].mult_input0,
        //             exp_mem[i].mult_input1,
        //             exp_mem[i].mult_output,
        //             act_mem[i].mult_output);
        // end

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

        $display("ERROR COUNT = %d", ERROR_COUNT);
    endtask

    task memory_check();
        foreach (exp_mem[i]) begin
            if (exp_mem[i].mult_output !== read_mem[i].mult_output) begin
                $error("Read mismatch at %0d: exp=%0d act=%0d",
                    i,
                    exp_mem[i].mult_output,
                    read_mem[i].mult_output);
                ERROR_COUNT += 1;
            end
        end

        $display("ERROR COUNT = %d", ERROR_COUNT);
    endtask

endmodule