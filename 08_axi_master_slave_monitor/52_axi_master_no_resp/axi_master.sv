//  Simplified AXI (SAXI) Verification IP
//  Written by Yuri Panchul as a baseline example for educational projects

import axi_transaction::*;

module axi_master
(
  input          clk,
  input          rst,

  output addr_t  araddr,
  output id_t    arid,
  output logic   arvalid,
  input          arready,

  output addr_t  awaddr,
  output logic   awvalid,
  input          awready,

  output data_t  wdata,
  output logic   wvalid,
  input          wready,

  input  data_t  rdata,
  input  id_t    rid,
  input          rvalid,
  output         rready,

  input          bvalid,
  output         bready
);

  import axi_transaction::*;

  //--------------------------------------------------------------------------
  // Ready signal randomization

  assign rready = 0;   // Read is not supported in this variant of master
  assign bready = 0;   // Write response is not supported in this variant of master

  //--------------------------------------------------------------------------
  // Queues and scoreboards

  axi_transaction send_queue    [$];
  axi_transaction receive_queue [$];

  axi_transaction wr_addr_queue [$];
  axi_transaction wr_data_queue [$];

  axi_transaction wr_resp_queue [$];

  //--------------------------------------------------------------------------
  // User interface

  `define complete_everything wait fork;

  //--------------------------------------------------------------------------

  task automatic start_write
  (
    addr_t  _addr,
    data_t  _data,
    delay_t _addr_delay = 0,
    delay_t _data_delay = 0
  );

    # 1  // This delay is necessary to order the moments
         // of adding the transactions to the send queue

    fork
    begin
      axi_transaction tr;

      tr = new ();

      assert (tr.randomize () with
      {
        op   == write;
        addr == _addr;
        data == _data;

        addr_delay == _addr_delay;
        data_delay == _data_delay;
      });

      send_queue.push_back (tr);

      do
      begin
        @ (posedge clk);
        # 1 ;
      end
      while (   receive_queue.size () == 0
             || receive_queue [0] != tr);

      void' (receive_queue.pop_front ());
    end
    join_none

  endtask

  //--------------------------------------------------------------------------

  task automatic run_write
  (
    addr_t  _addr,
    data_t  _data,
    delay_t _addr_delay = 0,
    delay_t _data_delay = 0
  );

    start_write
    (
      _addr,
      _data,
      _addr_delay,
      _data_delay
    );

    `complete_everything

  endtask

  //--------------------------------------------------------------------------
  // Main processing

  int unsigned cycle;
  axi_transaction tr;

  always @ (posedge clk)
    if (rst)
    begin
      cycle = 0;  // Blocking assignment here is intentional

      //----------------------------------------------------------------------
      // Clearing the queues

      send_queue    .delete ();
      receive_queue .delete ();

      wr_addr_queue .delete ();
      wr_data_queue .delete ();

      wr_resp_queue .delete ();

      //----------------------------------------------------------------------
      // Control signal reset

      arvalid <= '0;
      awvalid <= '0;
      wvalid  <= '0;
    end
    else
    begin
      cycle ++;  // Blocking assignment here is intentional

        if (wr_resp_queue.size () > 0)
        begin
          if (wr_resp_queue[0].addr_is_sent && wr_resp_queue[0].data_is_sent)
            receive_queue.push_back (wr_resp_queue.pop_front ());
        end

      //----------------------------------------------------------------------

      if (awvalid & awready)
      begin
        assert (wr_addr_queue.size () > 0);

        tr = wr_addr_queue.pop_front ();
        tr.addr_is_sent = 1;

        if (~ tr.data_is_sent)
          wr_resp_queue.push_back (tr);

        $display ("%0d master: write address transmitted: %s", cycle, tr.str ());
      end

      //----------------------------------------------------------------------

      if (wvalid & wready)
      begin
        assert (wr_data_queue.size () > 0);

        tr = wr_data_queue.pop_front ();
        tr.data_is_sent = 1;

        if (~ tr.addr_is_sent)
          wr_resp_queue.push_back (tr);

        $display ("%0d master: write data transmitted: %s", cycle, tr.str ());
      end

      //----------------------------------------------------------------------

      # 3  // This delay is for the user to check the receive queue
           // and prepare the new transactions for the send queue
           // based on new data

      //----------------------------------------------------------------------
      // Getting the user transaction

      while (send_queue.size () > 0)
      begin
        tr = send_queue.pop_front ();

        wr_addr_queue.push_back (tr);
        wr_data_queue.push_back (tr);
      end


      //----------------------------------------------------------------------

      awvalid <= '0;
      awaddr  <= 'x;

      if (wr_addr_queue.size () > 0)
      begin
        tr = wr_addr_queue [0];

        if (tr.addr_delay > 0)
        begin
          tr.addr_delay --;
        end
        else
        begin
          awvalid <= '1;
          awaddr  <= tr.addr;

          $display ("%0d master: started write address transmittion: %s", cycle, tr.str ());
        end
      end

      //----------------------------------------------------------------------

      wvalid <= '0;
      wdata  <= 'x;

      if (wr_data_queue.size () > 0)
      begin
        tr = wr_data_queue [0];

        if (tr.data_delay > 0)
        begin
          tr.data_delay --;
        end
        else
        begin
          wvalid <= '1;
          wdata  <= tr.data;

          $display ("%0d master: started write data transmittion: %s", cycle, tr.str ());
        end
      end
    end

endmodule
