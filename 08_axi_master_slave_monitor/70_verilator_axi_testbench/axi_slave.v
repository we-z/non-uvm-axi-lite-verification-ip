//============================================================================
// AXI-Lite Reference Slave (Verilator Compatible)
//
// Simplified AXI slave with:
// - Fixed-size memory (no associative arrays)
// - FIFO-based queues (no SystemVerilog queues)
// - Out-of-order read response support based on ID
//============================================================================

module axi_slave #(
    parameter ADDR_WIDTH = 32,
    parameter DATA_WIDTH = 32,
    parameter ID_WIDTH   = 4,
    parameter MEM_DEPTH  = 256,      // Memory depth (addresses 0 to MEM_DEPTH-1)
    parameter FIFO_DEPTH = 16        // FIFO depth for pending transactions
)(
    input  wire                   clk,
    input  wire                   rst,

    // Read Address Channel
    input  wire [ADDR_WIDTH-1:0]  araddr,
    input  wire [ID_WIDTH-1:0]    arid,
    input  wire                   arvalid,
    output reg                    arready,

    // Write Address Channel
    input  wire [ADDR_WIDTH-1:0]  awaddr,
    input  wire                   awvalid,
    output reg                    awready,

    // Write Data Channel
    input  wire [DATA_WIDTH-1:0]  wdata,
    input  wire                   wvalid,
    output reg                    wready,

    // Read Data Channel
    output reg  [DATA_WIDTH-1:0]  rdata,
    output reg  [ID_WIDTH-1:0]    rid,
    output reg                    rvalid,
    input  wire                   rready,

    // Write Response Channel
    output reg                    bvalid,
    input  wire                   bready
);

    localparam N_IDS = 1 << ID_WIDTH;
    localparam ADDR_BITS = $clog2(MEM_DEPTH);

    //--------------------------------------------------------------------------
    // Memory
    //--------------------------------------------------------------------------
    reg [DATA_WIDTH-1:0] memory [0:MEM_DEPTH-1];

    //--------------------------------------------------------------------------
    // Write Address FIFO
    //--------------------------------------------------------------------------
    reg [ADDR_WIDTH-1:0] wr_addr_fifo [0:FIFO_DEPTH-1];
    reg [3:0] wr_addr_wr_ptr, wr_addr_rd_ptr;
    wire wr_addr_empty = (wr_addr_wr_ptr == wr_addr_rd_ptr);
    wire wr_addr_full  = (wr_addr_wr_ptr[3] != wr_addr_rd_ptr[3]) &&
                         (wr_addr_wr_ptr[2:0] == wr_addr_rd_ptr[2:0]);

    //--------------------------------------------------------------------------
    // Write Data FIFO
    //--------------------------------------------------------------------------
    reg [DATA_WIDTH-1:0] wr_data_fifo [0:FIFO_DEPTH-1];
    reg [3:0] wr_data_wr_ptr, wr_data_rd_ptr;
    wire wr_data_empty = (wr_data_wr_ptr == wr_data_rd_ptr);
    wire wr_data_full  = (wr_data_wr_ptr[3] != wr_data_rd_ptr[3]) &&
                         (wr_data_wr_ptr[2:0] == wr_data_rd_ptr[2:0]);

    //--------------------------------------------------------------------------
    // Read Response FIFOs (one per ID for out-of-order support)
    //--------------------------------------------------------------------------
    reg [DATA_WIDTH-1:0] rd_data_fifo_0 [0:FIFO_DEPTH-1];
    reg [DATA_WIDTH-1:0] rd_data_fifo_1 [0:FIFO_DEPTH-1];
    reg [DATA_WIDTH-1:0] rd_data_fifo_2 [0:FIFO_DEPTH-1];
    reg [DATA_WIDTH-1:0] rd_data_fifo_3 [0:FIFO_DEPTH-1];
    reg [DATA_WIDTH-1:0] rd_data_fifo_4 [0:FIFO_DEPTH-1];
    reg [DATA_WIDTH-1:0] rd_data_fifo_5 [0:FIFO_DEPTH-1];
    reg [DATA_WIDTH-1:0] rd_data_fifo_6 [0:FIFO_DEPTH-1];
    reg [DATA_WIDTH-1:0] rd_data_fifo_7 [0:FIFO_DEPTH-1];

    reg [3:0] rd_wr_ptr_0, rd_wr_ptr_1, rd_wr_ptr_2, rd_wr_ptr_3;
    reg [3:0] rd_wr_ptr_4, rd_wr_ptr_5, rd_wr_ptr_6, rd_wr_ptr_7;
    reg [3:0] rd_rd_ptr_0, rd_rd_ptr_1, rd_rd_ptr_2, rd_rd_ptr_3;
    reg [3:0] rd_rd_ptr_4, rd_rd_ptr_5, rd_rd_ptr_6, rd_rd_ptr_7;

    // Check if FIFO has data
    wire has_data_0 = (rd_wr_ptr_0 != rd_rd_ptr_0);
    wire has_data_1 = (rd_wr_ptr_1 != rd_rd_ptr_1);
    wire has_data_2 = (rd_wr_ptr_2 != rd_rd_ptr_2);
    wire has_data_3 = (rd_wr_ptr_3 != rd_rd_ptr_3);
    wire has_data_4 = (rd_wr_ptr_4 != rd_rd_ptr_4);
    wire has_data_5 = (rd_wr_ptr_5 != rd_rd_ptr_5);
    wire has_data_6 = (rd_wr_ptr_6 != rd_rd_ptr_6);
    wire has_data_7 = (rd_wr_ptr_7 != rd_rd_ptr_7);

    // Write response counter
    reg [7:0] wr_resp_counter;

    //--------------------------------------------------------------------------
    // Random ready generation (using LFSR)
    //--------------------------------------------------------------------------
    reg [15:0] lfsr;

    always @(posedge clk) begin
        if (rst)
            lfsr <= 16'hACE1;
        else
            lfsr <= {lfsr[14:0], lfsr[15] ^ lfsr[13] ^ lfsr[12] ^ lfsr[10]};
    end

    // Ready signals with some randomization
    always @(posedge clk) begin
        if (rst) begin
            arready <= 1'b0;
            awready <= 1'b0;
            wready  <= 1'b0;
        end else begin
            arready <= (lfsr[0] | lfsr[1]);  // ~75% ready
            awready <= (lfsr[2] | lfsr[3]);
            wready  <= (lfsr[4] | lfsr[5]);
        end
    end

    //--------------------------------------------------------------------------
    // Write Address Channel Handler
    //--------------------------------------------------------------------------
    always @(posedge clk) begin
        if (rst) begin
            wr_addr_wr_ptr <= 0;
        end else if (awvalid && awready && !wr_addr_full) begin
            wr_addr_fifo[wr_addr_wr_ptr[2:0]] <= awaddr;
            wr_addr_wr_ptr <= wr_addr_wr_ptr + 1;
            $display("%0t slave: write address received: addr=%h", $time, awaddr);
        end
    end

    //--------------------------------------------------------------------------
    // Write Data Channel Handler
    //--------------------------------------------------------------------------
    always @(posedge clk) begin
        if (rst) begin
            wr_data_wr_ptr <= 0;
        end else if (wvalid && wready && !wr_data_full) begin
            wr_data_fifo[wr_data_wr_ptr[2:0]] <= wdata;
            wr_data_wr_ptr <= wr_data_wr_ptr + 1;
            $display("%0t slave: write data received: data=%h", $time, wdata);
        end
    end

    //--------------------------------------------------------------------------
    // Memory Write (when both address and data available)
    //--------------------------------------------------------------------------
    always @(posedge clk) begin
        if (rst) begin
            wr_addr_rd_ptr <= 0;
            wr_data_rd_ptr <= 0;
            wr_resp_counter <= 0;
        end else if (!wr_addr_empty && !wr_data_empty) begin
            memory[wr_addr_fifo[wr_addr_rd_ptr[2:0]][ADDR_BITS-1:0]] <=
                   wr_data_fifo[wr_data_rd_ptr[2:0]];
            $display("%0t slave: write memory[%h] = %h", $time,
                     wr_addr_fifo[wr_addr_rd_ptr[2:0]][ADDR_BITS-1:0],
                     wr_data_fifo[wr_data_rd_ptr[2:0]]);
            wr_addr_rd_ptr <= wr_addr_rd_ptr + 1;
            wr_data_rd_ptr <= wr_data_rd_ptr + 1;
            wr_resp_counter <= wr_resp_counter + 1;
        end
    end

    //--------------------------------------------------------------------------
    // Read Address Channel Handler (separate always blocks per ID)
    //--------------------------------------------------------------------------
    always @(posedge clk) begin
        if (rst) begin
            rd_wr_ptr_0 <= 0; rd_wr_ptr_1 <= 0; rd_wr_ptr_2 <= 0; rd_wr_ptr_3 <= 0;
            rd_wr_ptr_4 <= 0; rd_wr_ptr_5 <= 0; rd_wr_ptr_6 <= 0; rd_wr_ptr_7 <= 0;
        end else if (arvalid && arready) begin
            $display("%0t slave: read address received: addr=%h id=%0d data=%h",
                     $time, araddr, arid, memory[araddr[ADDR_BITS-1:0]]);
            case (arid[2:0])
                3'd0: begin rd_data_fifo_0[rd_wr_ptr_0[2:0]] <= memory[araddr[ADDR_BITS-1:0]]; rd_wr_ptr_0 <= rd_wr_ptr_0 + 1; end
                3'd1: begin rd_data_fifo_1[rd_wr_ptr_1[2:0]] <= memory[araddr[ADDR_BITS-1:0]]; rd_wr_ptr_1 <= rd_wr_ptr_1 + 1; end
                3'd2: begin rd_data_fifo_2[rd_wr_ptr_2[2:0]] <= memory[araddr[ADDR_BITS-1:0]]; rd_wr_ptr_2 <= rd_wr_ptr_2 + 1; end
                3'd3: begin rd_data_fifo_3[rd_wr_ptr_3[2:0]] <= memory[araddr[ADDR_BITS-1:0]]; rd_wr_ptr_3 <= rd_wr_ptr_3 + 1; end
                3'd4: begin rd_data_fifo_4[rd_wr_ptr_4[2:0]] <= memory[araddr[ADDR_BITS-1:0]]; rd_wr_ptr_4 <= rd_wr_ptr_4 + 1; end
                3'd5: begin rd_data_fifo_5[rd_wr_ptr_5[2:0]] <= memory[araddr[ADDR_BITS-1:0]]; rd_wr_ptr_5 <= rd_wr_ptr_5 + 1; end
                3'd6: begin rd_data_fifo_6[rd_wr_ptr_6[2:0]] <= memory[araddr[ADDR_BITS-1:0]]; rd_wr_ptr_6 <= rd_wr_ptr_6 + 1; end
                3'd7: begin rd_data_fifo_7[rd_wr_ptr_7[2:0]] <= memory[araddr[ADDR_BITS-1:0]]; rd_wr_ptr_7 <= rd_wr_ptr_7 + 1; end
            endcase
        end
    end

    //--------------------------------------------------------------------------
    // Read Response Channel (Out-of-Order based on ID)
    // Use combinational logic to select ID, sequential to update
    //--------------------------------------------------------------------------
    reg [2:0] selected_id;
    reg       found_data;
    reg [DATA_WIDTH-1:0] selected_data;

    // Combinational: find an ID with pending data (random starting point)
    always @(*) begin
        found_data = 0;
        selected_id = 0;
        selected_data = 0;

        // Check IDs in pseudo-random order based on LFSR
        case (lfsr[2:0])
            3'd0: begin
                if      (has_data_0) begin selected_id = 0; selected_data = rd_data_fifo_0[rd_rd_ptr_0[2:0]]; found_data = 1; end
                else if (has_data_1) begin selected_id = 1; selected_data = rd_data_fifo_1[rd_rd_ptr_1[2:0]]; found_data = 1; end
                else if (has_data_2) begin selected_id = 2; selected_data = rd_data_fifo_2[rd_rd_ptr_2[2:0]]; found_data = 1; end
                else if (has_data_3) begin selected_id = 3; selected_data = rd_data_fifo_3[rd_rd_ptr_3[2:0]]; found_data = 1; end
                else if (has_data_4) begin selected_id = 4; selected_data = rd_data_fifo_4[rd_rd_ptr_4[2:0]]; found_data = 1; end
                else if (has_data_5) begin selected_id = 5; selected_data = rd_data_fifo_5[rd_rd_ptr_5[2:0]]; found_data = 1; end
                else if (has_data_6) begin selected_id = 6; selected_data = rd_data_fifo_6[rd_rd_ptr_6[2:0]]; found_data = 1; end
                else if (has_data_7) begin selected_id = 7; selected_data = rd_data_fifo_7[rd_rd_ptr_7[2:0]]; found_data = 1; end
            end
            3'd1: begin
                if      (has_data_3) begin selected_id = 3; selected_data = rd_data_fifo_3[rd_rd_ptr_3[2:0]]; found_data = 1; end
                else if (has_data_5) begin selected_id = 5; selected_data = rd_data_fifo_5[rd_rd_ptr_5[2:0]]; found_data = 1; end
                else if (has_data_1) begin selected_id = 1; selected_data = rd_data_fifo_1[rd_rd_ptr_1[2:0]]; found_data = 1; end
                else if (has_data_7) begin selected_id = 7; selected_data = rd_data_fifo_7[rd_rd_ptr_7[2:0]]; found_data = 1; end
                else if (has_data_0) begin selected_id = 0; selected_data = rd_data_fifo_0[rd_rd_ptr_0[2:0]]; found_data = 1; end
                else if (has_data_2) begin selected_id = 2; selected_data = rd_data_fifo_2[rd_rd_ptr_2[2:0]]; found_data = 1; end
                else if (has_data_4) begin selected_id = 4; selected_data = rd_data_fifo_4[rd_rd_ptr_4[2:0]]; found_data = 1; end
                else if (has_data_6) begin selected_id = 6; selected_data = rd_data_fifo_6[rd_rd_ptr_6[2:0]]; found_data = 1; end
            end
            3'd2: begin
                if      (has_data_5) begin selected_id = 5; selected_data = rd_data_fifo_5[rd_rd_ptr_5[2:0]]; found_data = 1; end
                else if (has_data_2) begin selected_id = 2; selected_data = rd_data_fifo_2[rd_rd_ptr_2[2:0]]; found_data = 1; end
                else if (has_data_7) begin selected_id = 7; selected_data = rd_data_fifo_7[rd_rd_ptr_7[2:0]]; found_data = 1; end
                else if (has_data_0) begin selected_id = 0; selected_data = rd_data_fifo_0[rd_rd_ptr_0[2:0]]; found_data = 1; end
                else if (has_data_3) begin selected_id = 3; selected_data = rd_data_fifo_3[rd_rd_ptr_3[2:0]]; found_data = 1; end
                else if (has_data_1) begin selected_id = 1; selected_data = rd_data_fifo_1[rd_rd_ptr_1[2:0]]; found_data = 1; end
                else if (has_data_4) begin selected_id = 4; selected_data = rd_data_fifo_4[rd_rd_ptr_4[2:0]]; found_data = 1; end
                else if (has_data_6) begin selected_id = 6; selected_data = rd_data_fifo_6[rd_rd_ptr_6[2:0]]; found_data = 1; end
            end
            3'd3: begin
                if      (has_data_7) begin selected_id = 7; selected_data = rd_data_fifo_7[rd_rd_ptr_7[2:0]]; found_data = 1; end
                else if (has_data_4) begin selected_id = 4; selected_data = rd_data_fifo_4[rd_rd_ptr_4[2:0]]; found_data = 1; end
                else if (has_data_1) begin selected_id = 1; selected_data = rd_data_fifo_1[rd_rd_ptr_1[2:0]]; found_data = 1; end
                else if (has_data_6) begin selected_id = 6; selected_data = rd_data_fifo_6[rd_rd_ptr_6[2:0]]; found_data = 1; end
                else if (has_data_3) begin selected_id = 3; selected_data = rd_data_fifo_3[rd_rd_ptr_3[2:0]]; found_data = 1; end
                else if (has_data_0) begin selected_id = 0; selected_data = rd_data_fifo_0[rd_rd_ptr_0[2:0]]; found_data = 1; end
                else if (has_data_5) begin selected_id = 5; selected_data = rd_data_fifo_5[rd_rd_ptr_5[2:0]]; found_data = 1; end
                else if (has_data_2) begin selected_id = 2; selected_data = rd_data_fifo_2[rd_rd_ptr_2[2:0]]; found_data = 1; end
            end
            3'd4: begin
                if      (has_data_2) begin selected_id = 2; selected_data = rd_data_fifo_2[rd_rd_ptr_2[2:0]]; found_data = 1; end
                else if (has_data_6) begin selected_id = 6; selected_data = rd_data_fifo_6[rd_rd_ptr_6[2:0]]; found_data = 1; end
                else if (has_data_4) begin selected_id = 4; selected_data = rd_data_fifo_4[rd_rd_ptr_4[2:0]]; found_data = 1; end
                else if (has_data_0) begin selected_id = 0; selected_data = rd_data_fifo_0[rd_rd_ptr_0[2:0]]; found_data = 1; end
                else if (has_data_1) begin selected_id = 1; selected_data = rd_data_fifo_1[rd_rd_ptr_1[2:0]]; found_data = 1; end
                else if (has_data_3) begin selected_id = 3; selected_data = rd_data_fifo_3[rd_rd_ptr_3[2:0]]; found_data = 1; end
                else if (has_data_5) begin selected_id = 5; selected_data = rd_data_fifo_5[rd_rd_ptr_5[2:0]]; found_data = 1; end
                else if (has_data_7) begin selected_id = 7; selected_data = rd_data_fifo_7[rd_rd_ptr_7[2:0]]; found_data = 1; end
            end
            3'd5: begin
                if      (has_data_4) begin selected_id = 4; selected_data = rd_data_fifo_4[rd_rd_ptr_4[2:0]]; found_data = 1; end
                else if (has_data_1) begin selected_id = 1; selected_data = rd_data_fifo_1[rd_rd_ptr_1[2:0]]; found_data = 1; end
                else if (has_data_6) begin selected_id = 6; selected_data = rd_data_fifo_6[rd_rd_ptr_6[2:0]]; found_data = 1; end
                else if (has_data_3) begin selected_id = 3; selected_data = rd_data_fifo_3[rd_rd_ptr_3[2:0]]; found_data = 1; end
                else if (has_data_0) begin selected_id = 0; selected_data = rd_data_fifo_0[rd_rd_ptr_0[2:0]]; found_data = 1; end
                else if (has_data_7) begin selected_id = 7; selected_data = rd_data_fifo_7[rd_rd_ptr_7[2:0]]; found_data = 1; end
                else if (has_data_2) begin selected_id = 2; selected_data = rd_data_fifo_2[rd_rd_ptr_2[2:0]]; found_data = 1; end
                else if (has_data_5) begin selected_id = 5; selected_data = rd_data_fifo_5[rd_rd_ptr_5[2:0]]; found_data = 1; end
            end
            3'd6: begin
                if      (has_data_6) begin selected_id = 6; selected_data = rd_data_fifo_6[rd_rd_ptr_6[2:0]]; found_data = 1; end
                else if (has_data_0) begin selected_id = 0; selected_data = rd_data_fifo_0[rd_rd_ptr_0[2:0]]; found_data = 1; end
                else if (has_data_3) begin selected_id = 3; selected_data = rd_data_fifo_3[rd_rd_ptr_3[2:0]]; found_data = 1; end
                else if (has_data_5) begin selected_id = 5; selected_data = rd_data_fifo_5[rd_rd_ptr_5[2:0]]; found_data = 1; end
                else if (has_data_2) begin selected_id = 2; selected_data = rd_data_fifo_2[rd_rd_ptr_2[2:0]]; found_data = 1; end
                else if (has_data_7) begin selected_id = 7; selected_data = rd_data_fifo_7[rd_rd_ptr_7[2:0]]; found_data = 1; end
                else if (has_data_4) begin selected_id = 4; selected_data = rd_data_fifo_4[rd_rd_ptr_4[2:0]]; found_data = 1; end
                else if (has_data_1) begin selected_id = 1; selected_data = rd_data_fifo_1[rd_rd_ptr_1[2:0]]; found_data = 1; end
            end
            3'd7: begin
                if      (has_data_1) begin selected_id = 1; selected_data = rd_data_fifo_1[rd_rd_ptr_1[2:0]]; found_data = 1; end
                else if (has_data_7) begin selected_id = 7; selected_data = rd_data_fifo_7[rd_rd_ptr_7[2:0]]; found_data = 1; end
                else if (has_data_5) begin selected_id = 5; selected_data = rd_data_fifo_5[rd_rd_ptr_5[2:0]]; found_data = 1; end
                else if (has_data_2) begin selected_id = 2; selected_data = rd_data_fifo_2[rd_rd_ptr_2[2:0]]; found_data = 1; end
                else if (has_data_4) begin selected_id = 4; selected_data = rd_data_fifo_4[rd_rd_ptr_4[2:0]]; found_data = 1; end
                else if (has_data_6) begin selected_id = 6; selected_data = rd_data_fifo_6[rd_rd_ptr_6[2:0]]; found_data = 1; end
                else if (has_data_0) begin selected_id = 0; selected_data = rd_data_fifo_0[rd_rd_ptr_0[2:0]]; found_data = 1; end
                else if (has_data_3) begin selected_id = 3; selected_data = rd_data_fifo_3[rd_rd_ptr_3[2:0]]; found_data = 1; end
            end
        endcase
    end

    // Sequential: update read response and pointers
    always @(posedge clk) begin
        if (rst) begin
            rvalid <= 1'b0;
            rdata <= 0;
            rid <= 0;
            rd_rd_ptr_0 <= 0; rd_rd_ptr_1 <= 0; rd_rd_ptr_2 <= 0; rd_rd_ptr_3 <= 0;
            rd_rd_ptr_4 <= 0; rd_rd_ptr_5 <= 0; rd_rd_ptr_6 <= 0; rd_rd_ptr_7 <= 0;
        end else if (!rvalid || rready) begin
            if (found_data) begin
                rdata <= selected_data;
                rid <= {1'b0, selected_id};
                rvalid <= 1'b1;
                $display("%0t slave: read response sent: id=%0d data=%h", $time, selected_id, selected_data);

                // Update the appropriate read pointer
                case (selected_id)
                    3'd0: rd_rd_ptr_0 <= rd_rd_ptr_0 + 1;
                    3'd1: rd_rd_ptr_1 <= rd_rd_ptr_1 + 1;
                    3'd2: rd_rd_ptr_2 <= rd_rd_ptr_2 + 1;
                    3'd3: rd_rd_ptr_3 <= rd_rd_ptr_3 + 1;
                    3'd4: rd_rd_ptr_4 <= rd_rd_ptr_4 + 1;
                    3'd5: rd_rd_ptr_5 <= rd_rd_ptr_5 + 1;
                    3'd6: rd_rd_ptr_6 <= rd_rd_ptr_6 + 1;
                    3'd7: rd_rd_ptr_7 <= rd_rd_ptr_7 + 1;
                endcase
            end else begin
                rvalid <= 1'b0;
            end
        end
    end

    //--------------------------------------------------------------------------
    // Write Response Channel
    // Note: Removed strict lfsr[7] requirement to prevent hangs.
    // Now uses lfsr for slight delay variation but always responds.
    //--------------------------------------------------------------------------
    reg [2:0] resp_delay_cnt;

    always @(posedge clk) begin
        if (rst) begin
            bvalid <= 1'b0;
            resp_delay_cnt <= 0;
        end else if (!bvalid || bready) begin
            if (wr_resp_counter > 0) begin
                // Small random delay (0-3 cycles) then send response
                if (resp_delay_cnt == 0) begin
                    resp_delay_cnt <= lfsr[1:0];  // 0-3 cycle delay
                end else if (resp_delay_cnt == 1) begin
                    bvalid <= 1'b1;
                    wr_resp_counter <= wr_resp_counter - 1;
                    resp_delay_cnt <= 0;
                    $display("%0t slave: write response sent", $time);
                end else begin
                    resp_delay_cnt <= resp_delay_cnt - 1;
                    bvalid <= 1'b0;
                end
            end else begin
                bvalid <= 1'b0;
                resp_delay_cnt <= 0;
            end
        end
    end

    //--------------------------------------------------------------------------
    // Memory initialization
    //--------------------------------------------------------------------------
    integer j;
    initial begin
        for (j = 0; j < MEM_DEPTH; j = j + 1)
            memory[j] = 0;
    end

endmodule
