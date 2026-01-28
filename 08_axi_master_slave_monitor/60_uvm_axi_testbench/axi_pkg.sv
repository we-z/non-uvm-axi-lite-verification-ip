//----------------------------------------------------------------------------
//  UVM AXI-Lite Verification IP
//
//  Converted from non-UVM version by Yuri Panchul
//  UVM implementation demonstrates:
//      1. UVM transaction class (sequence item)
//      2. UVM sequencer
//      3. UVM driver (BFM) with pipelining support
//      4. UVM monitor (passive)
//      5. UVM agent
//      6. UVM environment
//      7. UVM sequences
//      8. Scoreboarding
//      9. Constrained randomization
//
//  Supported AXI features:
//      1. Valid/ready protocol on all channels (AR, AW, W, R, B)
//      2. Single transactions (no bursts)
//      3. In-order pipelining for write transactions
//      4. Out-of-order read response based on read tag/ID
//      5. Different timing of address vs data (addr before data, data before addr)
//      6. Configurable ready signal behavior
//
//----------------------------------------------------------------------------

package axi_pkg;

  import uvm_pkg::*;
  `include "uvm_macros.svh"

  //--------------------------------------------------------------------------
  // Parameters
  //--------------------------------------------------------------------------

  parameter int ADDR_WIDTH  = 32;
  parameter int DATA_WIDTH  = 32;
  parameter int ID_WIDTH    = 4;
  parameter int MAX_DELAY   = 100;

  parameter int N_IDS       = 1 << ID_WIDTH;
  parameter int DELAY_WIDTH = $clog2(MAX_DELAY + 1);

  //--------------------------------------------------------------------------
  // Types
  //--------------------------------------------------------------------------

  typedef enum bit { AXI_READ = 0, AXI_WRITE = 1 } axi_op_t;

  typedef logic [ADDR_WIDTH - 1:0]  addr_t;
  typedef logic [DATA_WIDTH - 1:0]  data_t;
  typedef logic [ID_WIDTH - 1:0]    id_t;
  typedef logic [DELAY_WIDTH - 1:0] delay_t;

  //--------------------------------------------------------------------------
  // Include UVM components
  //--------------------------------------------------------------------------

  `include "axi_seq_item.sv"
  `include "axi_sequencer.sv"
  `include "axi_driver.sv"
  `include "axi_monitor.sv"
  `include "axi_scoreboard.sv"
  `include "axi_agent.sv"
  `include "axi_env.sv"
  `include "axi_sequences.sv"
  `include "axi_test.sv"

endpackage
