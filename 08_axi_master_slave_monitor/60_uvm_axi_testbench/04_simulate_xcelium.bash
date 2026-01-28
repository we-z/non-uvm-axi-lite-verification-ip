#!/bin/bash
#------------------------------------------------------------------------------
# AXI UVM Testbench Simulation Script for Cadence Xcelium
#
# Usage:
#   ./04_simulate_xcelium.bash                    # Run default test (axi_all_tests)
#   ./04_simulate_xcelium.bash axi_random_test    # Run specific test
#------------------------------------------------------------------------------

# Default test name
TEST_NAME=${1:-axi_all_tests}

echo "=============================================="
echo " AXI UVM Testbench (Xcelium)"
echo " Running test: $TEST_NAME"
echo "=============================================="

# Run simulation (single-step compile and run)
xrun -sv -uvm \
    -timescale 1ns/1ps \
    +incdir+$UVM_HOME/src \
    axi_if.sv \
    axi_slave.sv \
    axi_pkg.sv \
    axi_tb_top.sv \
    +UVM_TESTNAME=$TEST_NAME \
    +UVM_VERBOSITY=UVM_MEDIUM

echo "=============================================="
echo " Simulation Complete"
echo "=============================================="
