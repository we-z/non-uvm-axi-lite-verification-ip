onerror { quit -f }

vlib work
vlog ../axi_transaction.sv
vlog ../axi_master.sv ../axi_monitor.sv ../axi_slave.sv ../axi_testbench.sv
vsim -voptargs="+acc" work.axi_testbench

onerror ""

add wave            sim:/axi_testbench/clk
add wave            sim:/axi_testbench/rst
add wave            sim:/axi_testbench/arvalid
add wave            sim:/axi_testbench/arready
add wave -radix hex sim:/axi_testbench/araddr
add wave            sim:/axi_testbench/arid
add wave            sim:/axi_testbench/awvalid
add wave            sim:/axi_testbench/awready
add wave -radix hex sim:/axi_testbench/awaddr
add wave            sim:/axi_testbench/wvalid
add wave            sim:/axi_testbench/wready
add wave -radix hex sim:/axi_testbench/wdata
add wave            sim:/axi_testbench/rvalid
add wave            sim:/axi_testbench/rready
add wave -radix hex sim:/axi_testbench/rdata
add wave            sim:/axi_testbench/bvalid
add wave            sim:/axi_testbench/bready

onfinish final
run -all

wave zoom full
