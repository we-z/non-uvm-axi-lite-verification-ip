//----------------------------------------------------------------------------
//  AXI Agent
//
//  UVM agent containing driver, monitor, and sequencer
//  Can operate in active (with driver) or passive (monitor only) mode
//----------------------------------------------------------------------------

class axi_agent extends uvm_agent;

  `uvm_component_utils(axi_agent)

  //--------------------------------------------------------------------------
  // Components
  //--------------------------------------------------------------------------

  axi_driver     driver;
  axi_monitor    monitor;
  axi_sequencer  sequencer;

  //--------------------------------------------------------------------------
  // Configuration
  //--------------------------------------------------------------------------

  bit is_active = 1;

  //--------------------------------------------------------------------------
  // Constructor
  //--------------------------------------------------------------------------

  function new(string name = "axi_agent", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  //--------------------------------------------------------------------------
  // Build Phase
  //--------------------------------------------------------------------------

  virtual function void build_phase(uvm_phase phase);
    super.build_phase(phase);

    // Always create monitor
    monitor = axi_monitor::type_id::create("monitor", this);

    // Create driver and sequencer only in active mode
    if (is_active) begin
      driver    = axi_driver::type_id::create("driver", this);
      sequencer = axi_sequencer::type_id::create("sequencer", this);
    end
  endfunction

  //--------------------------------------------------------------------------
  // Connect Phase
  //--------------------------------------------------------------------------

  virtual function void connect_phase(uvm_phase phase);
    super.connect_phase(phase);

    // Connect driver to sequencer in active mode
    if (is_active) begin
      driver.seq_item_port.connect(sequencer.seq_item_export);
    end
  endfunction

endclass
