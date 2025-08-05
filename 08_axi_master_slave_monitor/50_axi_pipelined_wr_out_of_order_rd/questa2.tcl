onerror { exit }
vlib work
vlog ../axi_transaction.sv
vlog ../axi_master.sv ../axi_monitor.sv ../axi_slave.sv ../axi_testbench.sv
vsim work.axi_testbench
onfinish exit
run -all
