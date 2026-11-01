`timescale 1ps/1ps

module mult_16b_test_seq (
    mult_16b_if vif,
    phases phases
);

    import env_pkg::*;

    task start();
        @(posedge vif.clk);
        vif.EN_mult = 1'b1;


        fork
            test_seq();
            monitor();
            scoreboard();
        join

    endtask // start

    task test_seq();
        phases.run_phase = 1;

        @(posedge vif.clk);
        send_custom();

        repeat (100) begin
            send_random();
        end   

        repeat (100) begin
            send_corner();
        end   

        phases.run_phase = 0;
    endtask

    task send_custom();
        @(posedge vif.clk);
        vif.mult_input0 = 1;
        vif.mult_input1 = 1;

        @(posedge vif.clk);
        vif.mult_input0 = 10;
        vif.mult_input1 = -100;

        @(posedge vif.clk);
        vif.mult_input0 = 5000;
        vif.mult_input1 = -120;

        @(posedge vif.clk);
        vif.mult_input0 = -32768;
        vif.mult_input1 = 20;

        @(posedge vif.clk);
        vif.mult_input0 = -32768;
        vif.mult_input1 = 32767;

        @(posedge vif.clk);
        vif.mult_input0 = -32768;
        vif.mult_input1 = 32767;

        @(posedge vif.clk);
        vif.mult_input0 = -32768;
        vif.mult_input1 = 32767;

        @(posedge vif.clk);
        vif.mult_input0 = 50000;
        vif.mult_input1 = -1200;

        @(posedge vif.clk);
        vif.mult_input0 = 500000;
        vif.mult_input1 = -1200;

    endtask

    task send_random();
        @(posedge vif.clk);
        vif.mult_input0 = $signed($urandom());
        vif.mult_input1 = $signed($urandom());
        
    endtask

    task send_corner();
        // The five corner values
        static logic signed [15:0] corners[5] = '{-16'sd1, 16'sd1, 16'sd0, -16'sd32768, 16'sd32767};

        @(posedge vif.clk);
        vif.mult_input0 = corners[$urandom_range(0,4)];
        vif.mult_input1 = corners[$urandom_range(0,4)];
    endtask
    
    env_pkg::mult_packet exp_q[$]; // ref model outputs
    env_pkg::mult_packet act_q[$];    // DUT outputs

    task monitor();
        env_pkg::mult_packet exp_p;
        env_pkg::mult_packet act_p;

        bit header_lock;

        while (phases.run_phase == 1) begin
            @(negedge vif.clk);
            // creating expected to actual pairs
            exp_p.mult_input0 = vif.mult_input0;
            exp_p.mult_input1 = vif.mult_input1;
            exp_p.mult_output = vif.mult_input0 * vif.mult_input1;

            act_p.mult_output = vif.output_val;

            exp_q.push_back(exp_p);
            act_q.push_back(act_p);

            // Keep the expected queue going

        end

    endtask

    task scoreboard();
        env_pkg::mult_packet exp_p;
        env_pkg::mult_packet act_p;

        bit header_lock;

        // Perform check
        header_lock = 0;
        while (phases.run_phase == 1 || (exp_q.size() > 0 && act_q.size() > 0)) begin
            // Block until a pair is available or the phase ends
            wait ((exp_q.size() > 0 && act_q.size() > 0) || phases.run_phase != 1);
            if (exp_q.size() == 0 || act_q.size() == 0) break;


            // Depending on the pipeline depth of the multiplier it takes
            // a while for data to appear on the output. Pop out the garbage data
            // until we see the first expected value output
            // At this point, the outputs of the multiplier should be aligned

            exp_p = exp_q.pop_front();
            act_p = act_q.pop_front();

            if (header_lock == 0) begin
                $display("exp: %0d, act: %0d", exp_p.mult_output, act_p.mult_output);

                // Discard pipeline garbage until the first expected value
                if ($isunknown(exp_p.mult_output)) continue;

                // Once we see the first correct output the streams are aligned
                if (exp_p.mult_output == act_p.mult_output) begin
                    header_lock = 1;
                end else begin
                    exp_q.push_front(exp_p);  // keep expected, drop stale actual
                end
            end else begin // we now have header lock. Proceed with pair wise comparison

                if (exp_p.mult_output !== act_p.mult_output) begin
                $error("Mismatch! A=%d, B=%d: Exp=%d, Act=%d",
                        exp_p.mult_input0, exp_p.mult_input1,
                        exp_p.mult_output, act_p.mult_output);
                end
                else begin
                    $display("Macthing data");
                end
            end
        end

        if (!header_lock) $error("Scoreboard never achieved header lock");
    endtask

endmodule