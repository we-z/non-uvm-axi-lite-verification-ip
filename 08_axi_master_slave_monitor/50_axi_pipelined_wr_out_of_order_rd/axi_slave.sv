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

  logic [6:0] read_address_ready_probability,
              write_address_ready_probability,
              write_data_ready_probability,
              read_response_probability,
              write_response_probability;

  always @ (posedge clk)
  begin
    arready <= ( $urandom_range (0, 99) < read_address_ready_probability   );
    awready <= ( $urandom_range (0, 99) < write_address_ready_probability  );
    wready  <= ( $urandom_range (0, 99) < write_data_ready_probability     );
  end

  task reset_probabilities ();

    read_address_ready_probability  = 100;
    write_address_ready_probability = 100;
    write_data_ready_probability    = 100;
    read_response_probability       = 100;
    write_response_probability      = 100;

  endtask

  initial reset_probabilities ();

  //--------------------------------------------------------------------------
  // Queues, counters and memories

  addr_t wr_addr_queue [$];
  data_t wr_data_queue [$];

  data_t rd_data_array [n_ids][$];
  int unsigned wr_resp_counter;

  data_t memory [addr_t];  // A sparse array

  //--------------------------------------------------------------------------
  // User interface

  task automatic dump_memory ();

    $display ("slave: memory dump");

    foreach (memory [addr])
      $display ("%h: %h", addr, memory [addr]);

    $display ("slave: end of memory dump");

  endtask

  //--------------------------------------------------------------------------
  // Main processing

  always @ (posedge clk)
    if (rst)
    begin
      //----------------------------------------------------------------------
      // Clearing the queues, counters and memory

      wr_addr_queue .delete ();
      wr_data_queue .delete ();

      for (int i = 0; i < n_ids; i ++)
        rd_data_array [i].delete ();

      wr_resp_counter = 0;

      memory.delete ();

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

      if (arvalid & arready)
      begin
        if (! memory.exists (araddr))
        begin
          $display ("slave: attempt to read from the memory location %h which was not written",
            araddr);

          rd_data_array [arid].push_back ('x);
        end
        else
        begin
          $display ("slave: read memory [%h] = %h",
            araddr, memory [araddr]);

          rd_data_array [arid].push_back (memory [araddr]);
        end
      end

      if (awvalid & awready)
        wr_addr_queue.push_back (awaddr);

      if (wvalid & wready)
        wr_data_queue.push_back (wdata);

      if (  wr_addr_queue.size () > 0
          & wr_data_queue.size () > 0)
      begin
        $display ("slave: write memory [%h] = %h",
          wr_addr_queue [0], wr_data_queue [0]);

        memory [wr_addr_queue.pop_front ()]
              = wr_data_queue.pop_front ();

        wr_resp_counter ++;
      end

      //----------------------------------------------------------------------
      // Generating the response

      if (~ rvalid | rready)
      begin
        rdata  <= 'x;
        rid    <= 'x;
        rvalid <= '0;

        if ($urandom_range (0, 99) < read_response_probability)
        begin
          int random_offset;
          random_offset = $urandom_range (0, n_ids - 1);

          for (int i = 0; i < n_ids; i ++)
          begin
            int id;
            id = (i + random_offset) % n_ids;

            if (rd_data_array [id].size () > 0)
            begin
              rdata  <= rd_data_array [id].pop_front ();
              rid    <= id;
              rvalid <= '1;

              break;
            end
          end
        end
      end

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
