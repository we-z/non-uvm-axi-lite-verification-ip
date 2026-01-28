#!/bin/bash
#------------------------------------------------------------------------------
# AXI UVM Testbench Simulation Script for Synopsys VCS
#
# Usage:
#   ./03_simulate_vcs.bash                    # Run default test (axi_all_tests)
#   ./03_simulate_vcs.bash axi_random_test    # Run specific test
#------------------------------------------------------------------------------

# Default test name
TEST_NAME=${1:-axi_all_tests}

echo "=============================================="
echo " AXI UVM Testbench (VCS)"
echo " Running test: $TEST_NAME"
echo "=============================================="

# Compile
vcs -full64 -sverilog -ntb_opts uvm-1.2 \
    -timescale=1ns/1ps \
    +incdir+$UVM_HOME/src \
    axi_if.sv \
    axi_slave.sv \
    axi_pkg.sv \
    axi_tb_top.sv \
    -o simv

# Run simulation
./simv +UVM_TESTNAME=$TEST_NAME +UVM_VERBOSITY=UVM_MEDIUM

echo "=============================================="
echo " Simulation Complete"
echo "=============================================="
