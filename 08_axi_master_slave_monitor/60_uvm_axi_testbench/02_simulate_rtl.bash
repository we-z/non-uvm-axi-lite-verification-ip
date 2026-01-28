#!/bin/bash
#------------------------------------------------------------------------------
# AXI UVM Testbench Simulation Script for Questa/ModelSim
#
# Usage:
#   ./02_simulate_rtl.bash                    # Run default test (axi_all_tests)
#   ./02_simulate_rtl.bash axi_random_test    # Run specific test
#------------------------------------------------------------------------------

# Default test name
TEST_NAME=${1:-axi_all_tests}

echo "=============================================="
echo " AXI UVM Testbench"
echo " Running test: $TEST_NAME"
echo "=============================================="

# Create work library
vlib work

# Compile UVM package and testbench files
vlog -sv \
    +incdir+$UVM_HOME/src \
    $UVM_HOME/src/uvm_pkg.sv \
    axi_if.sv \
    axi_slave.sv \
    axi_pkg.sv \
    axi_tb_top.sv

# Run simulation
vsim -c work.axi_tb_top \
    +UVM_TESTNAME=$TEST_NAME \
    +UVM_VERBOSITY=UVM_MEDIUM \
    -do "run -all; quit"

echo "=============================================="
echo " Simulation Complete"
echo "=============================================="
