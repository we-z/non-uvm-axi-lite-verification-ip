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
              write_data_ready_probability;

  always @ (posedge clk)
  begin
    awready <= ( $urandom_range (0, 99) < write_address_ready_probability  );
    wready  <= ( $urandom_range (0, 99) < write_data_ready_probability     );
  end

  assign bvalid = 'b0;

  task reset_probabilities ();

    write_address_ready_probability = 100;
    write_data_ready_probability    = 100;

  endtask

  initial reset_probabilities ();

endmodule
