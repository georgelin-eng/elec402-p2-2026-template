// mult_16b.sv
// 16 bit pipelined multiplier

module mult_16b #( N = 32, PIPELINE_DEPTH = 2 ) (
    input logic clk,
    input logic RST_N, // active-low synchronous reset

    // Multiplier / write side
    input   logic           EN_mult,
    input   logic [15:0]    mult_input0,  // signed operand A (two's complement)
    input   logic [15:0]    mult_input1,  // signed operand B (two's complement)

    output  logic           EN_mult_pipelined, // this is sent to the control logic so address is synced

    output  logic [N-1:0]   output_val
);
    logic[N-1:0] partial_products [15:0];

    logic[PIPELINE_DEPTH-1:0] EN_mult_sr;

    integer i, j;

    always_ff @(posedge clk) begin
        // if (~RST_N) EN_mult_sr <= '0;
        // else        EN_mult_sr <= {EN_mult_sr[PIPELINE_DEPTH-2:0], EN_mult};

        if (~RST_N) EN_mult_pipelined <= '0;
        else        EN_mult_pipelined <= EN_mult;
    end

    // assign EN_mult_pipelined = EN_mult_sr[PIPELINE_DEPTH-1];

    // For now, simple outputs on EN_mult
    always_ff @( posedge clk) begin : blockName
        if (~RST_N) begin
            for (i = 0; i < 16; i = i+1) begin
                partial_products[i] = 32'b0;
            end              
        end else begin
            if (EN_mult) begin
                
                /*
                    Niave implementation of computing
                    16 partial products then summing them all at the end
                    
                    p0 = (a[0] & b) << 0
                    p1 = (a[1] & b) << 1
                    p2 = (a[2] & b) << 2
                    ...
                    p15 = (a[15] & b) << 15

                    output = p0 + p1 + ... + p15
                */

                // Signed binary multiplication just involves a sign extension (duplication of the MSB)
                for (i = 0; i < 16; i = i+1) begin
                    partial_products[i] = (mult_input0[i] ? {{16{mult_input1[15]}}, mult_input1} : 32'b0) << i;
                end              
            end
        end
    end

    // assign output_val = partial_products[0] + partial_products[1];

    always_comb begin : sum_partial_products
    output_val = -partial_products[15];;
       for (j = 0; j < 15; j = j + 1) begin
            output_val = output_val + partial_products[j];
        end 
    end

endmodule

