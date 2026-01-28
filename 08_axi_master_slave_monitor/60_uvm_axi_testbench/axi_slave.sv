//----------------------------------------------------------------------------
//  AXI Reference Slave (DUT)
//
//  Reference slave model with memory implementation
//  Supports out-of-order read responses based on ID
//  (Copied from original non-UVM example for use as DUT)
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

  //--------------------------------------------------------------------------
  // Ready signal and response cycle randomization
  //--------------------------------------------------------------------------

  logic [6:0] read_address_ready_probability;
  logic [6:0] write_address_ready_probability;
  logic [6:0] write_data_ready_probability;
  logic [6:0] read_response_probability;
  logic [6:0] write_response_probability;

  always_ff @(posedge clk) begin
    arready <= ($urandom_range(0, 99) < read_address_ready_probability);
    awready <= ($urandom_range(0, 99) < write_address_ready_probability);
    wready  <= ($urandom_range(0, 99) < write_data_ready_probability);
  end

  initial begin
    read_address_ready_probability  = 100;
    write_address_ready_probability = 100;
    write_data_ready_probability    = 100;
    read_response_probability       = 100;
    write_response_probability      = 100;
  end

  //--------------------------------------------------------------------------
  // Queues, counters and memories
  //--------------------------------------------------------------------------

  logic [ADDR_WIDTH-1:0] wr_addr_queue[$];
  logic [DATA_WIDTH-1:0] wr_data_queue[$];

  logic [DATA_WIDTH-1:0] rd_data_array[N_IDS][$];
  int unsigned wr_resp_counter;

  logic [DATA_WIDTH-1:0] memory[logic [ADDR_WIDTH-1:0]];  // Sparse array

  //--------------------------------------------------------------------------
  // Memory dump task
  //--------------------------------------------------------------------------

  task automatic dump_memory();
    $display("slave: memory dump");
    foreach (memory[addr])
      $display("%h: %h", addr, memory[addr]);
    $display("slave: end of memory dump");
  endtask

  //--------------------------------------------------------------------------
  // Main processing
  //--------------------------------------------------------------------------

  always_ff @(posedge clk) begin
    if (rst) begin
      // Clearing the queues, counters and memory
      wr_addr_queue.delete();
      wr_data_queue.delete();

      for (int i = 0; i < N_IDS; i++)
        rd_data_array[i].delete();

      wr_resp_counter = 0;
      memory.delete();

      // Control signal reset
      rvalid <= 0;
      bvalid <= 0;
    end
    else begin
      //----------------------------------------------------------------------
      // Checking the input channels from the master
      // Together with memory operations
      //----------------------------------------------------------------------

      if (arvalid & arready) begin
        if (!memory.exists(araddr)) begin
          $display("slave: attempt to read from memory location %h which was not written",
                   araddr);
          rd_data_array[arid].push_back('x);
        end
        else begin
          $display("slave: read memory [%h] = %h", araddr, memory[araddr]);
          rd_data_array[arid].push_back(memory[araddr]);
        end
      end

      if (awvalid & awready)
        wr_addr_queue.push_back(awaddr);

      if (wvalid & wready)
        wr_data_queue.push_back(wdata);

      if (wr_addr_queue.size() > 0 && wr_data_queue.size() > 0) begin
        $display("slave: write memory [%h] = %h",
                 wr_addr_queue[0], wr_data_queue[0]);

        memory[wr_addr_queue.pop_front()] = wr_data_queue.pop_front();
        wr_resp_counter++;
      end

      //----------------------------------------------------------------------
      // Generating the response
      //----------------------------------------------------------------------

      if (~rvalid | rready) begin
        rdata  <= 'x;
        rid    <= 'x;
        rvalid <= 0;

        if ($urandom_range(0, 99) < read_response_probability) begin
          int random_offset;
          random_offset = $urandom_range(0, N_IDS - 1);

          for (int i = 0; i < N_IDS; i++) begin
            int id_idx;
            id_idx = (i + random_offset) % N_IDS;

            if (rd_data_array[id_idx].size() > 0) begin
              rdata  <= rd_data_array[id_idx].pop_front();
              rid    <= id_idx[ID_WIDTH-1:0];
              rvalid <= 1;
              break;
            end
          end
        end
      end

      if (~bvalid | bready) begin
        bvalid <= 0;

        if (wr_resp_counter > 0 &&
            $urandom_range(0, 99) < write_response_probability) begin
          bvalid <= 1;
          wr_resp_counter--;
        end
      end
    end
  end

endmodule
