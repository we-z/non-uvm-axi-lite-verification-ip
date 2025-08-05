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
  output logic   rready,

  input          bvalid,
  output logic   bready
);

  import axi_transaction::*;

  //--------------------------------------------------------------------------
  // Ready signal randomization

  logic [6:0] read_data_ready_probability,
              write_response_ready_probability;

  always @ (posedge clk)
  begin
    rready <= ( $urandom_range (0, 99) < read_data_ready_probability      );
    bready <= ( $urandom_range (0, 99) < write_response_ready_probability );
  end

  task reset_probabilities ();

    read_data_ready_probability      = 100;
    write_response_ready_probability = 100;

  endtask

  initial reset_probabilities ();

  //--------------------------------------------------------------------------
  // Queues and scoreboards

  axi_transaction send_queue    [$];
  axi_transaction receive_queue [$];

  axi_transaction rd_addr_queue [$];
  axi_transaction wr_addr_queue [$];
  axi_transaction wr_data_queue [$];

  axi_transaction rd_data_array [n_ids][$];
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

  task automatic start_read
  (
    addr_t  _addr,
    delay_t _addr_delay = 0,
    bit     in_order = 0
  );

    # 1  // This delay is necessary to order the moments
         // of adding the transactions to the send queue

    fork
    begin
      axi_transaction tr;

      tr = new ();

      assert (tr.randomize () with
      {
        op   == read;
        addr == _addr;

        addr_delay == _addr_delay;

        in_order -> id == 0;
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

  task automatic run_read
  (
          addr_t  _addr,
    ref   data_t  _data,
    input delay_t _addr_delay = 0,
          bit     in_order    = 0
  );

    axi_transaction tr;

    tr = new ();

    assert (tr.randomize () with
    {
      op   == read;
      addr == _addr;

      addr_delay == _addr_delay;

      in_order -> id == 0;
    });

    send_queue.push_back (tr);

    do
    begin
      @ (posedge clk);
      # 1 ;
    end
    while (   receive_queue.size () == 0
           || receive_queue [0] != tr);

    _data = tr.data;
    void' (receive_queue.pop_front ());

  endtask

  //--------------------------------------------------------------------------

  task run_random (int n, int _max_delay = 5);

    axi_transaction tr;

    repeat (n)
    begin
      tr = new ();

      assert (tr.randomize () with
      {
        addr_delay <= _max_delay;
        data_delay <= _max_delay;
      });

      send_queue.push_back (tr);
    end

    repeat (n)
    begin
      do
      begin
        @ (posedge clk);
        # 1 ;
      end
      while (receive_queue.size () == 0);

      void' (receive_queue.pop_front ());
    end

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

      rd_addr_queue .delete ();
      wr_addr_queue .delete ();
      wr_data_queue .delete ();

      for (int i = 0; i < n_ids; i ++)
        rd_data_array [i].delete ();

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

      //----------------------------------------------------------------------
      // Checking the responses from the slave

      if (bvalid & bready)
      begin
        if (wr_resp_queue.size () == 0)
        begin
          $display ("ERROR: Unexpected write response");
        end
        else
        begin
          tr = wr_resp_queue.pop_front ();
          $display ("%0d master: received write response: %s", cycle, tr.str ());

          if (~ tr.addr_is_sent)
            $display ("ERROR: Unexpected write response: address was not sent: %s",
              tr.str ());

          if (~ tr.data_is_sent)
            $display ("ERROR: Unexpected write response: data was not sent: %s",
              tr.str ());

          receive_queue.push_back (tr);
        end
      end

      //----------------------------------------------------------------------

      if (rvalid & rready)
      begin
        if (rd_data_array [rid].size () == 0)
        begin
          $display ("ERROR: Unexpected read data");
        end
        else
        begin
          tr = rd_data_array [rid].pop_front ();

          tr.data        = rdata;
          tr.data_is_set = 1;

          $display ("%0d master: received read data: %s", cycle, tr.str ());
          receive_queue.push_back (tr);
        end
      end

      //----------------------------------------------------------------------
      // Checking the output channel transmissions

      if (arvalid & arready)
      begin
        assert (rd_addr_queue.size () > 0);
        tr = rd_addr_queue.pop_front ();

        rd_data_array [tr.id].push_back (tr);

        $display ("%0d master: read address transmitted: %s", cycle, tr.str ());
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

        if (tr.op == read)
        begin
          rd_addr_queue.push_back (tr);
        end
        else
        begin
          wr_addr_queue.push_back (tr);
          wr_data_queue.push_back (tr);
        end
      end

      //----------------------------------------------------------------------
      // Initiating the output channel transmissions

      arvalid <= '0;
      araddr  <= 'x;
      arid    <= 'x;

      if (rd_addr_queue.size () > 0)
      begin
        tr = rd_addr_queue [0];

        if (tr.addr_delay > 0)
        begin
          tr.addr_delay --;
        end
        else
        begin
          arvalid <= '1;
          araddr  <= tr.addr;
          arid    <= tr.id;

          $display ("%0d master: started read address transmittion: %s", cycle, tr.str ());
        end
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
