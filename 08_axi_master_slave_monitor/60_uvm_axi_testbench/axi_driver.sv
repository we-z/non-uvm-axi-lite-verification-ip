//----------------------------------------------------------------------------
//  AXI Driver (Master BFM)
//
//  UVM driver implementing AXI master functionality with:
//  - Pipelined write transactions
//  - Write address before/after write data support
//  - Out-of-order read response handling based on ID tags
//  - Configurable ready signal probabilities
//----------------------------------------------------------------------------

class axi_driver extends uvm_driver #(axi_seq_item);

  `uvm_component_utils(axi_driver)

  //--------------------------------------------------------------------------
  // Virtual Interface
  //--------------------------------------------------------------------------

  virtual axi_if vif;

  //--------------------------------------------------------------------------
  // Configuration
  //--------------------------------------------------------------------------

  int unsigned read_data_ready_probability      = 100;
  int unsigned write_response_ready_probability = 100;

  //--------------------------------------------------------------------------
  // Internal Queues and Scoreboards
  //--------------------------------------------------------------------------

  // Queues for pending transactions
  axi_seq_item rd_addr_queue[$];
  axi_seq_item wr_addr_queue[$];
  axi_seq_item wr_data_queue[$];

  // Arrays for tracking responses
  axi_seq_item rd_data_array[N_IDS][$];
  axi_seq_item wr_resp_queue[$];

  // Transaction completion tracking
  axi_seq_item pending_items[$];

  // Cycle counter for logging
  int unsigned cycle;

  //--------------------------------------------------------------------------
  // Constructor
  //--------------------------------------------------------------------------

  function new(string name = "axi_driver", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  //--------------------------------------------------------------------------
  // Build Phase
  //--------------------------------------------------------------------------

  virtual function void build_phase(uvm_phase phase);
    super.build_phase(phase);

    if (!uvm_config_db#(virtual axi_if)::get(this, "", "vif", vif))
      `uvm_fatal("NOVIF", "Virtual interface not found")
  endfunction

  //--------------------------------------------------------------------------
  // Reset Task
  //--------------------------------------------------------------------------

  virtual task reset_driver();
    // Clear all queues
    rd_addr_queue.delete();
    wr_addr_queue.delete();
    wr_data_queue.delete();

    for (int i = 0; i < N_IDS; i++)
      rd_data_array[i].delete();

    wr_resp_queue.delete();
    pending_items.delete();

    // Reset outputs
    vif.drv_cb.arvalid <= 0;
    vif.drv_cb.araddr  <= 'x;
    vif.drv_cb.arid    <= 'x;
    vif.drv_cb.awvalid <= 0;
    vif.drv_cb.awaddr  <= 'x;
    vif.drv_cb.wvalid  <= 0;
    vif.drv_cb.wdata   <= 'x;
    vif.drv_cb.rready  <= 0;
    vif.drv_cb.bready  <= 0;

    cycle = 0;
  endtask

  //--------------------------------------------------------------------------
  // Run Phase
  //--------------------------------------------------------------------------

  virtual task run_phase(uvm_phase phase);
    // Wait for reset to complete
    @(negedge vif.rst);
    reset_driver();

    // Fork parallel processes
    fork
      get_transactions();
      drive_read_address();
      drive_write_address();
      drive_write_data();
      handle_read_response();
      handle_write_response();
      update_ready_signals();
      increment_cycle();
    join
  endtask

  //--------------------------------------------------------------------------
  // Get Transactions from Sequencer
  //--------------------------------------------------------------------------

  virtual task get_transactions();
    axi_seq_item item;

    forever begin
      seq_item_port.get_next_item(item);

      `uvm_info("DRV", $sformatf("%0d driver: received transaction: %s",
                cycle, item.convert2string()), UVM_MEDIUM)

      // Add to appropriate queues based on operation type
      if (item.op == AXI_READ) begin
        rd_addr_queue.push_back(item);
      end else begin
        wr_addr_queue.push_back(item);
        wr_data_queue.push_back(item);
      end

      pending_items.push_back(item);
      seq_item_port.item_done();
    end
  endtask

  //--------------------------------------------------------------------------
  // Increment Cycle Counter
  //--------------------------------------------------------------------------

  virtual task increment_cycle();
    forever begin
      @(vif.drv_cb);
      if (!vif.rst)
        cycle++;
    end
  endtask

  //--------------------------------------------------------------------------
  // Drive Read Address Channel
  //--------------------------------------------------------------------------

  virtual task drive_read_address();
    axi_seq_item item;

    forever begin
      @(vif.drv_cb);

      if (vif.rst) begin
        vif.drv_cb.arvalid <= 0;
        vif.drv_cb.araddr  <= 'x;
        vif.drv_cb.arid    <= 'x;
        continue;
      end

      // Check for successful transmission
      if (vif.drv_cb.arvalid && vif.drv_cb.arready) begin
        item = rd_addr_queue.pop_front();
        rd_data_array[item.id].push_back(item);
        `uvm_info("DRV", $sformatf("%0d driver: read address transmitted: %s",
                  cycle, item.convert2string()), UVM_MEDIUM)
      end

      // Drive next address
      vif.drv_cb.arvalid <= 0;
      vif.drv_cb.araddr  <= 'x;
      vif.drv_cb.arid    <= 'x;

      if (rd_addr_queue.size() > 0) begin
        item = rd_addr_queue[0];

        if (item.addr_delay > 0) begin
          item.addr_delay--;
        end else begin
          vif.drv_cb.arvalid <= 1;
          vif.drv_cb.araddr  <= item.addr;
          vif.drv_cb.arid    <= item.id;
          `uvm_info("DRV", $sformatf("%0d driver: started read address: %s",
                    cycle, item.convert2string()), UVM_HIGH)
        end
      end
    end
  endtask

  //--------------------------------------------------------------------------
  // Drive Write Address Channel
  //--------------------------------------------------------------------------

  virtual task drive_write_address();
    axi_seq_item item;

    forever begin
      @(vif.drv_cb);

      if (vif.rst) begin
        vif.drv_cb.awvalid <= 0;
        vif.drv_cb.awaddr  <= 'x;
        continue;
      end

      // Check for successful transmission
      if (vif.drv_cb.awvalid && vif.drv_cb.awready) begin
        item = wr_addr_queue.pop_front();
        item.addr_is_sent = 1;

        // If data not sent yet, add to response queue
        if (!item.data_is_sent)
          wr_resp_queue.push_back(item);

        `uvm_info("DRV", $sformatf("%0d driver: write address transmitted: %s",
                  cycle, item.convert2string()), UVM_MEDIUM)
      end

      // Drive next address
      vif.drv_cb.awvalid <= 0;
      vif.drv_cb.awaddr  <= 'x;

      if (wr_addr_queue.size() > 0) begin
        item = wr_addr_queue[0];

        if (item.addr_delay > 0) begin
          item.addr_delay--;
        end else begin
          vif.drv_cb.awvalid <= 1;
          vif.drv_cb.awaddr  <= item.addr;
          `uvm_info("DRV", $sformatf("%0d driver: started write address: %s",
                    cycle, item.convert2string()), UVM_HIGH)
        end
      end
    end
  endtask

  //--------------------------------------------------------------------------
  // Drive Write Data Channel
  //--------------------------------------------------------------------------

  virtual task drive_write_data();
    axi_seq_item item;

    forever begin
      @(vif.drv_cb);

      if (vif.rst) begin
        vif.drv_cb.wvalid <= 0;
        vif.drv_cb.wdata  <= 'x;
        continue;
      end

      // Check for successful transmission
      if (vif.drv_cb.wvalid && vif.drv_cb.wready) begin
        item = wr_data_queue.pop_front();
        item.data_is_sent = 1;

        // If address not sent yet, add to response queue
        if (!item.addr_is_sent)
          wr_resp_queue.push_back(item);

        `uvm_info("DRV", $sformatf("%0d driver: write data transmitted: %s",
                  cycle, item.convert2string()), UVM_MEDIUM)
      end

      // Drive next data
      vif.drv_cb.wvalid <= 0;
      vif.drv_cb.wdata  <= 'x;

      if (wr_data_queue.size() > 0) begin
        item = wr_data_queue[0];

        if (item.data_delay > 0) begin
          item.data_delay--;
        end else begin
          vif.drv_cb.wvalid <= 1;
          vif.drv_cb.wdata  <= item.data;
          `uvm_info("DRV", $sformatf("%0d driver: started write data: %s",
                    cycle, item.convert2string()), UVM_HIGH)
        end
      end
    end
  endtask

  //--------------------------------------------------------------------------
  // Handle Read Response (Out-of-Order Based on ID)
  //--------------------------------------------------------------------------

  virtual task handle_read_response();
    axi_seq_item item;
    id_t received_id;

    forever begin
      @(vif.drv_cb);

      if (vif.rst)
        continue;

      if (vif.drv_cb.rvalid && vif.drv_cb.rready) begin
        received_id = vif.drv_cb.rid;

        if (rd_data_array[received_id].size() == 0) begin
          `uvm_error("DRV", $sformatf("%0d driver: Unexpected read data for ID=%0d",
                     cycle, received_id))
        end else begin
          item = rd_data_array[received_id].pop_front();
          item.data = vif.drv_cb.rdata;
          item.data_is_set = 1;

          `uvm_info("DRV", $sformatf("%0d driver: received read data: %s",
                    cycle, item.convert2string()), UVM_MEDIUM)

          // Mark transaction as complete
          complete_transaction(item);
        end
      end
    end
  endtask

  //--------------------------------------------------------------------------
  // Handle Write Response
  //--------------------------------------------------------------------------

  virtual task handle_write_response();
    axi_seq_item item;

    forever begin
      @(vif.drv_cb);

      if (vif.rst)
        continue;

      if (vif.drv_cb.bvalid && vif.drv_cb.bready) begin
        if (wr_resp_queue.size() == 0) begin
          `uvm_error("DRV", $sformatf("%0d driver: Unexpected write response", cycle))
        end else begin
          item = wr_resp_queue.pop_front();

          `uvm_info("DRV", $sformatf("%0d driver: received write response: %s",
                    cycle, item.convert2string()), UVM_MEDIUM)

          if (!item.addr_is_sent)
            `uvm_error("DRV", $sformatf("Write response received before address sent: %s",
                       item.convert2string()))

          if (!item.data_is_sent)
            `uvm_error("DRV", $sformatf("Write response received before data sent: %s",
                       item.convert2string()))

          // Mark transaction as complete
          complete_transaction(item);
        end
      end
    end
  endtask

  //--------------------------------------------------------------------------
  // Update Ready Signals with Randomization
  //--------------------------------------------------------------------------

  virtual task update_ready_signals();
    forever begin
      @(vif.drv_cb);

      if (vif.rst) begin
        vif.drv_cb.rready <= 0;
        vif.drv_cb.bready <= 0;
      end else begin
        vif.drv_cb.rready <= ($urandom_range(0, 99) < read_data_ready_probability);
        vif.drv_cb.bready <= ($urandom_range(0, 99) < write_response_ready_probability);
      end
    end
  endtask

  //--------------------------------------------------------------------------
  // Complete Transaction (Remove from Pending)
  //--------------------------------------------------------------------------

  virtual function void complete_transaction(axi_seq_item item);
    int idx[$];

    idx = pending_items.find_first_index(x) with (x == item);
    if (idx.size() > 0)
      pending_items.delete(idx[0]);
  endfunction

  //--------------------------------------------------------------------------
  // Reset Probabilities
  //--------------------------------------------------------------------------

  virtual function void reset_probabilities();
    read_data_ready_probability      = 100;
    write_response_ready_probability = 100;
  endfunction

endclass
