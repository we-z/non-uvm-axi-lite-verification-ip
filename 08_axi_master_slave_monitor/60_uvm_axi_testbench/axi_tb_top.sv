//----------------------------------------------------------------------------
//  AXI UVM Testbench Top Module
//
//  Top-level testbench instantiating:
//  - Clock and reset generation
//  - AXI interface
//  - Reference slave (DUT)
//  - UVM test execution
//----------------------------------------------------------------------------

`timescale 1ns/1ps

module axi_tb_top;

  import uvm_pkg::*;
  `include "uvm_macros.svh"

  import axi_pkg::*;

  //--------------------------------------------------------------------------
  // Parameters
  //--------------------------------------------------------------------------

  parameter int CLK_PERIOD = 100;  // 100ns clock period (10 MHz)

  //--------------------------------------------------------------------------
  // Signals
  //--------------------------------------------------------------------------

  logic clk;
  logic rst;

  //--------------------------------------------------------------------------
  // Clock Generation
  //--------------------------------------------------------------------------

  initial begin
    clk = 1;
    forever #(CLK_PERIOD/2) clk = ~clk;
  end

  //--------------------------------------------------------------------------
  // Reset Generation
  //--------------------------------------------------------------------------

  initial begin
    rst = 1;
    repeat (3) @(posedge clk);
    rst = 0;
  end

  //--------------------------------------------------------------------------
  // AXI Interface
  //--------------------------------------------------------------------------

  axi_if #(
    .ADDR_WIDTH(ADDR_WIDTH),
    .DATA_WIDTH(DATA_WIDTH),
    .ID_WIDTH(ID_WIDTH)
  ) axi_vif (
    .clk(clk),
    .rst(rst)
  );

  //--------------------------------------------------------------------------
  // Reference Slave (DUT)
  //--------------------------------------------------------------------------

  axi_slave #(
    .ADDR_WIDTH(ADDR_WIDTH),
    .DATA_WIDTH(DATA_WIDTH),
    .ID_WIDTH(ID_WIDTH)
  ) dut (
    .clk     (clk),
    .rst     (rst),

    .araddr  (axi_vif.araddr),
    .arid    (axi_vif.arid),
    .arvalid (axi_vif.arvalid),
    .arready (axi_vif.arready),

    .awaddr  (axi_vif.awaddr),
    .awvalid (axi_vif.awvalid),
    .awready (axi_vif.awready),

    .wdata   (axi_vif.wdata),
    .wvalid  (axi_vif.wvalid),
    .wready  (axi_vif.wready),

    .rdata   (axi_vif.rdata),
    .rid     (axi_vif.rid),
    .rvalid  (axi_vif.rvalid),
    .rready  (axi_vif.rready),

    .bvalid  (axi_vif.bvalid),
    .bready  (axi_vif.bready)
  );

  //--------------------------------------------------------------------------
  // UVM Configuration and Test Execution
  //--------------------------------------------------------------------------

  initial begin
    // Set virtual interface in config DB
    uvm_config_db#(virtual axi_if)::set(null, "uvm_test_top.env.agent.*", "vif", axi_vif);

    // Optional: dump waveforms
    // $dumpfile("dump.vcd");
    // $dumpvars;

    // Run the UVM test
    run_test();
  end

  //--------------------------------------------------------------------------
  // Timeout Watchdog
  //--------------------------------------------------------------------------

  initial begin
    #100000;  // 100us timeout
    `uvm_fatal("TIMEOUT", "Simulation timeout - possible hang")
  end

endmodule
