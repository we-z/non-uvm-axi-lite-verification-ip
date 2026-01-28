//----------------------------------------------------------------------------
//  AXI Scoreboard
//
//  UVM scoreboard for verifying AXI transactions
//  Maintains a reference memory model for data checking
//----------------------------------------------------------------------------

// Analysis Implementation Macros (must be before class definition)
`uvm_analysis_imp_decl(_write)
`uvm_analysis_imp_decl(_read)

class axi_scoreboard extends uvm_scoreboard;

  `uvm_component_utils(axi_scoreboard)

  //--------------------------------------------------------------------------
  // Analysis Exports
  //--------------------------------------------------------------------------

  uvm_analysis_imp_write #(axi_seq_item, axi_scoreboard) write_export;
  uvm_analysis_imp_read  #(axi_seq_item, axi_scoreboard) read_export;

  //--------------------------------------------------------------------------
  // Reference Memory Model
  //--------------------------------------------------------------------------

  data_t ref_memory[addr_t];

  //--------------------------------------------------------------------------
  // Statistics
  //--------------------------------------------------------------------------

  int unsigned write_count;
  int unsigned read_count;
  int unsigned read_match_count;
  int unsigned read_mismatch_count;

  //--------------------------------------------------------------------------
  // Constructor
  //--------------------------------------------------------------------------

  function new(string name = "axi_scoreboard", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  //--------------------------------------------------------------------------
  // Build Phase
  //--------------------------------------------------------------------------

  virtual function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    write_export = new("write_export", this);
    read_export  = new("read_export", this);
  endfunction

  //--------------------------------------------------------------------------
  // Write Transaction Handler
  //--------------------------------------------------------------------------

  virtual function void write_write(axi_seq_item item);
    ref_memory[item.addr] = item.data;
    write_count++;

    `uvm_info("SCB", $sformatf("Write: addr='h%0h data='h%0h (total writes: %0d)",
              item.addr, item.data, write_count), UVM_MEDIUM)
  endfunction

  //--------------------------------------------------------------------------
  // Read Transaction Handler
  //--------------------------------------------------------------------------

  virtual function void write_read(axi_seq_item item);
    data_t expected;
    read_count++;

    if (!ref_memory.exists(item.addr)) begin
      `uvm_warning("SCB", $sformatf("Read from uninitialized address: 'h%0h", item.addr))
    end else begin
      expected = ref_memory[item.addr];

      if (item.data === expected) begin
        read_match_count++;
        `uvm_info("SCB", $sformatf("Read MATCH: addr='h%0h data='h%0h id=%0d",
                  item.addr, item.data, item.id), UVM_MEDIUM)
      end else begin
        read_mismatch_count++;
        `uvm_error("SCB", $sformatf("Read MISMATCH: addr='h%0h expected='h%0h actual='h%0h id=%0d",
                   item.addr, expected, item.data, item.id))
      end
    end
  endfunction

  //--------------------------------------------------------------------------
  // Report Phase
  //--------------------------------------------------------------------------

  virtual function void report_phase(uvm_phase phase);
    `uvm_info("SCB", "========== Scoreboard Summary ==========", UVM_LOW)
    `uvm_info("SCB", $sformatf("Total Writes:       %0d", write_count), UVM_LOW)
    `uvm_info("SCB", $sformatf("Total Reads:        %0d", read_count), UVM_LOW)
    `uvm_info("SCB", $sformatf("Read Matches:       %0d", read_match_count), UVM_LOW)
    `uvm_info("SCB", $sformatf("Read Mismatches:    %0d", read_mismatch_count), UVM_LOW)
    `uvm_info("SCB", "=========================================", UVM_LOW)

    if (read_mismatch_count > 0)
      `uvm_error("SCB", "TEST FAILED: Read mismatches detected")
    else
      `uvm_info("SCB", "TEST PASSED: All reads matched", UVM_LOW)
  endfunction

  //--------------------------------------------------------------------------
  // Memory Dump (for debugging)
  //--------------------------------------------------------------------------

  virtual function void dump_memory();
    `uvm_info("SCB", "========== Memory Dump ==========", UVM_LOW)
    foreach (ref_memory[addr])
      `uvm_info("SCB", $sformatf("  [%h]: %h", addr, ref_memory[addr]), UVM_LOW)
    `uvm_info("SCB", "=================================", UVM_LOW)
  endfunction

endclass
