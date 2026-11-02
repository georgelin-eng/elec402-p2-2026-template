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

endmodule : mult_16b



// mult_cntrl

module mult_cntrl # (MEM_DEPTH = 64)(
    input logic clk,
    input logic RST_N,

    input logic EN_mult,
    input logic EN_mult_pipelined, // synced with multiplier products
    output logic RDY_mult,

    // Read / drain side
    input logic EN_blockRead,
    output logic RDY_blockRead,
    output logic VALID_memVal,

    // Memory write port
    output logic EN_writeMem,
    output logic [5:0] writeMem_addr,

    // Memory read port
    output logic EN_readMem,
    output logic [5:0] readMem_addr
);
    
    typedef enum logic [3:0]
    { 
        IDLE,
        FILL,
        FILL_DROP_RDY,
        FULL,
        DRAIN,
        EMPTY,
        EMPTY_DROP_VALID
    } fsm_state;

    fsm_state state, next_state;

/*
    1. Reset:
        RDY_mult = 1
        {rest} = 0

    2. Fill w/ pause
        write_{mem, addr, val} paused 
        address counters puased
    
    3. Full
        RDY_mult must drop early
            RDY_mult should be based on 
            inputs to the multiplier that appear
            when EN_mult = 1 so that pipeline depth
            doesn't matter

        write_addr counts up to 63 and write_mem is 1 
        RDY_blockRead = 1 on the same cycle write_mem goes 0

    4. Drain w/ pause
        EN_blockRead can be dropped at any time
        VALID_memVal and memVal_data should pause when this happens
        address counter is also paused

        check this via sampling whenever VALID_memVal = 1


    5. Empty and can repeat without reset
        RDY_blockRead = 1 when we reach the end
        VALID_memVal = 0
        RDY_mult = 1

        Fill once EN_mult = 1
        writeMem_addr starts at 0 

        Drain once EN_blockRead = 1
        readMem_addr starts at 0
*/

    logic [5:0] mult_req_received;
    logic       is_not_full;
    logic       is_not_empty;

    logic       reset_write_count;
    logic       reset_read_count;

    // Next state logic
    always_ff @(posedge clk) begin
        if (~RST_N) state <= IDLE;
        else        state <= next_state;
    end

    // State transition logic
    always_comb begin
        case (state)
            IDLE: begin 
                if (EN_mult)    next_state = FILL;
                else            next_state = IDLE;
            end

            FILL: begin
                if (mult_req_received == MEM_DEPTH-1) next_state = FILL_DROP_RDY;
                else                                  next_state = FILL;
            end

            FILL_DROP_RDY: begin
                if (writeMem_addr == MEM_DEPTH-1) next_state = FULL;
                else                              next_state = FILL_DROP_RDY;
            end

            FULL: begin
                if (EN_blockRead) next_state = DRAIN;
                else              next_state = FULL;
            end

            DRAIN: begin
                if (readMem_addr == MEM_DEPTH-1) next_state = EMPTY;
                else                             next_state = DRAIN;
            end

            EMPTY: begin
                if (EN_mult) next_state = FILL;
                else         next_state = EMPTY;
            end


            default: next_state = IDLE;

        endcase
    end

    // Assign: one cycle too slow
    always_comb begin
        case(state)
            FILL: EN_writeMem = 1'b1 & EN_mult_pipelined;
            FILL_DROP_RDY: EN_writeMem = 1'b1;
            default: EN_writeMem = 1'b0;
        endcase
    end

    // State output logic
    always_ff @(posedge clk) begin
        if (!RST_N) begin
            RDY_mult <= 1'b0;
            RDY_blockRead <= 1'b0;
            is_not_full   <= 1'b0;
            is_not_empty  <= 1'b0;

            reset_write_count <= 1'b0;
            reset_read_count  <= 1'b0;
        end
        else begin
            RDY_mult <= 1'b0;
            RDY_blockRead <= 1'b0;
            is_not_full   <= 1'b0;
            is_not_empty  <= 1'b0;

            reset_write_count <= 1'b0;
            reset_read_count  <= 1'b0;

            case (next_state)
                IDLE: begin
                    RDY_mult <= 1'b1;
                    is_not_full <= 1'b1;
                end

                FILL: begin
                    RDY_mult <= 1'b1;
                    is_not_full <= 1'b1;
                    reset_read_count <= 1'b1;
                end

                FILL_DROP_RDY: begin
                    RDY_mult <= 1'b0;
                    is_not_full <= 1'b0;
                end

                FULL: begin
                    RDY_blockRead <= 1'b1;
                    is_not_empty <= 1'b1;
                end

                DRAIN: begin
                    is_not_empty <= 1'b1;
                    RDY_blockRead <= 1'b1;
                    // VALID_memVal <= 1'b1 & EN_blockRead;
                    reset_write_count <= 1'b1;
                end

                EMPTY: begin
                    is_not_empty <= 1'b0;
                    // VALID_memVal <= 1'b1;
                    RDY_blockRead <= 1'b0;
                    RDY_mult      <= 1'b1;
                    is_not_full <= 1'b1;
                end

                default: begin
                    RDY_mult <= 1'b0;
                    RDY_blockRead <= 1'b0;
                end
            endcase
        end

    end

    // EN_readMem is high on the same cycle as EN_blockRead
    // so it must be implemented with combinational logic
    assign EN_readMem = EN_blockRead && RDY_blockRead;

    always_ff @(posedge clk) begin
        if (~RST_N) VALID_memVal <= 1'b0;
        else VALID_memVal <= EN_readMem;
    end

    // Address counters

    always_ff @( posedge clk ) begin : write_addr_counter
        if (~RST_N) begin
            writeMem_addr <= 'b0;
            mult_req_received <= 'b0;
        end
        else if (reset_write_count) begin
            writeMem_addr <= 'b0;
            mult_req_received <= 'b0;
        end else begin

            // sync write address with the pipelined products
            if (EN_mult_pipelined && is_not_full) begin
                writeMem_addr <= writeMem_addr + 1;
            end

            // For dropping RDY_mult early
            if (EN_mult && is_not_full) begin
                mult_req_received <= mult_req_received + 1;
            end
        end
    end

    always_ff @( posedge clk ) begin : read_addr_counter
        if (~RST_N) begin
            readMem_addr <= 'b0;
        end else if (reset_read_count) begin
            readMem_addr <= 'b0;
        end
        else begin
            if (EN_blockRead && is_not_empty) begin
                readMem_addr <= readMem_addr + 1;
            end
        end
    end

endmodule : mult_cntrl

