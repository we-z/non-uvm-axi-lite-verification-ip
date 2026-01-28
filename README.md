# AXI-Lite Verification IP

Non-UVM and UVM AXI-Lite Verification IP. Started as an educational example in the older Valid-Ready-Etc repo for the Digital Circuit Synthesis School.

## UVM Testbench

A complete UVM testbench has been added that converts the original non-UVM example to UVM methodology.

### Location

```
08_axi_master_slave_monitor/60_uvm_axi_testbench/
```

### Features

The UVM testbench supports all scenarios from the challenge:

1. **In-order pipelining for write transactions** - Multiple write addresses issued before write data
2. **Write address before write data** - Address channel completes before data channel
3. **Write data before write address** - Data channel completes before address channel
4. **Address and data in the same cycle** - Simultaneous valid signals
5. **Out-of-order read responses based on ID tags** - Responses matched by transaction ID
6. **Configurable valid/ready handshake** - Randomized backpressure

### UVM Components

| Component | Description |
|-----------|-------------|
| `axi_seq_item.sv` | Transaction class with constrained randomization |
| `axi_driver.sv` | Master BFM with pipelining and out-of-order support |
| `axi_monitor.sv` | Passive monitor (implemented from scratch) |
| `axi_scoreboard.sv` | Reference memory model for verification |
| `axi_sequences.sv` | 8 directed test sequences |
| `axi_test.sv` | Multiple UVM test classes |

### Test Sequences

- `non_pipelined_writes_seq` - Sequential writes
- `pipelined_writes_seq` - Back-to-back pipelined writes
- `write_data_delayed_seq` - Multiple addresses before data
- `write_addr_delayed_seq` - Data before address
- `non_pipelined_reads_seq` - Sequential reads
- `pipelined_reads_in_order_seq` - Pipelined reads (ID=0)
- `pipelined_reads_out_of_order_seq` - Out-of-order reads (different IDs)
- `random_transactions_seq` - Randomized transactions

---

## Running the UVM Simulation

### Prerequisites

- UVM 1.2 library (typically included with commercial simulators)
- One of: Questa/ModelSim, VCS, or Xcelium

### Quick Start

```bash
cd 08_axi_master_slave_monitor/60_uvm_axi_testbench
```

#### Questa/ModelSim

```bash
# Run all tests
./02_simulate_rtl.bash

# Run specific test
./02_simulate_rtl.bash axi_all_tests
./02_simulate_rtl.bash axi_out_of_order_reads_test
./02_simulate_rtl.bash axi_random_test
```

#### Synopsys VCS

```bash
./03_simulate_vcs.bash axi_all_tests
```

#### Cadence Xcelium

```bash
./04_simulate_xcelium.bash axi_all_tests
```

### Available Tests

| Test Name | Description |
|-----------|-------------|
| `axi_all_tests` | Runs complete test suite (default) |
| `axi_non_pipelined_writes_test` | Sequential writes only |
| `axi_pipelined_writes_test` | Pipelined writes |
| `axi_write_data_delayed_test` | Address before data |
| `axi_write_addr_delayed_test` | Data before address |
| `axi_out_of_order_reads_test` | Out-of-order read responses |
| `axi_random_test` | 100 random transactions |

### Manual Compilation

If you need to compile manually:

```bash
# Set UVM_HOME to your UVM installation
export UVM_HOME=/path/to/uvm-1.2

# Compile (example for Questa)
vlib work
vlog -sv +incdir+$UVM_HOME/src \
    $UVM_HOME/src/uvm_pkg.sv \
    axi_if.sv \
    axi_slave.sv \
    axi_pkg.sv \
    axi_tb_top.sv

# Run
vsim -c work.axi_tb_top \
    +UVM_TESTNAME=axi_all_tests \
    +UVM_VERBOSITY=UVM_MEDIUM \
    -do "run -all"
```

---

## Expected Simulation Output

The simulation demonstrates the three key scenarios:

### 1. Multiple Write Addresses Before Write Data

```
driver: started write address: AXI_WRITE addr='h700
driver: started write address: AXI_WRITE addr='h800
driver: started write address: AXI_WRITE addr='h900
driver: started write data: AXI_WRITE addr='h700 d='h00000123
driver: started write data: AXI_WRITE addr='h800 d='h00000456
driver: started write data: AXI_WRITE addr='h900 d='h00000789
```

### 2. Write Data Before Write Address

```
driver: started write data: AXI_WRITE addr='hA00 d='h00000123
driver: started write data: AXI_WRITE addr='hB00 d='h00000456
driver: started write address: AXI_WRITE addr='hA00
driver: started write address: AXI_WRITE addr='hB00
```

### 3. Out-of-Order Read Data with ID Tags

```
driver: read address transmitted: AXI_READ addr='h100 id=1
driver: read address transmitted: AXI_READ addr='h200 id=2
driver: read address transmitted: AXI_READ addr='h300 id=3
driver: received read data: AXI_READ addr='h300 id=3 d='h00000789
driver: received read data: AXI_READ addr='h100 id=1 d='h00000123
driver: received read data: AXI_READ addr='h200 id=2 d='h00000456
```

---

## File Structure

```
non-uvm-axi-lite-verification-ip/
├── README.md
├── 08_axi_master_slave_monitor/
│   ├── 50_axi_pipelined_wr_out_of_order_rd/   # Original non-UVM
│   │   ├── axi_transaction.sv
│   │   ├── axi_master.sv
│   │   ├── axi_slave.sv
│   │   ├── axi_monitor.sv
│   │   └── axi_testbench.sv
│   └── 60_uvm_axi_testbench/                  # UVM conversion
│       ├── axi_pkg.sv
│       ├── axi_if.sv
│       ├── axi_seq_item.sv
│       ├── axi_sequencer.sv
│       ├── axi_driver.sv
│       ├── axi_monitor.sv
│       ├── axi_scoreboard.sv
│       ├── axi_agent.sv
│       ├── axi_env.sv
│       ├── axi_sequences.sv
│       ├── axi_test.sv
│       ├── axi_slave.sv
│       ├── axi_tb_top.sv
│       └── *.bash (simulation scripts)
└── scripts/
```

---

## Credits

- Original non-UVM example by Yuri Panchul
- UVM conversion created as response to the Verilog Meetup AI challenge
