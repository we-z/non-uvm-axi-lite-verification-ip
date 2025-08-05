//  Simplified AXI (SAXI) Verification IP
//  Written by Yuri Panchul as a baseline example for educational projects

module axi_testbench;

  import axi_transaction::*;

  // TODO: Extend the 'axi_transaction' class with an additional constraint
  // that restricts data delay to be equal to the address delay.
  //
  // Limit the transaction type to 'write' using another constraint.
  // Name the extended class my_axi_transaction.

  // START_SOLUTION

  class my_axi_transaction extends axi_transaction;

      constraint my_addr_data_delay_c { addr_delay == data_delay; }

      constraint op_c { op == write; }

  endclass

  // END_SOLUTION

  //--------------------------------------------------------------------------
  // Transaction handles

  axi_transaction trans;

  my_axi_transaction my_trans;

  //--------------------------------------------------------------------------
  // Randomization

  initial begin

    // TODO: Create 'trans' and 'my_trans'

    // START_SOLUTION

    trans    = new();
    my_trans = new();

    // END_SOLUTION

    $display("\n\n***Simple randomize\n");

    repeat(10) begin
      void'(trans.randomize());
      $display("%s", trans.str());
    end

    $display("\n\n***Randomize with address inside [0:5]\n");

    // TODO: Randomize 10 transactions
    // using 'randomize () with' construct,
    // with an additional constraint
    // that limits the address field to be inside [0:5].
    // Print each generated transaction.

    // START_SOLUTION

    repeat(10) begin
      void'(trans.randomize() with {addr inside {[0:5]};});
      $display("%s", trans.str());
    end

    // END_SOLUTION

    $display("\n\n***Randomize with extended class\n");
    repeat(10) begin
      void'(my_trans.randomize());
      $display("%s", my_trans.str());
    end

    $finish();
  end

endmodule
