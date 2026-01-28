//----------------------------------------------------------------------------
//  AXI-Lite Interface
//
//  SystemVerilog interface for AXI-Lite protocol signals
//  Includes clocking blocks for driver and monitor
//----------------------------------------------------------------------------

interface axi_if #(
  parameter int ADDR_WIDTH = 32,
  parameter int DATA_WIDTH = 32,
  parameter int ID_WIDTH   = 4
)(
  input logic clk,
  input logic rst
);

  //--------------------------------------------------------------------------
  // AXI Signal Declarations
  //--------------------------------------------------------------------------

  // Read Address Channel (AR)
  logic [ADDR_WIDTH-1:0] araddr;
  logic [ID_WIDTH-1:0]   arid;
  logic                  arvalid;
  logic                  arready;

  // Write Address Channel (AW)
  logic [ADDR_WIDTH-1:0] awaddr;
  logic                  awvalid;
  logic                  awready;

  // Write Data Channel (W)
  logic [DATA_WIDTH-1:0] wdata;
  logic                  wvalid;
  logic                  wready;

  // Read Data Channel (R)
  logic [DATA_WIDTH-1:0] rdata;
  logic [ID_WIDTH-1:0]   rid;
  logic                  rvalid;
  logic                  rready;

  // Write Response Channel (B)
  logic                  bvalid;
  logic                  bready;

  //--------------------------------------------------------------------------
  // Clocking Block for Driver (Master)
  //--------------------------------------------------------------------------

  clocking drv_cb @(posedge clk);
    default input #1step output #1;

    // Outputs (from master)
    output araddr, arid, arvalid;
    output awaddr, awvalid;
    output wdata, wvalid;
    output rready;
    output bready;

    // Inputs (from slave)
    input arready;
    input awready;
    input wready;
    input rdata, rid, rvalid;
    input bvalid;
  endclocking

  //--------------------------------------------------------------------------
  // Clocking Block for Monitor (Passive)
  //--------------------------------------------------------------------------

  clocking mon_cb @(posedge clk);
    default input #1step;

    // All signals as inputs for passive monitoring
    input araddr, arid, arvalid, arready;
    input awaddr, awvalid, awready;
    input wdata, wvalid, wready;
    input rdata, rid, rvalid, rready;
    input bvalid, bready;
  endclocking

  //--------------------------------------------------------------------------
  // Modports
  //--------------------------------------------------------------------------

  modport driver  (clocking drv_cb, input clk, rst);
  modport monitor (clocking mon_cb, input clk, rst);

  modport slave (
    input  clk, rst,
    input  araddr, arid, arvalid,
    output arready,
    input  awaddr, awvalid,
    output awready,
    input  wdata, wvalid,
    output wready,
    output rdata, rid, rvalid,
    input  rready,
    output bvalid,
    input  bready
  );

endinterface
