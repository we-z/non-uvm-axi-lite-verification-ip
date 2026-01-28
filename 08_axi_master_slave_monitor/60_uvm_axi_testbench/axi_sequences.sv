//----------------------------------------------------------------------------
//  AXI Sequences
//
//  UVM sequences covering all test scenarios:
//  1. Non-pipelined writes
//  2. Pipelined writes (back-to-back)
//  3. Write data delayed (address before data)
//  4. Write address delayed (data before address)
//  5. Non-pipelined reads
//  6. Pipelined reads (in-order)
//  7. Pipelined reads (out-of-order)
//  8. Random transactions
//----------------------------------------------------------------------------

//============================================================================
// Base Sequence
//============================================================================

class axi_base_sequence extends uvm_sequence #(axi_seq_item);

  `uvm_object_utils(axi_base_sequence)

  function new(string name = "axi_base_sequence");
    super.new(name);
  endfunction

  // Helper task to create and send a write transaction
  virtual task send_write(addr_t addr, data_t data,
                          delay_t addr_delay = 0, delay_t data_delay = 0);
    axi_seq_item item;

    item = axi_seq_item::type_id::create("write_item");
    start_item(item);

    if (!item.randomize() with {
      op         == AXI_WRITE;
      item.addr  == addr;
      item.data  == data;
      item.addr_delay == addr_delay;
      item.data_delay == data_delay;
    }) begin
      `uvm_error("SEQ", "Randomization failed for write transaction")
    end

    finish_item(item);
  endtask

  // Helper task to create and send a read transaction
  virtual task send_read(addr_t addr, delay_t addr_delay = 0, bit in_order = 0);
    axi_seq_item item;

    item = axi_seq_item::type_id::create("read_item");
    start_item(item);

    if (!item.randomize() with {
      op         == AXI_READ;
      item.addr  == addr;
      item.addr_delay == addr_delay;
      item.in_order   == in_order;
    }) begin
      `uvm_error("SEQ", "Randomization failed for read transaction")
    end

    finish_item(item);
  endtask

endclass

//============================================================================
// Test 1: Non-Pipelined Writes Sequence
//============================================================================

class non_pipelined_writes_seq extends axi_base_sequence;

  `uvm_object_utils(non_pipelined_writes_seq)

  function new(string name = "non_pipelined_writes_seq");
    super.new(name);
  endfunction

  virtual task body();
    `uvm_info("SEQ", "*** Non-Pipelined Writes ***", UVM_LOW)

    // Sequential write operations (each completes before next)
    send_write('h100, 'h123);
    send_write('h200, 'h456);
    send_write('h300, 'h789);

    `uvm_info("SEQ", "Non-pipelined writes complete", UVM_LOW)
  endtask

endclass

//============================================================================
// Test 2: Pipelined Writes Back-to-Back Sequence
//============================================================================

class pipelined_writes_seq extends axi_base_sequence;

  `uvm_object_utils(pipelined_writes_seq)

  function new(string name = "pipelined_writes_seq");
    super.new(name);
  endfunction

  virtual task body();
    axi_seq_item items[$];
    axi_seq_item item;

    `uvm_info("SEQ", "*** Pipelined Writes Back-to-Back ***", UVM_LOW)

    // Create multiple items and send them in parallel
    for (int i = 0; i < 3; i++) begin
      item = axi_seq_item::type_id::create($sformatf("wr_item_%0d", i));
      items.push_back(item);
    end

    // Start all items - they will be pipelined by the driver
    fork
      begin
        start_item(items[0]);
        if (!items[0].randomize() with {
          op   == AXI_WRITE;
          addr == 32'h400;
          data == 32'h123;
          addr_delay == 0;
          data_delay == 0;
        }) `uvm_error("SEQ", "Randomization failed")
        finish_item(items[0]);
      end
      begin
        start_item(items[1]);
        if (!items[1].randomize() with {
          op   == AXI_WRITE;
          addr == 32'h500;
          data == 32'hABC;
          addr_delay == 0;
          data_delay == 0;
        }) `uvm_error("SEQ", "Randomization failed")
        finish_item(items[1]);
      end
      begin
        start_item(items[2]);
        if (!items[2].randomize() with {
          op   == AXI_WRITE;
          addr == 32'h600;
          data == 32'h789;
          addr_delay == 0;
          data_delay == 0;
        }) `uvm_error("SEQ", "Randomization failed")
        finish_item(items[2]);
      end
    join

    `uvm_info("SEQ", "Pipelined writes complete", UVM_LOW)
  endtask

endclass

//============================================================================
// Test 3: Write Data Delayed Sequence (Address Before Data)
//============================================================================

class write_data_delayed_seq extends axi_base_sequence;

  `uvm_object_utils(write_data_delayed_seq)

  function new(string name = "write_data_delayed_seq");
    super.new(name);
  endfunction

  virtual task body();
    axi_seq_item items[$];
    axi_seq_item item;

    `uvm_info("SEQ", "*** Write Data Delayed (Multiple Addresses Before Data) ***", UVM_LOW)

    // Create items with data delayed relative to address
    for (int i = 0; i < 3; i++) begin
      item = axi_seq_item::type_id::create($sformatf("wr_item_%0d", i));
      items.push_back(item);
    end

    fork
      begin
        start_item(items[0]);
        if (!items[0].randomize() with {
          op         == AXI_WRITE;
          addr       == 32'h700;
          data       == 32'h123;
          addr_delay == 0;
          data_delay == 3;  // Data comes 3 cycles after address
        }) `uvm_error("SEQ", "Randomization failed")
        finish_item(items[0]);
      end
      begin
        start_item(items[1]);
        if (!items[1].randomize() with {
          op         == AXI_WRITE;
          addr       == 32'h800;
          data       == 32'h456;
          addr_delay == 0;
          data_delay == 3;
        }) `uvm_error("SEQ", "Randomization failed")
        finish_item(items[1]);
      end
      begin
        start_item(items[2]);
        if (!items[2].randomize() with {
          op         == AXI_WRITE;
          addr       == 32'h900;
          data       == 32'h789;
          addr_delay == 0;
          data_delay == 3;
        }) `uvm_error("SEQ", "Randomization failed")
        finish_item(items[2]);
      end
    join

    `uvm_info("SEQ", "Write data delayed sequence complete", UVM_LOW)
  endtask

endclass

//============================================================================
// Test 4: Write Address Delayed Sequence (Data Before Address)
//============================================================================

class write_addr_delayed_seq extends axi_base_sequence;

  `uvm_object_utils(write_addr_delayed_seq)

  function new(string name = "write_addr_delayed_seq");
    super.new(name);
  endfunction

  virtual task body();
    axi_seq_item items[$];
    axi_seq_item item;

    `uvm_info("SEQ", "*** Write Address Delayed (Data Before Address) ***", UVM_LOW)

    // Create items with address delayed relative to data
    for (int i = 0; i < 3; i++) begin
      item = axi_seq_item::type_id::create($sformatf("wr_item_%0d", i));
      items.push_back(item);
    end

    fork
      begin
        start_item(items[0]);
        if (!items[0].randomize() with {
          op         == AXI_WRITE;
          addr       == 32'hA00;
          data       == 32'h123;
          addr_delay == 3;  // Address comes 3 cycles after data
          data_delay == 0;
        }) `uvm_error("SEQ", "Randomization failed")
        finish_item(items[0]);
      end
      begin
        start_item(items[1]);
        if (!items[1].randomize() with {
          op         == AXI_WRITE;
          addr       == 32'hB00;
          data       == 32'h456;
          addr_delay == 3;
          data_delay == 0;
        }) `uvm_error("SEQ", "Randomization failed")
        finish_item(items[1]);
      end
      begin
        start_item(items[2]);
        if (!items[2].randomize() with {
          op         == AXI_WRITE;
          addr       == 32'hC00;
          data       == 32'h789;
          addr_delay == 3;
          data_delay == 0;
        }) `uvm_error("SEQ", "Randomization failed")
        finish_item(items[2]);
      end
    join

    `uvm_info("SEQ", "Write address delayed sequence complete", UVM_LOW)
  endtask

endclass

//============================================================================
// Test 5: Non-Pipelined Reads Sequence
//============================================================================

class non_pipelined_reads_seq extends axi_base_sequence;

  `uvm_object_utils(non_pipelined_reads_seq)

  function new(string name = "non_pipelined_reads_seq");
    super.new(name);
  endfunction

  virtual task body();
    `uvm_info("SEQ", "*** Non-Pipelined Reads ***", UVM_LOW)

    // Sequential read operations
    send_read('h100, .in_order(1));
    send_read('h200, .in_order(1));
    send_read('h300, .in_order(1));
    send_read('h400, .in_order(1));
    send_read('h500, .in_order(1));

    `uvm_info("SEQ", "Non-pipelined reads complete", UVM_LOW)
  endtask

endclass

//============================================================================
// Test 6: Pipelined Reads In-Order Sequence
//============================================================================

class pipelined_reads_in_order_seq extends axi_base_sequence;

  `uvm_object_utils(pipelined_reads_in_order_seq)

  function new(string name = "pipelined_reads_in_order_seq");
    super.new(name);
  endfunction

  virtual task body();
    axi_seq_item items[$];
    axi_seq_item item;

    `uvm_info("SEQ", "*** Pipelined Reads In-Order ***", UVM_LOW)

    // Create read items with in_order constraint (all use ID=0)
    for (int i = 0; i < 5; i++) begin
      item = axi_seq_item::type_id::create($sformatf("rd_item_%0d", i));
      items.push_back(item);
    end

    fork
      begin
        start_item(items[0]);
        if (!items[0].randomize() with {
          op       == AXI_READ;
          addr     == 32'h100;
          in_order == 1;
        }) `uvm_error("SEQ", "Randomization failed")
        finish_item(items[0]);
      end
      begin
        start_item(items[1]);
        if (!items[1].randomize() with {
          op       == AXI_READ;
          addr     == 32'h200;
          in_order == 1;
        }) `uvm_error("SEQ", "Randomization failed")
        finish_item(items[1]);
      end
      begin
        start_item(items[2]);
        if (!items[2].randomize() with {
          op       == AXI_READ;
          addr     == 32'h300;
          in_order == 1;
        }) `uvm_error("SEQ", "Randomization failed")
        finish_item(items[2]);
      end
      begin
        start_item(items[3]);
        if (!items[3].randomize() with {
          op       == AXI_READ;
          addr     == 32'h400;
          in_order == 1;
        }) `uvm_error("SEQ", "Randomization failed")
        finish_item(items[3]);
      end
      begin
        start_item(items[4]);
        if (!items[4].randomize() with {
          op       == AXI_READ;
          addr     == 32'h500;
          in_order == 1;
        }) `uvm_error("SEQ", "Randomization failed")
        finish_item(items[4]);
      end
    join

    `uvm_info("SEQ", "Pipelined reads in-order complete", UVM_LOW)
  endtask

endclass

//============================================================================
// Test 7: Pipelined Reads Out-of-Order Sequence
//============================================================================

class pipelined_reads_out_of_order_seq extends axi_base_sequence;

  `uvm_object_utils(pipelined_reads_out_of_order_seq)

  // Reference to driver for controlling ready probability
  axi_driver driver;

  function new(string name = "pipelined_reads_out_of_order_seq");
    super.new(name);
  endfunction

  virtual task body();
    axi_seq_item items[$];
    axi_seq_item item;

    `uvm_info("SEQ", "*** Pipelined Reads Out-of-Order ***", UVM_LOW)

    // Get driver reference from sequencer's parent agent
    begin
      axi_agent agent;
      if ($cast(agent, m_sequencer.get_parent()))
        driver = agent.driver;
    end

    // Create read items with different IDs for out-of-order responses
    for (int i = 0; i < 5; i++) begin
      item = axi_seq_item::type_id::create($sformatf("rd_item_%0d", i));
      items.push_back(item);
    end

    // Disable read ready to allow responses to queue up
    if (driver != null)
      driver.read_data_ready_probability = 0;

    fork
      begin
        start_item(items[0]);
        if (!items[0].randomize() with {
          op       == AXI_READ;
          addr     == 32'h100;
          id       == 1;  // Different IDs for out-of-order
          in_order == 0;
        }) `uvm_error("SEQ", "Randomization failed")
        finish_item(items[0]);
      end
      begin
        start_item(items[1]);
        if (!items[1].randomize() with {
          op       == AXI_READ;
          addr     == 32'h200;
          id       == 2;
          in_order == 0;
        }) `uvm_error("SEQ", "Randomization failed")
        finish_item(items[1]);
      end
      begin
        start_item(items[2]);
        if (!items[2].randomize() with {
          op       == AXI_READ;
          addr     == 32'h300;
          id       == 3;
          in_order == 0;
        }) `uvm_error("SEQ", "Randomization failed")
        finish_item(items[2]);
      end
      begin
        start_item(items[3]);
        if (!items[3].randomize() with {
          op       == AXI_READ;
          addr     == 32'h400;
          id       == 4;
          in_order == 0;
        }) `uvm_error("SEQ", "Randomization failed")
        finish_item(items[3]);
      end
      begin
        start_item(items[4]);
        if (!items[4].randomize() with {
          op       == AXI_READ;
          addr     == 32'h500;
          id       == 5;
          in_order == 0;
        }) `uvm_error("SEQ", "Randomization failed")
        finish_item(items[4]);
      end
    join

    // Wait some cycles then re-enable read ready
    #200;
    if (driver != null)
      driver.read_data_ready_probability = 100;

    `uvm_info("SEQ", "Pipelined reads out-of-order complete", UVM_LOW)
  endtask

endclass

//============================================================================
// Test 8: Random Transactions Sequence
//============================================================================

class random_transactions_seq extends axi_base_sequence;

  `uvm_object_utils(random_transactions_seq)

  int unsigned num_transactions = 100;
  int unsigned max_delay = 5;

  function new(string name = "random_transactions_seq");
    super.new(name);
  endfunction

  virtual task body();
    axi_seq_item item;

    `uvm_info("SEQ", $sformatf("*** Random Transactions (%0d) ***", num_transactions), UVM_LOW)

    for (int i = 0; i < num_transactions; i++) begin
      item = axi_seq_item::type_id::create($sformatf("rand_item_%0d", i));
      start_item(item);

      if (!item.randomize() with {
        addr_delay <= max_delay;
        data_delay <= max_delay;
      }) begin
        `uvm_error("SEQ", "Randomization failed for random transaction")
      end

      finish_item(item);
    end

    `uvm_info("SEQ", "Random transactions complete", UVM_LOW)
  endtask

endclass

//============================================================================
// Virtual Sequence - Runs All Tests
//============================================================================

class axi_all_tests_vseq extends uvm_sequence #(uvm_sequence_item);

  `uvm_object_utils(axi_all_tests_vseq)

  // Sequencer handle
  axi_sequencer axi_sqr;

  function new(string name = "axi_all_tests_vseq");
    super.new(name);
  endfunction

  virtual task body();
    non_pipelined_writes_seq        seq1;
    pipelined_writes_seq            seq2;
    write_data_delayed_seq          seq3;
    write_addr_delayed_seq          seq4;
    non_pipelined_reads_seq         seq5;
    pipelined_reads_in_order_seq    seq6;
    pipelined_reads_out_of_order_seq seq7;

    `uvm_info("VSEQ", "========================================", UVM_LOW)
    `uvm_info("VSEQ", "Starting All AXI Tests", UVM_LOW)
    `uvm_info("VSEQ", "========================================", UVM_LOW)

    // Test 1: Non-pipelined writes
    seq1 = non_pipelined_writes_seq::type_id::create("seq1");
    seq1.start(axi_sqr);

    // Test 2: Pipelined writes back-to-back
    seq2 = pipelined_writes_seq::type_id::create("seq2");
    seq2.start(axi_sqr);

    // Test 3: Write data delayed (multiple addresses before multiple data)
    seq3 = write_data_delayed_seq::type_id::create("seq3");
    seq3.start(axi_sqr);

    // Test 4: Write address delayed (data before address)
    seq4 = write_addr_delayed_seq::type_id::create("seq4");
    seq4.start(axi_sqr);

    // Test 5: Non-pipelined reads
    seq5 = non_pipelined_reads_seq::type_id::create("seq5");
    seq5.start(axi_sqr);

    // Test 6: Pipelined reads in-order
    seq6 = pipelined_reads_in_order_seq::type_id::create("seq6");
    seq6.start(axi_sqr);

    // Test 7: Pipelined reads out-of-order
    seq7 = pipelined_reads_out_of_order_seq::type_id::create("seq7");
    seq7.start(axi_sqr);

    `uvm_info("VSEQ", "========================================", UVM_LOW)
    `uvm_info("VSEQ", "All AXI Tests Complete", UVM_LOW)
    `uvm_info("VSEQ", "========================================", UVM_LOW)
  endtask

endclass
