cmake_minimum_required(VERSION 3.16)
project(axi_tb CXX)

# Find Verilator
find_package(verilator HINTS ${VERILATOR_ROOT} $ENV{VERILATOR_ROOT})
if (NOT verilator_FOUND)
    message(FATAL_ERROR "Verilator not found. Set VERILATOR_ROOT environment variable.")
endif()

# SystemC dependencies
set(THREADS_PREFER_PTHREAD_FLAG ON)
find_package(Threads REQUIRED)

# Find SystemC
find_package(SystemCLanguage PATHS ${SYSTEMC_HOME} $ENV{SYSTEMC_HOME})
if (NOT SystemCLanguage_FOUND)
    message(FATAL_ERROR "SystemC not found. Set SYSTEMC_HOME environment variable.")
endif()

# Create executable
add_executable(axi_tb axi_tb.cpp)

# Set C++ standard to match SystemC
set_property(
    TARGET axi_tb
    PROPERTY CXX_STANDARD ${SystemC_CXX_STANDARD}
)

# Verilate the AXI slave
verilate(axi_tb SYSTEMC COVERAGE TRACE
    INCLUDE_DIRS "."
    SOURCES axi_slave.v
    VERILATOR_ARGS -Wno-WIDTH -Wno-CASEINCOMPLETE -Wno-UNOPTFLAT
)

# Link SystemC
verilator_link_systemc(axi_tb)
