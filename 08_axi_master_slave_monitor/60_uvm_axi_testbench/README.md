# UVM AXI-Lite Verification IP

This is a UVM conversion of the non-UVM AXI-Lite Verification IP example.

## Features

The UVM testbench supports:

1. **In-order pipelining for write transactions** - Multiple write addresses can be issued before write data arrives
2. **Write address before write data** - Address channel completes before data channel
3. **Write data before write address** - Data channel completes before address channel
4. **Address and data in the same cycle** - Simultaneous valid signals
5. **Out-of-order read responses based on ID tags** - Responses can return in any order, matched by ID
6. **Configurable ready signal probabilities** - Randomized backpressure testing

## File Structure

```
60_uvm_axi_testbench/
├── axi_pkg.sv          # UVM package with all type definitions and includes
├── axi_if.sv           # AXI interface with clocking blocks
├── axi_seq_item.sv     # UVM sequence item (transaction)
├── axi_sequencer.sv    # UVM sequencer
├── axi_driver.sv       # UVM driver (master BFM)
├── axi_monitor.sv      # UVM monitor (passive)
├── axi_scoreboard.sv   # UVM scoreboard with reference memory
├── axi_agent.sv        # UVM agent
├── axi_env.sv          # UVM environment
├── axi_sequences.sv    # UVM sequences for all test scenarios
├── axi_test.sv         # UVM test classes
├── axi_slave.sv        # Reference slave (DUT)
├── axi_tb_top.sv       # Top-level testbench
├── filelist.f          # File compilation list
├── 01_clean.bash       # Cleanup script
├── 02_simulate_rtl.bash    # Questa/ModelSim simulation
├── 03_simulate_vcs.bash    # VCS simulation
├── 04_simulate_xcelium.bash # Xcelium simulation
└── questa.tcl          # Questa TCL script
```

## Test Scenarios

The following test sequences are implemented:

1. **non_pipelined_writes_seq** - Sequential writes, each completes before next
2. **pipelined_writes_seq** - Back-to-back pipelined writes
3. **write_data_delayed_seq** - Multiple addresses before multiple data
4. **write_addr_delayed_seq** - Data before address (reversed timing)
5. **non_pipelined_reads_seq** - Sequential reads
6. **pipelined_reads_in_order_seq** - Pipelined reads with ID=0 (in-order)
7. **pipelined_reads_out_of_order_seq** - Pipelined reads with different IDs (out-of-order)
8. **random_transactions_seq** - Fully randomized transactions

## Available Tests

- `axi_all_tests` - Runs all test sequences (default)
- `axi_non_pipelined_writes_test` - Only non-pipelined writes
- `axi_pipelined_writes_test` - Pipelined writes test
- `axi_write_data_delayed_test` - Write with data delayed
- `axi_write_addr_delayed_test` - Write with address delayed
- `axi_out_of_order_reads_test` - Out-of-order read test
- `axi_random_test` - Random transactions test

## Running Simulations

### Questa/ModelSim
```bash
./02_simulate_rtl.bash                    # Run default test
./02_simulate_rtl.bash axi_random_test    # Run specific test
```

### VCS
```bash
./03_simulate_vcs.bash                    # Run default test
./03_simulate_vcs.bash axi_random_test    # Run specific test
```

### Xcelium
```bash
./04_simulate_xcelium.bash                # Run default test
./04_simulate_xcelium.bash axi_random_test # Run specific test
```

## Expected Output

The simulation log should demonstrate:

1. **Multiple write addresses before multiple write data:**
```
driver: started write address: AXI_WRITE addr='h700
driver: started write address: AXI_WRITE addr='h800
driver: started write address: AXI_WRITE addr='h900
driver: started write data: AXI_WRITE addr='h700 d='h00000123
driver: started write data: AXI_WRITE addr='h800 d='h00000456
driver: started write data: AXI_WRITE addr='h900 d='h00000789
```

2. **Write data before write address:**
```
driver: started write data: AXI_WRITE addr='hA00 d='h00000123
driver: started write data: AXI_WRITE addr='hB00 d='h00000456
driver: started write address: AXI_WRITE addr='hA00
driver: started write address: AXI_WRITE addr='hB00
```

3. **Out-of-order read data with ID tags:**
```
driver: read address transmitted: AXI_READ addr='h100 id=1
driver: read address transmitted: AXI_READ addr='h200 id=2
driver: read address transmitted: AXI_READ addr='h300 id=3
driver: received read data: AXI_READ addr='h300 id=3 d='h00000789
driver: received read data: AXI_READ addr='h100 id=1 d='h00000123
driver: received read data: AXI_READ addr='h200 id=2 d='h00000456
```

## UVM Components

### Driver (axi_driver.sv)
The driver implements a full AXI master BFM with:
- Separate processes for each channel (AR, AW, W, R, B)
- Transaction queues for pipelining
- ID-based tracking for out-of-order read responses
- Configurable ready signal probabilities

### Monitor (axi_monitor.sv)
The passive monitor:
- Observes all AXI channels
- Reconstructs complete transactions
- Handles out-of-order read responses using ID matching
- Publishes transactions via analysis ports

### Scoreboard (axi_scoreboard.sv)
The scoreboard:
- Maintains a reference memory model
- Verifies read data against expected values
- Reports pass/fail status

### Sequences (axi_sequences.sv)
Each sequence demonstrates specific AXI protocol scenarios with directed tests rather than purely random testing.
