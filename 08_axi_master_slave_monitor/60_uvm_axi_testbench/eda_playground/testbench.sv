//============================================================================
// EDA Playground - Testbench Pane (Right Side)
// Complete UVM Testbench for AXI-Lite Verification
//
// Instructions:
// 1. Go to https://edaplayground.com
// 2. Paste design.sv in LEFT pane
// 3. Paste this file in RIGHT pane
// 4. Select "Synopsys VCS" or "Cadence Xcelium" as simulator
// 5. Check "UVM 1.2" checkbox
// 6. Click "Run"
//============================================================================

`timescale 1ns/1ps

//============================================================================
// AXI Package with UVM Components
//============================================================================
package axi_pkg;

  import uvm_pkg::*;
  `include "uvm_macros.svh"

  // Parameters
  parameter int ADDR_WIDTH  = 32;
  parameter int DATA_WIDTH  = 32;
  parameter int ID_WIDTH    = 4;
  parameter int MAX_DELAY   = 100;
  parameter int N_IDS       = 1 << ID_WIDTH;

  // Types
  typedef enum bit { AXI_READ = 0, AXI_WRITE = 1 } axi_op_t;
  typedef logic [ADDR_WIDTH - 1:0]  addr_t;
  typedef logic [DATA_WIDTH - 1:0]  data_t;
  typedef logic [ID_WIDTH - 1:0]    id_t;

  //==========================================================================
  // AXI Sequence Item
  //==========================================================================
  class axi_seq_item extends uvm_sequence_item;

    rand axi_op_t op;
    rand addr_t   addr;
    rand data_t   data;
    rand id_t     id;
    rand int      addr_delay;
    rand int      data_delay;
    bit           data_is_set;
    bit           addr_is_sent;
    bit           data_is_sent;
    bit           in_order;

    `uvm_object_utils_begin(axi_seq_item)
      `uvm_field_enum(axi_op_t, op, UVM_ALL_ON)
      `uvm_field_int(addr, UVM_ALL_ON | UVM_HEX)
      `uvm_field_int(data, UVM_ALL_ON | UVM_HEX)
      `uvm_field_int(id, UVM_ALL_ON)
      `uvm_field_int(addr_delay, UVM_ALL_ON)
      `uvm_field_int(data_delay, UVM_ALL_ON)
    `uvm_object_utils_end

    constraint id_c {
      id < N_IDS;
      op == AXI_WRITE -> id == 0;
      in_order -> id == 0;
    }

    constraint delay_c {
      addr_delay >= 0; addr_delay <= 5;
      data_delay >= 0; data_delay <= 5;
      op == AXI_READ -> data_delay == 0;
    }

    function new(string name = "axi_seq_item");
      super.new(name);
    endfunction

    virtual function string convert2string();
      return $sformatf("%s addr='h%0h data='h%0h id=%0d", op.name(), addr, data, id);
    endfunction

  endclass

  //==========================================================================
  // AXI Sequencer
  //==========================================================================
  class axi_sequencer extends uvm_sequencer #(axi_seq_item);
    `uvm_component_utils(axi_sequencer)
    function new(string name = "axi_sequencer", uvm_component parent = null);
      super.new(name, parent);
    endfunction
  endclass

  //==========================================================================
  // AXI Driver
  //==========================================================================
  class axi_driver extends uvm_driver #(axi_seq_item);

    `uvm_component_utils(axi_driver)

    virtual axi_if vif;
    int unsigned read_data_ready_probability = 100;
    int unsigned write_response_ready_probability = 100;

    // Internal queues
    axi_seq_item rd_addr_queue[$];
    axi_seq_item wr_addr_queue[$];
    axi_seq_item wr_data_queue[$];
    axi_seq_item rd_data_array[N_IDS][$];
    axi_seq_item wr_resp_queue[$];
    int unsigned cycle;

    function new(string name = "axi_driver", uvm_component parent = null);
      super.new(name, parent);
    endfunction

    virtual function void build_phase(uvm_phase phase);
      super.build_phase(phase);
      if (!uvm_config_db#(virtual axi_if)::get(this, "", "vif", vif))
        `uvm_fatal("NOVIF", "Virtual interface not found")
    endfunction

    virtual task run_phase(uvm_phase phase);
      @(negedge vif.rst);
      reset_driver();
      fork
        get_transactions();
        drive_read_address();
        drive_write_address();
        drive_write_data();
        handle_read_response();
        handle_write_response();
        update_ready_signals();
        forever begin @(vif.drv_cb); if (!vif.rst) cycle++; end
      join
    endtask

    virtual task reset_driver();
      rd_addr_queue.delete(); wr_addr_queue.delete(); wr_data_queue.delete();
      for (int i = 0; i < N_IDS; i++) rd_data_array[i].delete();
      wr_resp_queue.delete();
      vif.drv_cb.arvalid <= 0; vif.drv_cb.awvalid <= 0; vif.drv_cb.wvalid <= 0;
      vif.drv_cb.rready <= 0; vif.drv_cb.bready <= 0;
      cycle = 0;
    endtask

    virtual task get_transactions();
      axi_seq_item item;
      forever begin
        seq_item_port.get_next_item(item);
        `uvm_info("DRV", $sformatf("%0d driver: got %s", cycle, item.convert2string()), UVM_MEDIUM)
        if (item.op == AXI_READ) rd_addr_queue.push_back(item);
        else begin wr_addr_queue.push_back(item); wr_data_queue.push_back(item); end
        seq_item_port.item_done();
      end
    endtask

    virtual task drive_read_address();
      axi_seq_item item;
      forever begin
        @(vif.drv_cb);
        if (vif.rst) begin vif.drv_cb.arvalid <= 0; continue; end
        if (vif.drv_cb.arvalid && vif.drv_cb.arready) begin
          item = rd_addr_queue.pop_front();
          rd_data_array[item.id].push_back(item);
          `uvm_info("DRV", $sformatf("%0d driver: read addr sent: %s", cycle, item.convert2string()), UVM_MEDIUM)
        end
        vif.drv_cb.arvalid <= 0;
        if (rd_addr_queue.size() > 0) begin
          item = rd_addr_queue[0];
          if (item.addr_delay > 0) item.addr_delay--;
          else begin vif.drv_cb.arvalid <= 1; vif.drv_cb.araddr <= item.addr; vif.drv_cb.arid <= item.id; end
        end
      end
    endtask

    virtual task drive_write_address();
      axi_seq_item item;
      forever begin
        @(vif.drv_cb);
        if (vif.rst) begin vif.drv_cb.awvalid <= 0; continue; end
        if (vif.drv_cb.awvalid && vif.drv_cb.awready) begin
          item = wr_addr_queue.pop_front();
          item.addr_is_sent = 1;
          if (!item.data_is_sent) wr_resp_queue.push_back(item);
          `uvm_info("DRV", $sformatf("%0d driver: write addr sent: %s", cycle, item.convert2string()), UVM_MEDIUM)
        end
        vif.drv_cb.awvalid <= 0;
        if (wr_addr_queue.size() > 0) begin
          item = wr_addr_queue[0];
          if (item.addr_delay > 0) item.addr_delay--;
          else begin vif.drv_cb.awvalid <= 1; vif.drv_cb.awaddr <= item.addr; end
        end
      end
    endtask

    virtual task drive_write_data();
      axi_seq_item item;
      forever begin
        @(vif.drv_cb);
        if (vif.rst) begin vif.drv_cb.wvalid <= 0; continue; end
        if (vif.drv_cb.wvalid && vif.drv_cb.wready) begin
          item = wr_data_queue.pop_front();
          item.data_is_sent = 1;
          if (!item.addr_is_sent) wr_resp_queue.push_back(item);
          `uvm_info("DRV", $sformatf("%0d driver: write data sent: %s", cycle, item.convert2string()), UVM_MEDIUM)
        end
        vif.drv_cb.wvalid <= 0;
        if (wr_data_queue.size() > 0) begin
          item = wr_data_queue[0];
          if (item.data_delay > 0) item.data_delay--;
          else begin vif.drv_cb.wvalid <= 1; vif.drv_cb.wdata <= item.data; end
        end
      end
    endtask

    virtual task handle_read_response();
      axi_seq_item item; id_t rid;
      forever begin
        @(vif.drv_cb);
        if (vif.rst) continue;
        if (vif.drv_cb.rvalid && vif.drv_cb.rready) begin
          rid = vif.drv_cb.rid;
          if (rd_data_array[rid].size() > 0) begin
            item = rd_data_array[rid].pop_front();
            item.data = vif.drv_cb.rdata;
            `uvm_info("DRV", $sformatf("%0d driver: read data rcvd: %s", cycle, item.convert2string()), UVM_MEDIUM)
          end
        end
      end
    endtask

    virtual task handle_write_response();
      axi_seq_item item;
      forever begin
        @(vif.drv_cb);
        if (vif.rst) continue;
        if (vif.drv_cb.bvalid && vif.drv_cb.bready) begin
          if (wr_resp_queue.size() > 0) begin
            item = wr_resp_queue.pop_front();
            `uvm_info("DRV", $sformatf("%0d driver: write resp rcvd: %s", cycle, item.convert2string()), UVM_MEDIUM)
          end
        end
      end
    endtask

    virtual task update_ready_signals();
      forever begin
        @(vif.drv_cb);
        if (vif.rst) begin vif.drv_cb.rready <= 0; vif.drv_cb.bready <= 0; end
        else begin
          vif.drv_cb.rready <= ($urandom_range(0, 99) < read_data_ready_probability);
          vif.drv_cb.bready <= ($urandom_range(0, 99) < write_response_ready_probability);
        end
      end
    endtask

  endclass

  //==========================================================================
  // AXI Monitor
  //==========================================================================
  class axi_monitor extends uvm_monitor;

    `uvm_component_utils(axi_monitor)

    virtual axi_if vif;
    uvm_analysis_port #(axi_seq_item) write_ap;
    uvm_analysis_port #(axi_seq_item) read_ap;

    addr_t wr_addr_queue[$];
    data_t wr_data_queue[$];
    axi_seq_item rd_pending[N_IDS][$];
    int unsigned cycle;

    function new(string name = "axi_monitor", uvm_component parent = null);
      super.new(name, parent);
    endfunction

    virtual function void build_phase(uvm_phase phase);
      super.build_phase(phase);
      write_ap = new("write_ap", this);
      read_ap  = new("read_ap", this);
      if (!uvm_config_db#(virtual axi_if)::get(this, "", "vif", vif))
        `uvm_fatal("NOVIF", "Virtual interface not found")
    endfunction

    virtual task run_phase(uvm_phase phase);
      @(negedge vif.rst);
      fork
        monitor_write();
        monitor_read();
        forever begin @(vif.mon_cb); if (!vif.rst) cycle++; end
      join
    endtask

    virtual task monitor_write();
      axi_seq_item item;
      forever begin
        @(vif.mon_cb);
        if (vif.rst) begin wr_addr_queue.delete(); wr_data_queue.delete(); continue; end
        if (vif.mon_cb.awvalid && vif.mon_cb.awready) wr_addr_queue.push_back(vif.mon_cb.awaddr);
        if (vif.mon_cb.wvalid && vif.mon_cb.wready) wr_data_queue.push_back(vif.mon_cb.wdata);
        while (wr_addr_queue.size() > 0 && wr_data_queue.size() > 0) begin
          item = axi_seq_item::type_id::create("wr_item");
          item.op = AXI_WRITE; item.addr = wr_addr_queue.pop_front(); item.data = wr_data_queue.pop_front();
          `uvm_info("MON", $sformatf("%0d monitor: write complete: %s", cycle, item.convert2string()), UVM_MEDIUM)
          write_ap.write(item);
        end
      end
    endtask

    virtual task monitor_read();
      axi_seq_item item; id_t rid;
      forever begin
        @(vif.mon_cb);
        if (vif.rst) begin for (int i = 0; i < N_IDS; i++) rd_pending[i].delete(); continue; end
        if (vif.mon_cb.arvalid && vif.mon_cb.arready) begin
          item = axi_seq_item::type_id::create("rd_item");
          item.op = AXI_READ; item.addr = vif.mon_cb.araddr; item.id = vif.mon_cb.arid;
          rd_pending[item.id].push_back(item);
        end
        if (vif.mon_cb.rvalid && vif.mon_cb.rready) begin
          rid = vif.mon_cb.rid;
          if (rd_pending[rid].size() > 0) begin
            item = rd_pending[rid].pop_front();
            item.data = vif.mon_cb.rdata;
            `uvm_info("MON", $sformatf("%0d monitor: read complete: %s", cycle, item.convert2string()), UVM_MEDIUM)
            read_ap.write(item);
          end
        end
      end
    endtask

  endclass

  //==========================================================================
  // AXI Scoreboard
  //==========================================================================
  `uvm_analysis_imp_decl(_write)
  `uvm_analysis_imp_decl(_read)

  class axi_scoreboard extends uvm_scoreboard;

    `uvm_component_utils(axi_scoreboard)

    uvm_analysis_imp_write #(axi_seq_item, axi_scoreboard) write_export;
    uvm_analysis_imp_read  #(axi_seq_item, axi_scoreboard) read_export;
    data_t ref_memory[addr_t];
    int write_count, read_count, match_count, mismatch_count;

    function new(string name = "axi_scoreboard", uvm_component parent = null);
      super.new(name, parent);
    endfunction

    virtual function void build_phase(uvm_phase phase);
      super.build_phase(phase);
      write_export = new("write_export", this);
      read_export  = new("read_export", this);
    endfunction

    virtual function void write_write(axi_seq_item item);
      ref_memory[item.addr] = item.data;
      write_count++;
    endfunction

    virtual function void write_read(axi_seq_item item);
      read_count++;
      if (ref_memory.exists(item.addr)) begin
        if (item.data === ref_memory[item.addr]) match_count++;
        else begin
          mismatch_count++;
          `uvm_error("SCB", $sformatf("MISMATCH: addr=%h exp=%h got=%h", item.addr, ref_memory[item.addr], item.data))
        end
      end
    endfunction

    virtual function void report_phase(uvm_phase phase);
      `uvm_info("SCB", $sformatf("Writes=%0d Reads=%0d Match=%0d Mismatch=%0d", write_count, read_count, match_count, mismatch_count), UVM_LOW)
    endfunction

  endclass

  //==========================================================================
  // AXI Agent
  //==========================================================================
  class axi_agent extends uvm_agent;
    `uvm_component_utils(axi_agent)
    axi_driver driver;
    axi_monitor monitor;
    axi_sequencer sequencer;

    function new(string name = "axi_agent", uvm_component parent = null);
      super.new(name, parent);
    endfunction

    virtual function void build_phase(uvm_phase phase);
      super.build_phase(phase);
      monitor = axi_monitor::type_id::create("monitor", this);
      driver = axi_driver::type_id::create("driver", this);
      sequencer = axi_sequencer::type_id::create("sequencer", this);
    endfunction

    virtual function void connect_phase(uvm_phase phase);
      super.connect_phase(phase);
      driver.seq_item_port.connect(sequencer.seq_item_export);
    endfunction
  endclass

  //==========================================================================
  // AXI Environment
  //==========================================================================
  class axi_env extends uvm_env;
    `uvm_component_utils(axi_env)
    axi_agent agent;
    axi_scoreboard scoreboard;

    function new(string name = "axi_env", uvm_component parent = null);
      super.new(name, parent);
    endfunction

    virtual function void build_phase(uvm_phase phase);
      super.build_phase(phase);
      agent = axi_agent::type_id::create("agent", this);
      scoreboard = axi_scoreboard::type_id::create("scoreboard", this);
    endfunction

    virtual function void connect_phase(uvm_phase phase);
      super.connect_phase(phase);
      agent.monitor.write_ap.connect(scoreboard.write_export);
      agent.monitor.read_ap.connect(scoreboard.read_export);
    endfunction
  endclass

  //==========================================================================
  // AXI Sequences
  //==========================================================================

  // Base sequence
  class axi_base_seq extends uvm_sequence #(axi_seq_item);
    `uvm_object_utils(axi_base_seq)
    function new(string name = "axi_base_seq");
      super.new(name);
    endfunction
  endclass

  // Test 1: Non-pipelined writes
  class non_pipelined_writes_seq extends axi_base_seq;
    `uvm_object_utils(non_pipelined_writes_seq)
    function new(string name = "non_pipelined_writes_seq");
      super.new(name);
    endfunction
    virtual task body();
      axi_seq_item item;
      `uvm_info("SEQ", "*** Non-Pipelined Writes ***", UVM_LOW)
      for (int i = 0; i < 3; i++) begin
        item = axi_seq_item::type_id::create($sformatf("wr%0d", i));
        start_item(item);
        assert(item.randomize() with { op == AXI_WRITE; addr == 32'h100 + i*256; data == 32'h123 + i*333; addr_delay == 0; data_delay == 0; });
        finish_item(item);
      end
    endtask
  endclass

  // Test 2: Pipelined writes (back-to-back)
  class pipelined_writes_seq extends axi_base_seq;
    `uvm_object_utils(pipelined_writes_seq)
    function new(string name = "pipelined_writes_seq");
      super.new(name);
    endfunction
    virtual task body();
      axi_seq_item items[3];
      `uvm_info("SEQ", "*** Pipelined Writes Back-to-Back ***", UVM_LOW)
      foreach (items[i]) items[i] = axi_seq_item::type_id::create($sformatf("wr%0d", i));
      fork
        begin start_item(items[0]); assert(items[0].randomize() with { op == AXI_WRITE; addr == 32'h400; data == 32'hAAA; }); finish_item(items[0]); end
        begin start_item(items[1]); assert(items[1].randomize() with { op == AXI_WRITE; addr == 32'h500; data == 32'hBBB; }); finish_item(items[1]); end
        begin start_item(items[2]); assert(items[2].randomize() with { op == AXI_WRITE; addr == 32'h600; data == 32'hCCC; }); finish_item(items[2]); end
      join
    endtask
  endclass

  // Test 3: Write data delayed (address before data)
  class write_data_delayed_seq extends axi_base_seq;
    `uvm_object_utils(write_data_delayed_seq)
    function new(string name = "write_data_delayed_seq");
      super.new(name);
    endfunction
    virtual task body();
      axi_seq_item items[3];
      `uvm_info("SEQ", "*** Write Data Delayed (Addresses Before Data) ***", UVM_LOW)
      foreach (items[i]) items[i] = axi_seq_item::type_id::create($sformatf("wr%0d", i));
      fork
        begin start_item(items[0]); assert(items[0].randomize() with { op == AXI_WRITE; addr == 32'h700; data == 32'h111; addr_delay == 0; data_delay == 3; }); finish_item(items[0]); end
        begin start_item(items[1]); assert(items[1].randomize() with { op == AXI_WRITE; addr == 32'h800; data == 32'h222; addr_delay == 0; data_delay == 3; }); finish_item(items[1]); end
        begin start_item(items[2]); assert(items[2].randomize() with { op == AXI_WRITE; addr == 32'h900; data == 32'h333; addr_delay == 0; data_delay == 3; }); finish_item(items[2]); end
      join
    endtask
  endclass

  // Test 4: Write address delayed (data before address)
  class write_addr_delayed_seq extends axi_base_seq;
    `uvm_object_utils(write_addr_delayed_seq)
    function new(string name = "write_addr_delayed_seq");
      super.new(name);
    endfunction
    virtual task body();
      axi_seq_item items[3];
      `uvm_info("SEQ", "*** Write Address Delayed (Data Before Address) ***", UVM_LOW)
      foreach (items[i]) items[i] = axi_seq_item::type_id::create($sformatf("wr%0d", i));
      fork
        begin start_item(items[0]); assert(items[0].randomize() with { op == AXI_WRITE; addr == 32'hA00; data == 32'h444; addr_delay == 3; data_delay == 0; }); finish_item(items[0]); end
        begin start_item(items[1]); assert(items[1].randomize() with { op == AXI_WRITE; addr == 32'hB00; data == 32'h555; addr_delay == 3; data_delay == 0; }); finish_item(items[1]); end
        begin start_item(items[2]); assert(items[2].randomize() with { op == AXI_WRITE; addr == 32'hC00; data == 32'h666; addr_delay == 3; data_delay == 0; }); finish_item(items[2]); end
      join
    endtask
  endclass

  // Test 5: Non-pipelined reads
  class non_pipelined_reads_seq extends axi_base_seq;
    `uvm_object_utils(non_pipelined_reads_seq)
    function new(string name = "non_pipelined_reads_seq");
      super.new(name);
    endfunction
    virtual task body();
      axi_seq_item item;
      `uvm_info("SEQ", "*** Non-Pipelined Reads ***", UVM_LOW)
      for (int i = 0; i < 5; i++) begin
        item = axi_seq_item::type_id::create($sformatf("rd%0d", i));
        start_item(item);
        assert(item.randomize() with { op == AXI_READ; addr == 32'h100 + i*256; in_order == 1; });
        finish_item(item);
      end
    endtask
  endclass

  // Test 6: Pipelined reads in-order
  class pipelined_reads_in_order_seq extends axi_base_seq;
    `uvm_object_utils(pipelined_reads_in_order_seq)
    function new(string name = "pipelined_reads_in_order_seq");
      super.new(name);
    endfunction
    virtual task body();
      axi_seq_item items[5];
      `uvm_info("SEQ", "*** Pipelined Reads In-Order ***", UVM_LOW)
      foreach (items[i]) items[i] = axi_seq_item::type_id::create($sformatf("rd%0d", i));
      fork
        begin start_item(items[0]); assert(items[0].randomize() with { op == AXI_READ; addr == 32'h100; in_order == 1; }); finish_item(items[0]); end
        begin start_item(items[1]); assert(items[1].randomize() with { op == AXI_READ; addr == 32'h200; in_order == 1; }); finish_item(items[1]); end
        begin start_item(items[2]); assert(items[2].randomize() with { op == AXI_READ; addr == 32'h300; in_order == 1; }); finish_item(items[2]); end
        begin start_item(items[3]); assert(items[3].randomize() with { op == AXI_READ; addr == 32'h400; in_order == 1; }); finish_item(items[3]); end
        begin start_item(items[4]); assert(items[4].randomize() with { op == AXI_READ; addr == 32'h500; in_order == 1; }); finish_item(items[4]); end
      join
    endtask
  endclass

  // Test 7: Pipelined reads out-of-order
  class pipelined_reads_out_of_order_seq extends axi_base_seq;
    `uvm_object_utils(pipelined_reads_out_of_order_seq)
    function new(string name = "pipelined_reads_out_of_order_seq");
      super.new(name);
    endfunction
    virtual task body();
      axi_seq_item items[5];
      `uvm_info("SEQ", "*** Pipelined Reads Out-of-Order (Different IDs) ***", UVM_LOW)
      foreach (items[i]) items[i] = axi_seq_item::type_id::create($sformatf("rd%0d", i));
      fork
        begin start_item(items[0]); assert(items[0].randomize() with { op == AXI_READ; addr == 32'h100; id == 1; in_order == 0; }); finish_item(items[0]); end
        begin start_item(items[1]); assert(items[1].randomize() with { op == AXI_READ; addr == 32'h200; id == 2; in_order == 0; }); finish_item(items[1]); end
        begin start_item(items[2]); assert(items[2].randomize() with { op == AXI_READ; addr == 32'h300; id == 3; in_order == 0; }); finish_item(items[2]); end
        begin start_item(items[3]); assert(items[3].randomize() with { op == AXI_READ; addr == 32'h400; id == 4; in_order == 0; }); finish_item(items[3]); end
        begin start_item(items[4]); assert(items[4].randomize() with { op == AXI_READ; addr == 32'h500; id == 5; in_order == 0; }); finish_item(items[4]); end
      join
    endtask
  endclass

  // Test 8: Random transactions
  class random_seq extends axi_base_seq;
    `uvm_object_utils(random_seq)
    int num = 20;
    function new(string name = "random_seq");
      super.new(name);
    endfunction
    virtual task body();
      axi_seq_item item;
      `uvm_info("SEQ", $sformatf("*** Random Transactions (%0d) ***", num), UVM_LOW)
      for (int i = 0; i < num; i++) begin
        item = axi_seq_item::type_id::create($sformatf("rand%0d", i));
        start_item(item);
        assert(item.randomize());
        finish_item(item);
      end
    endtask
  endclass

  //==========================================================================
  // AXI Test
  //==========================================================================
  class axi_test extends uvm_test;

    `uvm_component_utils(axi_test)

    axi_env env;

    function new(string name = "axi_test", uvm_component parent = null);
      super.new(name, parent);
    endfunction

    virtual function void build_phase(uvm_phase phase);
      super.build_phase(phase);
      env = axi_env::type_id::create("env", this);
    endfunction

    virtual task run_phase(uvm_phase phase);
      non_pipelined_writes_seq       seq1;
      pipelined_writes_seq           seq2;
      write_data_delayed_seq         seq3;
      write_addr_delayed_seq         seq4;
      non_pipelined_reads_seq        seq5;
      pipelined_reads_in_order_seq   seq6;
      pipelined_reads_out_of_order_seq seq7;
      random_seq                     seq8;

      phase.raise_objection(this);

      `uvm_info("TEST", "========================================", UVM_LOW)
      `uvm_info("TEST", "    AXI UVM Testbench - All Tests", UVM_LOW)
      `uvm_info("TEST", "========================================", UVM_LOW)

      seq1 = non_pipelined_writes_seq::type_id::create("seq1");
      seq1.start(env.agent.sequencer);
      #100;

      seq2 = pipelined_writes_seq::type_id::create("seq2");
      seq2.start(env.agent.sequencer);
      #100;

      seq3 = write_data_delayed_seq::type_id::create("seq3");
      seq3.start(env.agent.sequencer);
      #200;

      seq4 = write_addr_delayed_seq::type_id::create("seq4");
      seq4.start(env.agent.sequencer);
      #200;

      seq5 = non_pipelined_reads_seq::type_id::create("seq5");
      seq5.start(env.agent.sequencer);
      #100;

      seq6 = pipelined_reads_in_order_seq::type_id::create("seq6");
      seq6.start(env.agent.sequencer);
      #200;

      seq7 = pipelined_reads_out_of_order_seq::type_id::create("seq7");
      seq7.start(env.agent.sequencer);
      #200;

      seq8 = random_seq::type_id::create("seq8");
      seq8.start(env.agent.sequencer);
      #500;

      `uvm_info("TEST", "========================================", UVM_LOW)
      `uvm_info("TEST", "    All Tests Complete", UVM_LOW)
      `uvm_info("TEST", "========================================", UVM_LOW)

      phase.drop_objection(this);
    endtask

    virtual function void report_phase(uvm_phase phase);
      uvm_report_server svr = uvm_report_server::get_server();
      if (svr.get_severity_count(UVM_ERROR) == 0)
        `uvm_info("TEST", "*** TEST PASSED ***", UVM_LOW)
      else
        `uvm_info("TEST", "*** TEST FAILED ***", UVM_LOW)
    endfunction

  endclass

endpackage

//============================================================================
// Top-Level Testbench
//============================================================================
module tb_top;

  import uvm_pkg::*;
  `include "uvm_macros.svh"
  import axi_pkg::*;

  // Clock and reset
  logic clk = 1;
  logic rst = 1;

  always #50 clk = ~clk;

  initial begin
    rst = 1;
    repeat (3) @(posedge clk);
    rst = 0;
  end

  // AXI Interface
  axi_if #(.ADDR_WIDTH(32), .DATA_WIDTH(32), .ID_WIDTH(4)) axi_vif (.clk(clk), .rst(rst));

  // DUT (Reference Slave)
  axi_slave #(.ADDR_WIDTH(32), .DATA_WIDTH(32), .ID_WIDTH(4)) dut (
    .clk(clk), .rst(rst),
    .araddr(axi_vif.araddr), .arid(axi_vif.arid), .arvalid(axi_vif.arvalid), .arready(axi_vif.arready),
    .awaddr(axi_vif.awaddr), .awvalid(axi_vif.awvalid), .awready(axi_vif.awready),
    .wdata(axi_vif.wdata), .wvalid(axi_vif.wvalid), .wready(axi_vif.wready),
    .rdata(axi_vif.rdata), .rid(axi_vif.rid), .rvalid(axi_vif.rvalid), .rready(axi_vif.rready),
    .bvalid(axi_vif.bvalid), .bready(axi_vif.bready)
  );

  // UVM Test
  initial begin
    uvm_config_db#(virtual axi_if)::set(null, "uvm_test_top.env.agent.*", "vif", axi_vif);
    run_test("axi_test");
  end

  // Timeout
  initial begin
    #50000;
    `uvm_fatal("TIMEOUT", "Simulation timeout")
  end

endmodule
