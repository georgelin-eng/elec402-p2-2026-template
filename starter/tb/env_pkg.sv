package env_pkg;

    // Testbench Params
    parameter OPERAND_SIZE = 16;
    parameter PRODUCT_WIDTH = OPERAND_SIZE*2;

    typedef struct {
        
        logic signed [OPERAND_SIZE-1:0]  mult_input0;
        logic signed [OPERAND_SIZE-1:0]  mult_input1;
        logic signed [PRODUCT_WIDTH-1:0] mult_output;

    } mult_packet;

endpackage // env_pkg

interface phases;

    logic reset_phase;
    logic run_phase;
    logic report_phase;

endinterface // phases


interface mult_16b_if #(parameter N = 32);

    logic clk, RST_N;

    logic EN_mult;
    logic RDY_mult;

    logic signed [15:0] mult_input0, mult_input1;
    logic signed [N-1:0] output_val;

endinterface : mult_16b_if