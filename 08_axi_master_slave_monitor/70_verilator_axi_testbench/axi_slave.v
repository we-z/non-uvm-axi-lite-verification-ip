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
    reg [DATA_WIDTH-1:0] rd_data_fifo [0:N_IDS-1][0:FIFO_DEPTH-1];
    reg [3:0] rd_data_wr_ptr [0:N_IDS-1];
    reg [3:0] rd_data_rd_ptr [0:N_IDS-1];

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
    // Read Address Channel Handler
    //--------------------------------------------------------------------------
    integer i;
    always @(posedge clk) begin
        if (rst) begin
            for (i = 0; i < N_IDS; i = i + 1)
                rd_data_wr_ptr[i] <= 0;
        end else if (arvalid && arready) begin
            rd_data_fifo[arid][rd_data_wr_ptr[arid][2:0]] <=
                memory[araddr[ADDR_BITS-1:0]];
            rd_data_wr_ptr[arid] <= rd_data_wr_ptr[arid] + 1;
            $display("%0t slave: read address received: addr=%h id=%0d data=%h",
                     $time, araddr, arid, memory[araddr[ADDR_BITS-1:0]]);
        end
    end

    //--------------------------------------------------------------------------
    // Read Response Channel (Out-of-Order based on ID)
    //--------------------------------------------------------------------------
    reg [ID_WIDTH-1:0] current_id;
    reg found_data;

    always @(posedge clk) begin
        if (rst) begin
            rvalid <= 1'b0;
            rdata <= 0;
            rid <= 0;
            for (i = 0; i < N_IDS; i = i + 1)
                rd_data_rd_ptr[i] <= 0;
        end else if (!rvalid || rready) begin
            rvalid <= 1'b0;
            found_data = 0;

            // Random starting point for out-of-order behavior
            current_id = lfsr[ID_WIDTH-1:0];

            for (i = 0; i < N_IDS && !found_data; i = i + 1) begin
                current_id = (current_id + 1) % N_IDS;
                if (rd_data_wr_ptr[current_id] != rd_data_rd_ptr[current_id]) begin
                    rdata <= rd_data_fifo[current_id][rd_data_rd_ptr[current_id][2:0]];
                    rid <= current_id;
                    rvalid <= 1'b1;
                    rd_data_rd_ptr[current_id] <= rd_data_rd_ptr[current_id] + 1;
                    found_data = 1;
                    $display("%0t slave: read response sent: id=%0d data=%h",
                             $time, current_id,
                             rd_data_fifo[current_id][rd_data_rd_ptr[current_id][2:0]]);
                end
            end
        end
    end

    //--------------------------------------------------------------------------
    // Write Response Channel
    //--------------------------------------------------------------------------
    always @(posedge clk) begin
        if (rst) begin
            bvalid <= 1'b0;
        end else if (!bvalid || bready) begin
            if (wr_resp_counter > 0 && lfsr[7]) begin
                bvalid <= 1'b1;
                wr_resp_counter <= wr_resp_counter - 1;
                $display("%0t slave: write response sent", $time);
            end else begin
                bvalid <= 1'b0;
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
