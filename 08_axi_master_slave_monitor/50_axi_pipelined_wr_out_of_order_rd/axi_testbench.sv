//  Simplified AXI (SAXI) Verification IP
//  Written by Yuri Panchul as a baseline example for educational projects

module axi_testbench;

  import axi_transaction::*;

  //--------------------------------------------------------------------------
  // Signals

  logic         clk;
  logic         rst;

  wire  addr_t  araddr;
  wire  id_t    arid;
  wire          arvalid;
  wire          arready;

  wire  addr_t  awaddr;
  wire          awvalid;
  wire          awready;

  wire  data_t  wdata;
  wire          wvalid;
  wire          wready;

  wire  data_t  rdata;
  wire  id_t    rid;
  wire          rvalid;
  wire          rready;

  wire          bvalid;
  wire          bready;

  //--------------------------------------------------------------------------
  // Instantiations

  axi_master  master  (.*);
  axi_slave   slave   (.*);
  axi_monitor monitor (.*);

  //--------------------------------------------------------------------------
  // Driving clock

  initial
  begin
    clk = '1;
    forever # 50 clk = ~ clk;
  end

  //--------------------------------------------------------------------------
  // Reset sequence

  task reset_sequence;

    rst <= '1;
    repeat (3) @ (posedge clk);
    rst <= '0;

  endtask

  //--------------------------------------------------------------------------

  `define complete_everything wait fork;

  //--------------------------------------------------------------------------
  // Tests

  // TODO:
  //
  // Implement the test that issues write transactions.
  // Each transaction should finish
  // before launching the next one.
  // Use master.run_write (<args>).

  // Example: master.run_write ('h100, 'h123);

  task test_non_pipelined_writes ();

    $display ("*** %m ***");

    // START_SOLUTION

    master .run_write ('h100, 'h123);
    master .run_write ('h200, 'h456);
    master .run_write ('h300, 'h789);

    // END_SOLUTION

    slave.dump_memory ();

  endtask

  //--------------------------------------------------------------------------

  // TODO:
  //
  // Implement a sequence of pipelined transactions
  // using master.start_write (<args>).
  //
  // Use $urandom () to generate values for address and data.
  //
  // Use `complete_everything macro at the end of the sequence
  // in order to wait for all forked threads to finish.

  // Example: master.start_write ('h400, 'h123);

  task test_pipelined_writes_back_to_back ();

    $display ("*** %m ***");

    // START_SOLUTION

    master .start_write ( $urandom () , 'h123       );
    master .start_write ( 'h500       , $urandom () );
    master .start_write ( 'h600       , 'h789       );

    `complete_everything

    // END_SOLUTION

    slave.dump_memory ();

  endtask

  //--------------------------------------------------------------------------

  // TODO:
  //
  // Implement a sequence of pipelined write transactions
  // with data transafer delayed relative to the address transfer.
  //
  // Use `complete_everything macro at the end of the sequence
  // in order to wait for all forked threads to finish.
  //
  // An example how to delay data transfer in a transaction:
  // master.start_write ('h700, 'h123, ._data_delay (3));

  task test_write_data_delayed ();

    $display ("*** %m ***");

    // START_SOLUTION

    master .start_write ('h700, 'h123, ._data_delay (3));
    master .start_write ('h800, 'h456, ._data_delay (3));
    master .start_write ('h900, 'h789, ._data_delay (3));

    `complete_everything

    // END_SOLUTION

    slave.dump_memory ();

  endtask

  //--------------------------------------------------------------------------

  // TODO:
  //
  // Implement a sequence of pipelined write transactions
  // with address transfer delayed relative to the data transfer.
  //
  // Use `complete_everything macro at the end of the sequence
  // in order to wait for all forked threads to finish.
  //
  // An example how to delay address transfer in a transaction:
  // master .start_write ('h700, 'h123, ._addr_delay (3));
  //
  // master.start_write ('h700, 'h123, ._addr_delay (3));

  task test_write_addr_delayed ();

    $display ("*** %m ***");

    // START_SOLUTION

    master .start_write ('ha00, 'h123, ._addr_delay (3));
    master .start_write ('hb00, 'h456, ._addr_delay (3));
    master .start_write ('hc00, 'h789, ._addr_delay (3));

    `complete_everything

    // END_SOLUTION

    slave.dump_memory ();

  endtask

  //--------------------------------------------------------------------------

  // TODO:
  //
  // Implement a sequence of non-pipelined reads:
  // each read should start after the previous one finishes.
  //
  // Store the read data into the variables r1, r2, r3, r4, r5.
  // A call example: master.run_read ('h100, r1);

  task test_non_pipelined_reads ();

    data_t r1, r2, r3, r4, r5;

    $display ("*** %m ***");

    // START_SOLUTION

    master .run_read ('h100, r1);
    master .run_read ('h200, r2);
    master .run_read ('h300, r3);
    master .run_read ('h400, r4);
    master .run_read ('h500, r5);

    // END_SOLUTION

    $display ("test: read %h %h %h %h %h", r1, r2, r3, r4, r5);

    slave.dump_memory ();

  endtask

  //--------------------------------------------------------------------------

  // TODO:
  //
  // Implement a sequence of pipelined reads
  // where a read address transfer does not wait
  // for the previous read to finish.
  //
  // Store the read data into the variables r1, r2, r3, r4, r5.
  //
  // Use `complete_everything macro at the end of the sequence
  // in order to wait for all forked threads to finish.
  //
  // The proposed template how to accomplish it:
  //
  //     fork master .run_read ('h100, r1, .in_order (1)); join_none
  // # 1 fork master .run_read ('h200, r2, .in_order (1)); join_none
  // # 1 ...

  task test_non_pipelined_reads_in_order ();

    data_t r1, r2, r3, r4, r5;

    $display ("*** %m ***");

    // START_SOLUTION

        fork master .run_read ('h100, r1, .in_order (1)); join_none
    # 1 fork master .run_read ('h200, r2, .in_order (1)); join_none
    # 1 fork master .run_read ('h300, r3, .in_order (1)); join_none
    # 1 fork master .run_read ('h400, r4, .in_order (1)); join_none
    # 1 fork master .run_read ('h500, r5, .in_order (1)); join_none

    // END_SOLUTION

    `complete_everything

    $display ("test: read %h %h %h %h %h", r1, r2, r3, r4, r5);

    slave.dump_memory ();

  endtask

  //--------------------------------------------------------------------------

  task test_non_pipelined_reads_out_of_order ();

    data_t r1, r2, r3, r4, r5;

    $display ("*** %m ***");

    // Make master stop responding with ready to read response
    master .read_data_ready_probability = 0;

        fork master .run_read ('h100, r1); join_none
    # 1 fork master .run_read ('h200, r2); join_none
    # 1 fork master .run_read ('h300, r3); join_none
    # 1 fork master .run_read ('h400, r4); join_none
    # 1 fork master .run_read ('h500, r5); join_none

    repeat (20) @ (posedge clk);

    // Make master to respond again with ready to read response
    master .read_data_ready_probability = 100;

    `complete_everything

    $display ("test: read %h %h %h %h %h", r1, r2, r3, r4, r5);

    slave.dump_memory ();

  endtask

  //--------------------------------------------------------------------------

  // TODO:
  //
  // Uncomment this test in the main initial block
  // and check how it issues the random AXI4 read and write transactions.

  task test_random ();

    slave  .read_address_ready_probability   = 70;
    slave  .write_address_ready_probability  = 70;
    slave  .write_data_ready_probability     = 70;
    slave  .read_response_probability        = 70;
    slave  .write_response_probability       = 70;

    master .read_data_ready_probability      = 70;
    master .write_response_ready_probability = 70;

    master .run_random (100);
    slave  .dump_memory ();

    master .reset_probabilities ();
    slave  .reset_probabilities ();

    slave.dump_memory ();

  endtask

  //--------------------------------------------------------------------------

  // The main initial block

  initial
  begin
    // $dumpfile("dump.vcd");
    // $dumpvars;

    reset_sequence ();

    fork
      begin
        test_non_pipelined_writes             ();
        test_pipelined_writes_back_to_back    ();
        test_write_data_delayed               ();
        test_write_addr_delayed               ();
        test_non_pipelined_reads              ();
        test_non_pipelined_reads_in_order     ();
        test_non_pipelined_reads_out_of_order ();
        // test_random                           ();
      end

      begin
        repeat (1000)
          @ (posedge clk);

        $display ("Timeout: design hangs");
      end
    join_any

    $finish;
  end

endmodule
