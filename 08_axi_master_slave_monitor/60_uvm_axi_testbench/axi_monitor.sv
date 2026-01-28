//----------------------------------------------------------------------------
//  AXI Monitor (Passive)
//
//  UVM monitor implementing passive AXI bus monitoring with:
//  - Transaction reconstruction from channel signals
//  - Support for out-of-order read responses
//  - Analysis port for scoreboard/coverage
//----------------------------------------------------------------------------

class axi_monitor extends uvm_monitor;

  `uvm_component_utils(axi_monitor)

  //--------------------------------------------------------------------------
  // Virtual Interface
  //--------------------------------------------------------------------------

  virtual axi_if vif;

  //--------------------------------------------------------------------------
  // Analysis Ports
  //--------------------------------------------------------------------------

  uvm_analysis_port #(axi_seq_item) write_ap;
  uvm_analysis_port #(axi_seq_item) read_ap;

  //--------------------------------------------------------------------------
  // Internal State for Transaction Reconstruction
  //--------------------------------------------------------------------------

  // Queues for pending transactions
  addr_t wr_addr_queue[$];
  data_t wr_data_queue[$];

  // Track read addresses by ID for out-of-order response matching
  axi_seq_item rd_pending[N_IDS][$];

  // Cycle counter
  int unsigned cycle;

  //--------------------------------------------------------------------------
  // Constructor
  //--------------------------------------------------------------------------

  function new(string name = "axi_monitor", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  //--------------------------------------------------------------------------
  // Build Phase
  //--------------------------------------------------------------------------

  virtual function void build_phase(uvm_phase phase);
    super.build_phase(phase);

    write_ap = new("write_ap", this);
    read_ap  = new("read_ap", this);

    if (!uvm_config_db#(virtual axi_if)::get(this, "", "vif", vif))
      `uvm_fatal("NOVIF", "Virtual interface not found")
  endfunction

  //--------------------------------------------------------------------------
  // Reset Monitor State
  //--------------------------------------------------------------------------

  virtual task reset_monitor();
    wr_addr_queue.delete();
    wr_data_queue.delete();

    for (int i = 0; i < N_IDS; i++)
      rd_pending[i].delete();

    cycle = 0;
  endtask

  //--------------------------------------------------------------------------
  // Run Phase
  //--------------------------------------------------------------------------

  virtual task run_phase(uvm_phase phase);
    // Wait for reset
    @(negedge vif.rst);
    reset_monitor();

    // Fork parallel monitoring processes
    fork
      monitor_write_address();
      monitor_write_data();
      monitor_write_complete();
      monitor_read_address();
      monitor_read_response();
      increment_cycle();
    join
  endtask

  //--------------------------------------------------------------------------
  // Increment Cycle Counter
  //--------------------------------------------------------------------------

  virtual task increment_cycle();
    forever begin
      @(vif.mon_cb);
      if (!vif.rst)
        cycle++;
    end
  endtask

  //--------------------------------------------------------------------------
  // Monitor Write Address Channel
  //--------------------------------------------------------------------------

  virtual task monitor_write_address();
    forever begin
      @(vif.mon_cb);

      if (vif.rst) begin
        wr_addr_queue.delete();
        continue;
      end

      if (vif.mon_cb.awvalid && vif.mon_cb.awready) begin
        wr_addr_queue.push_back(vif.mon_cb.awaddr);
        `uvm_info("MON", $sformatf("%0d monitor: write address captured: addr='h%0h",
                  cycle, vif.mon_cb.awaddr), UVM_MEDIUM)
      end
    end
  endtask

  //--------------------------------------------------------------------------
  // Monitor Write Data Channel
  //--------------------------------------------------------------------------

  virtual task monitor_write_data();
    forever begin
      @(vif.mon_cb);

      if (vif.rst) begin
        wr_data_queue.delete();
        continue;
      end

      if (vif.mon_cb.wvalid && vif.mon_cb.wready) begin
        wr_data_queue.push_back(vif.mon_cb.wdata);
        `uvm_info("MON", $sformatf("%0d monitor: write data captured: data='h%0h",
                  cycle, vif.mon_cb.wdata), UVM_MEDIUM)
      end
    end
  endtask

  //--------------------------------------------------------------------------
  // Monitor Write Completion (When Both Address and Data Are Available)
  //--------------------------------------------------------------------------

  virtual task monitor_write_complete();
    axi_seq_item item;

    forever begin
      @(vif.mon_cb);

      if (vif.rst)
        continue;

      // Check if we have both address and data to complete a write
      while (wr_addr_queue.size() > 0 && wr_data_queue.size() > 0) begin
        item = axi_seq_item::type_id::create("write_item");
        item.op   = AXI_WRITE;
        item.addr = wr_addr_queue.pop_front();
        item.data = wr_data_queue.pop_front();
        item.id   = 0;  // Writes use ID=0

        `uvm_info("MON", $sformatf("%0d monitor: write transaction complete: %s",
                  cycle, item.convert2string()), UVM_MEDIUM)

        write_ap.write(item);
      end
    end
  endtask

  //--------------------------------------------------------------------------
  // Monitor Read Address Channel
  //--------------------------------------------------------------------------

  virtual task monitor_read_address();
    axi_seq_item item;

    forever begin
      @(vif.mon_cb);

      if (vif.rst) begin
        for (int i = 0; i < N_IDS; i++)
          rd_pending[i].delete();
        continue;
      end

      if (vif.mon_cb.arvalid && vif.mon_cb.arready) begin
        item = axi_seq_item::type_id::create("read_item");
        item.op   = AXI_READ;
        item.addr = vif.mon_cb.araddr;
        item.id   = vif.mon_cb.arid;

        rd_pending[item.id].push_back(item);

        `uvm_info("MON", $sformatf("%0d monitor: read address captured: addr='h%0h id=%0d",
                  cycle, item.addr, item.id), UVM_MEDIUM)
      end
    end
  endtask

  //--------------------------------------------------------------------------
  // Monitor Read Response Channel (Out-of-Order Based on ID)
  //--------------------------------------------------------------------------

  virtual task monitor_read_response();
    axi_seq_item item;
    id_t rid;

    forever begin
      @(vif.mon_cb);

      if (vif.rst)
        continue;

      if (vif.mon_cb.rvalid && vif.mon_cb.rready) begin
        rid = vif.mon_cb.rid;

        if (rd_pending[rid].size() == 0) begin
          `uvm_error("MON", $sformatf("%0d monitor: Unexpected read response for ID=%0d",
                     cycle, rid))
        end else begin
          item = rd_pending[rid].pop_front();
          item.data = vif.mon_cb.rdata;
          item.data_is_set = 1;

          `uvm_info("MON", $sformatf("%0d monitor: read transaction complete: %s",
                    cycle, item.convert2string()), UVM_MEDIUM)

          read_ap.write(item);
        end
      end
    end
  endtask

endclass
