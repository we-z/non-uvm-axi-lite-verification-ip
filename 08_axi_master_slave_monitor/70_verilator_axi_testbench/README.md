# AXI-Lite Verilator Testbench

A Verilator + SystemC testbench demonstrating AXI-Lite protocol features on macOS (Apple Silicon).

## Features Demonstrated

1. **In-order pipelining for write transactions**
2. **Multiple write addresses before write data** - Addresses sent first, then data
3. **Write data before write address** - Data sent first, then addresses
4. **Out-of-order read responses based on ID tags** - Responses can return in any order

## Prerequisites

Make sure you have completed the Verilator/SystemC setup from the tutorial:
- Verilator installed and `VERILATOR_ROOT` set
- SystemC installed and `SYSTEMC_HOME` set
- CMake and Ninja installed

## Building

```bash
cd 08_axi_master_slave_monitor/70_verilator_axi_testbench

# Create build directory
mkdir build
cd build

# Configure with CMake
cmake -GNinja ..

# Build
ninja
```

## Running

```bash
./axi_tb
```

## Expected Output

```
========================================
  AXI-Lite Verilator Testbench
========================================

=== Reset Sequence ===

=== Test 1: Non-Pipelined Writes ===
...

=== Test 3: Write Addresses Before Data ===
Sending 3 addresses first...
master: write addr sent: addr=0x20
master: write addr sent: addr=0x24
master: write addr sent: addr=0x28
Now sending data...
master: write data sent: data=0xdead0001
master: write data sent: data=0xdead0002
master: write data sent: data=0xdead0003
...

=== Test 4: Write Data Before Address ===
Sending 3 data values first...
master: write data sent: data=0xbeef0001
master: write data sent: data=0xbeef0002
master: write data sent: data=0xbeef0003
Now sending addresses...
master: write addr sent: addr=0x30
master: write addr sent: addr=0x34
master: write addr sent: addr=0x38
...

=== Test 6: Out-of-Order Reads (Different IDs) ===
Sending 5 read addresses with different IDs...
master: read addr sent: addr=0x0 id=1
master: read addr sent: addr=0x4 id=2
master: read addr sent: addr=0x8 id=3
master: read addr sent: addr=0x10 id=4
master: read addr sent: addr=0x14 id=5
Receiving responses (may be out-of-order)...
master: read data received: id=3 ...   <- Out of order!
master: read data received: id=5 ...
master: read data received: id=1 ...
...

========================================
           Test Statistics
========================================
Writes sent:      12
Write responses:  12
Reads sent:       14
Read responses:   14
Read matches:     14
Read mismatches:  0
========================================
         *** TEST PASSED ***
========================================
```

## Viewing Waveforms

The testbench generates a VCD file that can be viewed with GTKWave:

```bash
gtkwave axi_tb.vcd
```

## File Structure

```
70_verilator_axi_testbench/
├── axi_slave.v      # Verilator-compatible AXI slave (DUT)
├── axi_tb.cpp       # SystemC/C++ testbench
├── CMakeLists.txt   # CMake build configuration
└── README.md        # This file
```

## Test Scenarios

| Test | Description |
|------|-------------|
| Test 1 | Non-pipelined writes (sequential) |
| Test 2 | Pipelined writes (back-to-back) |
| Test 3 | **Multiple addresses before data** |
| Test 4 | **Data before address** |
| Test 5 | Non-pipelined reads |
| Test 6 | **Out-of-order reads with different IDs** |
| Test 7 | Verify all written data |
