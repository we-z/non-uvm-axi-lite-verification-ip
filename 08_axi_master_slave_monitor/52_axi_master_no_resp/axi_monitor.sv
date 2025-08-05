//  Simplified AXI (SAXI) Verification IP
//  Written by Yuri Panchul as a baseline example for educational projects

import axi_transaction::*;

module axi_monitor
(
  input         clk,
  input         rst,

  input addr_t  araddr,
  input id_t    arid,
  input         arvalid,
  input         arready,

  input addr_t  awaddr,
  input         awvalid,
  input         awready,

  input data_t  wdata,
  input         wvalid,
  input         wready,

  input data_t  rdata,
  input id_t    rid,
  input         rvalid,
  input         rready,

  input         bvalid,
  input         bready
);

  // TODO: Implement the passive monitor that logs the transactions

endmodule
