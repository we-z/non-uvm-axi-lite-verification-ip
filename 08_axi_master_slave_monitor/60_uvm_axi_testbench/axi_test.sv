//----------------------------------------------------------------------------
//  AXI Test
//
//  UVM test class that configures the environment and starts sequences
//----------------------------------------------------------------------------

class axi_base_test extends uvm_test;

  `uvm_component_utils(axi_base_test)

  //--------------------------------------------------------------------------
  // Components
  //--------------------------------------------------------------------------

  axi_env env;

  //--------------------------------------------------------------------------
  // Constructor
  //--------------------------------------------------------------------------

  function new(string name = "axi_base_test", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  //--------------------------------------------------------------------------
  // Build Phase
  //--------------------------------------------------------------------------

  virtual function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    env = axi_env::type_id::create("env", this);
  endfunction

  //--------------------------------------------------------------------------
  // End of Elaboration Phase
  //--------------------------------------------------------------------------

  virtual function void end_of_elaboration_phase(uvm_phase phase);
    super.end_of_elaboration_phase(phase);
    uvm_top.print_topology();
  endfunction

  //--------------------------------------------------------------------------
  // Report Phase
  //--------------------------------------------------------------------------

  virtual function void report_phase(uvm_phase phase);
    uvm_report_server svr;
    super.report_phase(phase);

    svr = uvm_report_server::get_server();

    if (svr.get_severity_count(UVM_FATAL) + svr.get_severity_count(UVM_ERROR) > 0) begin
      `uvm_info("TEST", "========================================", UVM_LOW)
      `uvm_info("TEST", "           TEST FAILED", UVM_LOW)
      `uvm_info("TEST", "========================================", UVM_LOW)
    end else begin
      `uvm_info("TEST", "========================================", UVM_LOW)
      `uvm_info("TEST", "           TEST PASSED", UVM_LOW)
      `uvm_info("TEST", "========================================", UVM_LOW)
    end
  endfunction

endclass

//============================================================================
// All Tests - Runs Complete Test Suite
//============================================================================

class axi_all_tests extends axi_base_test;

  `uvm_component_utils(axi_all_tests)

  function new(string name = "axi_all_tests", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  virtual task run_phase(uvm_phase phase);
    axi_all_tests_vseq vseq;

    phase.raise_objection(this);

    vseq = axi_all_tests_vseq::type_id::create("vseq");
    vseq.axi_sqr = env.agent.sequencer;
    vseq.start(null);

    // Allow some time for final transactions to complete
    #1000;

    phase.drop_objection(this);
  endtask

endclass

//============================================================================
// Individual Test Classes
//============================================================================

// Non-pipelined writes test
class axi_non_pipelined_writes_test extends axi_base_test;

  `uvm_component_utils(axi_non_pipelined_writes_test)

  function new(string name = "axi_non_pipelined_writes_test", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  virtual task run_phase(uvm_phase phase);
    non_pipelined_writes_seq seq;

    phase.raise_objection(this);
    seq = non_pipelined_writes_seq::type_id::create("seq");
    seq.start(env.agent.sequencer);
    #500;
    phase.drop_objection(this);
  endtask

endclass

// Pipelined writes test
class axi_pipelined_writes_test extends axi_base_test;

  `uvm_component_utils(axi_pipelined_writes_test)

  function new(string name = "axi_pipelined_writes_test", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  virtual task run_phase(uvm_phase phase);
    non_pipelined_writes_seq seq1;
    pipelined_writes_seq seq2;

    phase.raise_objection(this);

    // First do some writes
    seq1 = non_pipelined_writes_seq::type_id::create("seq1");
    seq1.start(env.agent.sequencer);

    // Then pipelined writes
    seq2 = pipelined_writes_seq::type_id::create("seq2");
    seq2.start(env.agent.sequencer);

    #500;
    phase.drop_objection(this);
  endtask

endclass

// Write data delayed test
class axi_write_data_delayed_test extends axi_base_test;

  `uvm_component_utils(axi_write_data_delayed_test)

  function new(string name = "axi_write_data_delayed_test", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  virtual task run_phase(uvm_phase phase);
    write_data_delayed_seq seq;

    phase.raise_objection(this);
    seq = write_data_delayed_seq::type_id::create("seq");
    seq.start(env.agent.sequencer);
    #500;
    phase.drop_objection(this);
  endtask

endclass

// Write address delayed test
class axi_write_addr_delayed_test extends axi_base_test;

  `uvm_component_utils(axi_write_addr_delayed_test)

  function new(string name = "axi_write_addr_delayed_test", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  virtual task run_phase(uvm_phase phase);
    write_addr_delayed_seq seq;

    phase.raise_objection(this);
    seq = write_addr_delayed_seq::type_id::create("seq");
    seq.start(env.agent.sequencer);
    #500;
    phase.drop_objection(this);
  endtask

endclass

// Out-of-order reads test
class axi_out_of_order_reads_test extends axi_base_test;

  `uvm_component_utils(axi_out_of_order_reads_test)

  function new(string name = "axi_out_of_order_reads_test", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  virtual task run_phase(uvm_phase phase);
    non_pipelined_writes_seq seq1;
    pipelined_reads_out_of_order_seq seq2;

    phase.raise_objection(this);

    // First populate memory with writes
    seq1 = non_pipelined_writes_seq::type_id::create("seq1");
    seq1.start(env.agent.sequencer);

    // Then test out-of-order reads
    seq2 = pipelined_reads_out_of_order_seq::type_id::create("seq2");
    seq2.start(env.agent.sequencer);

    #1000;
    phase.drop_objection(this);
  endtask

endclass

// Random test
class axi_random_test extends axi_base_test;

  `uvm_component_utils(axi_random_test)

  function new(string name = "axi_random_test", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  virtual task run_phase(uvm_phase phase);
    random_transactions_seq seq;

    phase.raise_objection(this);
    seq = random_transactions_seq::type_id::create("seq");
    seq.num_transactions = 100;
    seq.start(env.agent.sequencer);
    #2000;
    phase.drop_objection(this);
  endtask

endclass
