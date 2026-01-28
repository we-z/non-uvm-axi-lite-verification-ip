//============================================================================
// EDA Playground - Design Pane (Left Side)
// AXI Interface and Reference Slave
//============================================================================

//----------------------------------------------------------------------------
// AXI-Lite Interface
//----------------------------------------------------------------------------
interface axi_if #(
  parameter int ADDR_WIDTH = 32,
  parameter int DATA_WIDTH = 32,
  parameter int ID_WIDTH   = 4
)(
  input logic clk,
  input logic rst
);

  // Read Address Channel (AR)
  logic [ADDR_WIDTH-1:0] araddr;
  logic [ID_WIDTH-1:0]   arid;
  logic                  arvalid;
  logic                  arready;

  // Write Address Channel (AW)
  logic [ADDR_WIDTH-1:0] awaddr;
  logic                  awvalid;
  logic                  awready;

  // Write Data Channel (W)
  logic [DATA_WIDTH-1:0] wdata;
  logic                  wvalid;
  logic                  wready;

  // Read Data Channel (R)
  logic [DATA_WIDTH-1:0] rdata;
  logic [ID_WIDTH-1:0]   rid;
  logic                  rvalid;
  logic                  rready;

  // Write Response Channel (B)
  logic                  bvalid;
  logic                  bready;

  // Clocking Blocks
  clocking drv_cb @(posedge clk);
    default input #1step output #1;
    output araddr, arid, arvalid;
    output awaddr, awvalid;
    output wdata, wvalid;
    output rready, bready;
    input arready, awready, wready;
    input rdata, rid, rvalid, bvalid;
  endclocking

  clocking mon_cb @(posedge clk);
    default input #1step;
    input araddr, arid, arvalid, arready;
    input awaddr, awvalid, awready;
    input wdata, wvalid, wready;
    input rdata, rid, rvalid, rready;
    input bvalid, bready;
  endclocking

  modport driver  (clocking drv_cb, input clk, rst);
  modport monitor (clocking mon_cb, input clk, rst);

endinterface

//----------------------------------------------------------------------------
// AXI Reference Slave (DUT)
//----------------------------------------------------------------------------
module axi_slave #(
  parameter int ADDR_WIDTH = 32,
  parameter int DATA_WIDTH = 32,
  parameter int ID_WIDTH   = 4
)(
  input  logic                   clk,
  input  logic                   rst,
  input  logic [ADDR_WIDTH-1:0]  araddr,
  input  logic [ID_WIDTH-1:0]    arid,
  input  logic                   arvalid,
  output logic                   arready,
  input  logic [ADDR_WIDTH-1:0]  awaddr,
  input  logic                   awvalid,
  output logic                   awready,
  input  logic [DATA_WIDTH-1:0]  wdata,
  input  logic                   wvalid,
  output logic                   wready,
  output logic [DATA_WIDTH-1:0]  rdata,
  output logic [ID_WIDTH-1:0]    rid,
  output logic                   rvalid,
  input  logic                   rready,
  output logic                   bvalid,
  input  logic                   bready
);

  localparam int N_IDS = 1 << ID_WIDTH;

  // Ready probabilities
  logic [6:0] read_address_ready_probability = 100;
  logic [6:0] write_address_ready_probability = 100;
  logic [6:0] write_data_ready_probability = 100;
  logic [6:0] read_response_probability = 100;
  logic [6:0] write_response_probability = 100;

  always_ff @(posedge clk) begin
    arready <= ($urandom_range(0, 99) < read_address_ready_probability);
    awready <= ($urandom_range(0, 99) < write_address_ready_probability);
    wready  <= ($urandom_range(0, 99) < write_data_ready_probability);
  end

  // Queues and memory
  logic [ADDR_WIDTH-1:0] wr_addr_queue[$];
  logic [DATA_WIDTH-1:0] wr_data_queue[$];
  logic [DATA_WIDTH-1:0] rd_data_array[N_IDS][$];
  int unsigned wr_resp_counter;
  logic [DATA_WIDTH-1:0] memory[logic [ADDR_WIDTH-1:0]];

  always_ff @(posedge clk) begin
    if (rst) begin
      wr_addr_queue.delete();
      wr_data_queue.delete();
      for (int i = 0; i < N_IDS; i++) rd_data_array[i].delete();
      wr_resp_counter = 0;
      memory.delete();
      rvalid <= 0;
      bvalid <= 0;
    end
    else begin
      // Read address handling
      if (arvalid & arready) begin
        if (!memory.exists(araddr)) begin
          $display("%0t slave: read from unwritten addr %h", $time, araddr);
          rd_data_array[arid].push_back('x);
        end else begin
          $display("%0t slave: read memory[%h] = %h", $time, araddr, memory[araddr]);
          rd_data_array[arid].push_back(memory[araddr]);
        end
      end

      // Write handling
      if (awvalid & awready) wr_addr_queue.push_back(awaddr);
      if (wvalid & wready) wr_data_queue.push_back(wdata);

      if (wr_addr_queue.size() > 0 && wr_data_queue.size() > 0) begin
        $display("%0t slave: write memory[%h] = %h", $time, wr_addr_queue[0], wr_data_queue[0]);
        memory[wr_addr_queue.pop_front()] = wr_data_queue.pop_front();
        wr_resp_counter++;
      end

      // Read response (out-of-order based on random ID selection)
      if (~rvalid | rready) begin
        rdata  <= 'x;
        rid    <= 'x;
        rvalid <= 0;
        if ($urandom_range(0, 99) < read_response_probability) begin
          int random_offset = $urandom_range(0, N_IDS - 1);
          for (int i = 0; i < N_IDS; i++) begin
            int id_idx = (i + random_offset) % N_IDS;
            if (rd_data_array[id_idx].size() > 0) begin
              rdata  <= rd_data_array[id_idx].pop_front();
              rid    <= id_idx[ID_WIDTH-1:0];
              rvalid <= 1;
              break;
            end
          end
        end
      end

      // Write response
      if (~bvalid | bready) begin
        bvalid <= 0;
        if (wr_resp_counter > 0 && $urandom_range(0, 99) < write_response_probability) begin
          bvalid <= 1;
          wr_resp_counter--;
        end
      end
    end
  end

endmodule
