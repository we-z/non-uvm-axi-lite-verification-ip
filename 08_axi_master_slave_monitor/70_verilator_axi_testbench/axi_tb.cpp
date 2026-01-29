//============================================================================
// AXI-Lite Testbench (Verilator + SystemC)
//
// Demonstrates:
// 1. In-order pipelining for write transactions
// 2. Write address before write data (multiple addresses before data)
// 3. Write data before write address
// 4. Out-of-order read responses based on ID tags
//============================================================================

#include <systemc.h>
#include <verilated.h>
#include <verilated_vcd_sc.h>

#include "Vaxi_slave.h"

#include <iostream>
#include <queue>
#include <map>
#include <iomanip>

//============================================================================
// AXI Master BFM Class
//============================================================================
class AXIMaster {
public:
    // Signals
    sc_signal<uint32_t>& araddr;
    sc_signal<uint32_t>& arid;
    sc_signal<bool>&     arvalid;
    sc_signal<bool>&     arready;

    sc_signal<uint32_t>& awaddr;
    sc_signal<bool>&     awvalid;
    sc_signal<bool>&     awready;

    sc_signal<uint32_t>& wdata;
    sc_signal<bool>&     wvalid;
    sc_signal<bool>&     wready;

    sc_signal<uint32_t>& rdata;
    sc_signal<uint32_t>& rid;
    sc_signal<bool>&     rvalid;
    sc_signal<bool>&     rready;

    sc_signal<bool>&     bvalid;
    sc_signal<bool>&     bready;

    sc_clock& clk;

    // Reference memory for checking
    std::map<uint32_t, uint32_t> ref_memory;

    // Pending read tracking by ID
    std::map<uint32_t, std::queue<uint32_t>> pending_reads;  // id -> addresses

    // Statistics
    int writes_sent = 0;
    int reads_sent = 0;
    int write_responses = 0;
    int read_responses = 0;
    int read_matches = 0;
    int read_mismatches = 0;

    AXIMaster(
        sc_signal<uint32_t>& _araddr, sc_signal<uint32_t>& _arid,
        sc_signal<bool>& _arvalid, sc_signal<bool>& _arready,
        sc_signal<uint32_t>& _awaddr, sc_signal<bool>& _awvalid, sc_signal<bool>& _awready,
        sc_signal<uint32_t>& _wdata, sc_signal<bool>& _wvalid, sc_signal<bool>& _wready,
        sc_signal<uint32_t>& _rdata, sc_signal<uint32_t>& _rid,
        sc_signal<bool>& _rvalid, sc_signal<bool>& _rready,
        sc_signal<bool>& _bvalid, sc_signal<bool>& _bready,
        sc_clock& _clk
    ) : araddr(_araddr), arid(_arid), arvalid(_arvalid), arready(_arready),
        awaddr(_awaddr), awvalid(_awvalid), awready(_awready),
        wdata(_wdata), wvalid(_wvalid), wready(_wready),
        rdata(_rdata), rid(_rid), rvalid(_rvalid), rready(_rready),
        bvalid(_bvalid), bready(_bready), clk(_clk)
    {
        // Initialize outputs
        arvalid.write(false);
        awvalid.write(false);
        wvalid.write(false);
        rready.write(true);
        bready.write(true);
    }

    void wait_clocks(int n) {
        for (int i = 0; i < n; i++) {
            sc_start(1, SC_NS);
        }
    }

    //------------------------------------------------------------------------
    // Send Write Address (non-blocking)
    //------------------------------------------------------------------------
    void send_write_addr(uint32_t addr) {
        awaddr.write(addr);
        awvalid.write(true);

        // Wait for handshake
        do {
            sc_start(1, SC_NS);
        } while (!awready.read());

        std::cout << sc_time_stamp() << " master: write addr sent: addr=0x"
                  << std::hex << addr << std::dec << std::endl;

        awvalid.write(false);
    }

    //------------------------------------------------------------------------
    // Send Write Data (non-blocking)
    //------------------------------------------------------------------------
    void send_write_data(uint32_t data) {
        wdata.write(data);
        wvalid.write(true);

        // Wait for handshake
        do {
            sc_start(1, SC_NS);
        } while (!wready.read());

        std::cout << sc_time_stamp() << " master: write data sent: data=0x"
                  << std::hex << data << std::dec << std::endl;

        wvalid.write(false);
    }

    //------------------------------------------------------------------------
    // Complete Write (blocking - wait for response)
    //------------------------------------------------------------------------
    void complete_write(uint32_t addr, uint32_t data) {
        ref_memory[addr] = data;
        writes_sent++;

        // Wait for write response
        while (!bvalid.read() || !bready.read()) {
            sc_start(1, SC_NS);
        }
        sc_start(1, SC_NS);
        write_responses++;
        std::cout << sc_time_stamp() << " master: write response received" << std::endl;
    }

    //------------------------------------------------------------------------
    // Simple blocking write
    //------------------------------------------------------------------------
    void write(uint32_t addr, uint32_t data) {
        send_write_addr(addr);
        send_write_data(data);
        complete_write(addr, data);
    }

    //------------------------------------------------------------------------
    // Send Read Address (non-blocking)
    //------------------------------------------------------------------------
    void send_read_addr(uint32_t addr, uint32_t id = 0) {
        araddr.write(addr);
        arid.write(id);
        arvalid.write(true);

        // Wait for handshake
        do {
            sc_start(1, SC_NS);
        } while (!arready.read());

        std::cout << sc_time_stamp() << " master: read addr sent: addr=0x"
                  << std::hex << addr << std::dec << " id=" << id << std::endl;

        arvalid.write(false);
        pending_reads[id].push(addr);
        reads_sent++;
    }

    //------------------------------------------------------------------------
    // Receive Read Data (blocking - waits for response)
    //------------------------------------------------------------------------
    uint32_t receive_read_data() {
        // Wait for valid read data
        while (!rvalid.read() || !rready.read()) {
            sc_start(1, SC_NS);
        }

        uint32_t data = rdata.read();
        uint32_t id = rid.read();
        uint32_t addr = 0;

        if (!pending_reads[id].empty()) {
            addr = pending_reads[id].front();
            pending_reads[id].pop();
        }

        std::cout << sc_time_stamp() << " master: read data received: id=" << id
                  << " addr=0x" << std::hex << addr
                  << " data=0x" << data << std::dec << std::endl;

        // Check against reference
        if (ref_memory.count(addr)) {
            if (ref_memory[addr] == data) {
                read_matches++;
            } else {
                read_mismatches++;
                std::cout << "  ERROR: Expected 0x" << std::hex << ref_memory[addr]
                          << " got 0x" << data << std::dec << std::endl;
            }
        }

        read_responses++;
        sc_start(1, SC_NS);
        return data;
    }

    //------------------------------------------------------------------------
    // Simple blocking read
    //------------------------------------------------------------------------
    uint32_t read(uint32_t addr, uint32_t id = 0) {
        send_read_addr(addr, id);
        return receive_read_data();
    }

    //------------------------------------------------------------------------
    // Print statistics
    //------------------------------------------------------------------------
    void print_stats() {
        std::cout << "\n========================================" << std::endl;
        std::cout << "           Test Statistics" << std::endl;
        std::cout << "========================================" << std::endl;
        std::cout << "Writes sent:      " << writes_sent << std::endl;
        std::cout << "Write responses:  " << write_responses << std::endl;
        std::cout << "Reads sent:       " << reads_sent << std::endl;
        std::cout << "Read responses:   " << read_responses << std::endl;
        std::cout << "Read matches:     " << read_matches << std::endl;
        std::cout << "Read mismatches:  " << read_mismatches << std::endl;
        std::cout << "========================================" << std::endl;
        if (read_mismatches == 0) {
            std::cout << "         *** TEST PASSED ***" << std::endl;
        } else {
            std::cout << "         *** TEST FAILED ***" << std::endl;
        }
        std::cout << "========================================\n" << std::endl;
    }
};

//============================================================================
// Main Testbench
//============================================================================
int sc_main(int argc, char** argv) {
    Verilated::commandArgs(argc, argv);
    Verilated::traceEverOn(true);

    std::cout << "\n========================================" << std::endl;
    std::cout << "  AXI-Lite Verilator Testbench" << std::endl;
    std::cout << "========================================\n" << std::endl;

    // Clock (1ns period)
    sc_clock clk("clk", 1, SC_NS, 0.5, 0, SC_NS, true);
    sc_signal<bool> rst;

    // AXI Signals
    sc_signal<uint32_t> araddr, arid, awaddr, wdata, rdata, rid;
    sc_signal<bool> arvalid, arready, awvalid, awready;
    sc_signal<bool> wvalid, wready, rvalid, rready, bvalid, bready;

    // Instantiate DUT
    const std::unique_ptr<Vaxi_slave> dut{new Vaxi_slave{"dut"}};

    dut->clk(clk);
    dut->rst(rst);
    dut->araddr(araddr);
    dut->arid(arid);
    dut->arvalid(arvalid);
    dut->arready(arready);
    dut->awaddr(awaddr);
    dut->awvalid(awvalid);
    dut->awready(awready);
    dut->wdata(wdata);
    dut->wvalid(wvalid);
    dut->wready(wready);
    dut->rdata(rdata);
    dut->rid(rid);
    dut->rvalid(rvalid);
    dut->rready(rready);
    dut->bvalid(bvalid);
    dut->bready(bready);

    // Create master BFM
    AXIMaster master(araddr, arid, arvalid, arready,
                     awaddr, awvalid, awready,
                     wdata, wvalid, wready,
                     rdata, rid, rvalid, rready,
                     bvalid, bready, clk);

    // Setup VCD trace
    sc_start(0, SC_NS);
    VerilatedVcdSc* trace = new VerilatedVcdSc();
    dut->trace(trace, 99);
    trace->open("axi_tb.vcd");

    //------------------------------------------------------------------------
    // Reset
    //------------------------------------------------------------------------
    std::cout << "=== Reset Sequence ===" << std::endl;
    rst.write(true);
    sc_start(5, SC_NS);
    rst.write(false);
    sc_start(5, SC_NS);

    //------------------------------------------------------------------------
    // Test 1: Non-pipelined writes
    //------------------------------------------------------------------------
    std::cout << "\n=== Test 1: Non-Pipelined Writes ===" << std::endl;
    master.write(0x00, 0x11111111);
    master.write(0x04, 0x22222222);
    master.write(0x08, 0x33333333);
    sc_start(10, SC_NS);

    //------------------------------------------------------------------------
    // Test 2: Pipelined writes (back-to-back addresses)
    //------------------------------------------------------------------------
    std::cout << "\n=== Test 2: Pipelined Writes ===" << std::endl;
    master.write(0x10, 0xAAAAAAAA);
    master.write(0x14, 0xBBBBBBBB);
    master.write(0x18, 0xCCCCCCCC);
    sc_start(10, SC_NS);

    //------------------------------------------------------------------------
    // Test 3: Multiple write addresses BEFORE write data
    //------------------------------------------------------------------------
    std::cout << "\n=== Test 3: Write Addresses Before Data ===" << std::endl;
    std::cout << "Sending 3 addresses first..." << std::endl;

    // Send all addresses first
    master.send_write_addr(0x20);
    master.send_write_addr(0x24);
    master.send_write_addr(0x28);

    std::cout << "Now sending data..." << std::endl;

    // Then send all data
    master.send_write_data(0xDEAD0001);
    master.ref_memory[0x20] = 0xDEAD0001;
    master.writes_sent++;

    master.send_write_data(0xDEAD0002);
    master.ref_memory[0x24] = 0xDEAD0002;
    master.writes_sent++;

    master.send_write_data(0xDEAD0003);
    master.ref_memory[0x28] = 0xDEAD0003;
    master.writes_sent++;

    // Wait for all write responses
    for (int i = 0; i < 3; i++) {
        while (!bvalid.read() || !bready.read()) {
            sc_start(1, SC_NS);
        }
        sc_start(1, SC_NS);
        master.write_responses++;
        std::cout << sc_time_stamp() << " master: write response received" << std::endl;
    }
    sc_start(10, SC_NS);

    //------------------------------------------------------------------------
    // Test 4: Write data BEFORE write address
    //------------------------------------------------------------------------
    std::cout << "\n=== Test 4: Write Data Before Address ===" << std::endl;
    std::cout << "Sending 3 data values first..." << std::endl;

    // Send all data first
    master.send_write_data(0xBEEF0001);
    master.send_write_data(0xBEEF0002);
    master.send_write_data(0xBEEF0003);

    std::cout << "Now sending addresses..." << std::endl;

    // Then send all addresses
    master.send_write_addr(0x30);
    master.ref_memory[0x30] = 0xBEEF0001;
    master.writes_sent++;

    master.send_write_addr(0x34);
    master.ref_memory[0x34] = 0xBEEF0002;
    master.writes_sent++;

    master.send_write_addr(0x38);
    master.ref_memory[0x38] = 0xBEEF0003;
    master.writes_sent++;

    // Wait for all write responses
    for (int i = 0; i < 3; i++) {
        while (!bvalid.read() || !bready.read()) {
            sc_start(1, SC_NS);
        }
        sc_start(1, SC_NS);
        master.write_responses++;
        std::cout << sc_time_stamp() << " master: write response received" << std::endl;
    }
    sc_start(10, SC_NS);

    //------------------------------------------------------------------------
    // Test 5: Non-pipelined reads
    //------------------------------------------------------------------------
    std::cout << "\n=== Test 5: Non-Pipelined Reads ===" << std::endl;
    master.read(0x00, 0);
    master.read(0x04, 0);
    master.read(0x08, 0);
    sc_start(10, SC_NS);

    //------------------------------------------------------------------------
    // Test 6: Out-of-order reads with different IDs
    //------------------------------------------------------------------------
    std::cout << "\n=== Test 6: Out-of-Order Reads (Different IDs) ===" << std::endl;
    std::cout << "Sending 5 read addresses with different IDs..." << std::endl;

    // Send read addresses with different IDs
    master.send_read_addr(0x00, 1);  // ID=1
    master.send_read_addr(0x04, 2);  // ID=2
    master.send_read_addr(0x08, 3);  // ID=3
    master.send_read_addr(0x10, 4);  // ID=4
    master.send_read_addr(0x14, 5);  // ID=5

    std::cout << "Receiving responses (may be out-of-order)..." << std::endl;

    // Receive all responses (may come out of order!)
    for (int i = 0; i < 5; i++) {
        master.receive_read_data();
    }
    sc_start(10, SC_NS);

    //------------------------------------------------------------------------
    // Test 7: Verify previous writes with reads
    //------------------------------------------------------------------------
    std::cout << "\n=== Test 7: Verify All Written Data ===" << std::endl;
    master.read(0x20, 0);  // Should be 0xDEAD0001
    master.read(0x24, 0);  // Should be 0xDEAD0002
    master.read(0x28, 0);  // Should be 0xDEAD0003
    master.read(0x30, 0);  // Should be 0xBEEF0001
    master.read(0x34, 0);  // Should be 0xBEEF0002
    master.read(0x38, 0);  // Should be 0xBEEF0003
    sc_start(20, SC_NS);

    //------------------------------------------------------------------------
    // Finish
    //------------------------------------------------------------------------
    dut->final();
    trace->flush();
    trace->close();
    delete trace;

    master.print_stats();

    return (master.read_mismatches == 0) ? 0 : 1;
}
