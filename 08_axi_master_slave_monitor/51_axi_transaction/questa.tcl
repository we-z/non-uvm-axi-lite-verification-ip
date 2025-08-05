onerror { exit }
vlib work
vlog ../axi_transaction.sv
vlog ../axi_testbench.sv
vsim work.axi_testbench
onfinish exit
run -all
