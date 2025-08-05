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
        test_non_pipelined_writes();
        test_pipelined_writes_back_to_back();
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
