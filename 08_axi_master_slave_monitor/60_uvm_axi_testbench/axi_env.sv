//----------------------------------------------------------------------------
//  AXI Environment
//
//  UVM environment containing agent and scoreboard
//----------------------------------------------------------------------------

class axi_env extends uvm_env;

  `uvm_component_utils(axi_env)

  //--------------------------------------------------------------------------
  // Components
  //--------------------------------------------------------------------------

  axi_agent      agent;
  axi_scoreboard scoreboard;

  //--------------------------------------------------------------------------
  // Constructor
  //--------------------------------------------------------------------------

  function new(string name = "axi_env", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  //--------------------------------------------------------------------------
  // Build Phase
  //--------------------------------------------------------------------------

  virtual function void build_phase(uvm_phase phase);
    super.build_phase(phase);

    agent      = axi_agent::type_id::create("agent", this);
    scoreboard = axi_scoreboard::type_id::create("scoreboard", this);
  endfunction

  //--------------------------------------------------------------------------
  // Connect Phase
  //--------------------------------------------------------------------------

  virtual function void connect_phase(uvm_phase phase);
    super.connect_phase(phase);

    // Connect monitor analysis ports to scoreboard
    agent.monitor.write_ap.connect(scoreboard.write_export);
    agent.monitor.read_ap.connect(scoreboard.read_export);
  endfunction

endclass
