//  Simplified AXI (SAXI) Verification IP
//  Written by Yuri Panchul as a baseline example for educational projects

import axi_transaction::*;

module axi_slave
(
  input          clk,
  input          rst,

  input  addr_t  araddr,
  input  id_t    arid,
  input          arvalid,
  output logic   arready,

  input  addr_t  awaddr,
  input          awvalid,
  output logic   awready,

  input  data_t  wdata,
  input          wvalid,
  output logic   wready,

  output data_t  rdata,
  output id_t    rid,
  output logic   rvalid,
  input          rready,

  output logic   bvalid,
  input          bready
);

  import axi_transaction::*;

  //--------------------------------------------------------------------------
  // Ready signal and responce cycle randomization

  logic [6:0] write_address_ready_probability,
              write_data_ready_probability,
              write_response_probability;

  always @ (posedge clk)
  begin
    awready <= ( $urandom_range (0, 99) < write_address_ready_probability  );
    wready  <= ( $urandom_range (0, 99) < write_data_ready_probability     );
  end

  task reset_probabilities ();

    write_address_ready_probability = 100;
    write_data_ready_probability    = 100;
    write_response_probability      = 100;

  endtask

  initial reset_probabilities ();

  //--------------------------------------------------------------------------
  // Queues, counters and memories

  addr_t wr_addr_queue [$];
  data_t wr_data_queue [$];

  int unsigned wr_resp_counter;

  //--------------------------------------------------------------------------
  // Main processing

  always @ (posedge clk)
    if (rst)
    begin
      //----------------------------------------------------------------------
      // Clearing the queues, counters and memory

      wr_addr_queue .delete ();
      wr_data_queue .delete ();

      wr_resp_counter = 0;

      //----------------------------------------------------------------------
      // Control signal reset

      rvalid <= '0;
      bvalid <= '0;
    end
    else
    begin
      //----------------------------------------------------------------------
      // Checking the input channels from the master
      // Together with memory operations

      if (awvalid & awready)
        wr_addr_queue.push_back (awaddr);

      if (wvalid & wready)
        wr_data_queue.push_back (wdata);

      if (  wr_addr_queue.size () > 0
          & wr_data_queue.size () > 0)
      begin
        void'(wr_addr_queue.pop_front ());
        void'(wr_data_queue.pop_front ());
        wr_resp_counter ++;
      end

      //----------------------------------------------------------------------
      // Generating the response

      if (~ bvalid | bready)
      begin
        bvalid <= '0;

        if (   wr_resp_counter > 0
            && $urandom_range (0, 99) < write_response_probability)
        begin
          bvalid <= '1;
          wr_resp_counter --;
        end
    end
  end

endmodule
