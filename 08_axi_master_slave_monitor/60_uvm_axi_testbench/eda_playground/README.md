# EDA Playground Instructions

Run the UVM testbench online at https://edaplayground.com

## Quick Start

### Step 1: Go to EDA Playground
Open https://edaplayground.com and create a free account (or log in).

### Step 2: Configure Settings
- **Languages & Libraries**: Select `SystemVerilog/Verilog`
- **Simulator**: Select `Synopsys VCS` or `Cadence Xcelium`
- **UVM**: Check the `UVM 1.2` checkbox (IMPORTANT!)

### Step 3: Paste Code
- **Left Pane (Design)**: Copy contents of `design.sv`
- **Right Pane (Testbench)**: Copy contents of `testbench.sv`

### Step 4: Run
Click the **Run** button.

## Expected Output

The simulation will show all 8 test scenarios:

```
*** Non-Pipelined Writes ***
*** Pipelined Writes Back-to-Back ***
*** Write Data Delayed (Addresses Before Data) ***
*** Write Address Delayed (Data Before Address) ***
*** Non-Pipelined Reads ***
*** Pipelined Reads In-Order ***
*** Pipelined Reads Out-of-Order (Different IDs) ***
*** Random Transactions (20) ***
*** TEST PASSED ***
```

## Key Scenarios Demonstrated

### 1. Multiple Write Addresses Before Write Data
```
driver: write addr sent: AXI_WRITE addr='h700
driver: write addr sent: AXI_WRITE addr='h800
driver: write addr sent: AXI_WRITE addr='h900
driver: write data sent: AXI_WRITE addr='h700 data='h111
driver: write data sent: AXI_WRITE addr='h800 data='h222
driver: write data sent: AXI_WRITE addr='h900 data='h333
```

### 2. Write Data Before Write Address
```
driver: write data sent: AXI_WRITE addr='hA00 data='h444
driver: write data sent: AXI_WRITE addr='hB00 data='h555
driver: write addr sent: AXI_WRITE addr='hA00
driver: write addr sent: AXI_WRITE addr='hB00
```

### 3. Out-of-Order Read Data with ID Tags
```
driver: read addr sent: AXI_READ addr='h100 id=1
driver: read addr sent: AXI_READ addr='h200 id=2
driver: read addr sent: AXI_READ addr='h300 id=3
driver: read data rcvd: AXI_READ addr='h300 id=3  <- Out of order!
driver: read data rcvd: AXI_READ addr='h100 id=1
driver: read data rcvd: AXI_READ addr='h200 id=2
```

## Direct Link

You can save and share your EDA Playground simulation with others using the "Save" button.
