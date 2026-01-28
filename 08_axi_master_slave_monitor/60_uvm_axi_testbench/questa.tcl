#------------------------------------------------------------------------------
# Questa/ModelSim TCL Script for AXI UVM Testbench
#
# Usage:
#   vsim -do questa.tcl
#   vsim -do "set TEST_NAME axi_random_test; source questa.tcl"
#------------------------------------------------------------------------------

# Default test name if not set
if {![info exists TEST_NAME]} {
    set TEST_NAME "axi_all_tests"
}

puts "=============================================="
puts " AXI UVM Testbench"
puts " Running test: $TEST_NAME"
puts "=============================================="

# Create work library
vlib work

# Compile files
vlog -sv +incdir+$::env(UVM_HOME)/src \
    $::env(UVM_HOME)/src/uvm_pkg.sv \
    axi_if.sv \
    axi_slave.sv \
    axi_pkg.sv \
    axi_tb_top.sv

# Load design
vsim work.axi_tb_top \
    +UVM_TESTNAME=$TEST_NAME \
    +UVM_VERBOSITY=UVM_MEDIUM

# Add waves (optional)
# add wave -recursive /*

# Run simulation
run -all

puts "=============================================="
puts " Simulation Complete"
puts "=============================================="
