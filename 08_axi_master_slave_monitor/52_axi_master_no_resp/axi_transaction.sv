//
//  Simplified AXI (SAXI) Verification IP
//
//  Written by Yuri Panchul as a baseline example for educational projects.
//  It illustrates the following concepts:
//
//      1. Bus Functional Model (BFM)
//      2. Master driver
//      3. Reference slave
//      4. Passive monitor
//      5. Transaction-based verification
//      6. Scoreboarding
//      7. Constrained randomization
//
//  For the sake of simplicity and lazor-sharp focus on the above concepts,
//  the code uses object-oriented programming (classes) only for transactions,
//  not for the agents (master driver, slave, monitor).
//
//  We also do not use SystemVerilog interfaces in these examples.
//  Classes for the agents and SV interfaces can be added as a course project.
//
//  The initial version of the code code also does not illustrate
//  the following important verification methodologies:
//
//      8. Functional coverage
//      9. Concurrent assertions
//
//  Simplified AXI verification IP support the subset of AXI that include:
//
//      1. Valid/ready protocol on all channels (AR, AW, W, R, B)
//      2. Single transactions
//      3. In-order pipelining for write transactions
//      4. Out-of-order read response based on read tag
//      5. [Read-write ordering using address] (*)
//      6. No bursts
//      7. No write masks
//      8. No errors
//      9. No locked or exclusive transactions
//
//  (*) The initial version is not going to have any read-write ordering.
//  Adding it should be the subject of the student's projects.
//
//----------------------------------------------------------------------------
//
//  axi_transaction.sv
//
//----------------------------------------------------------------------------

package axi_transaction;

  parameter addr_width  = 32,
            data_width  = 32,
            id_width    = 4,
            max_delay   = 100;

  parameter n_ids       = 1 << id_width,
            delay_width = $clog2 (max_delay + 1);

  typedef enum { read, write } op_t;

  typedef logic [addr_width  - 1:0] addr_t;
  typedef logic [data_width  - 1:0] data_t;
  typedef logic [id_width    - 1:0] id_t;
  typedef logic [delay_width - 1:0] delay_t;

  //--------------------------------------------------------------------------

  class axi_transaction;

    rand op_t    op;
    rand addr_t  addr;

    rand data_t  data;

    rand id_t    id;

    rand delay_t addr_delay;
    rand delay_t data_delay;

    bit          data_is_set;
    bit          addr_is_sent;
    bit          data_is_sent;

    //------------------------------------------------------------------------

    `ifndef XILINX_SIMULATOR
    constraint addr_c
    {
      addr dist
      {
        [ 0     : 3            ] := 10,
        [ 4     : 9            ] :/ 50,
        [ 32'ha : 32'hffffffff ] :/ 10
      };
    }
    `endif

    constraint id_c
    {
      id < n_ids;
      op == write -> id == 0;
    }

    constraint addr_data_delay_c
    {
      addr_delay <= max_delay;

      if (op == read)
        data_delay == 0;
      else
        data_delay <= max_delay;

      `ifndef XILINX_SIMULATOR
      signed' (data_delay) - signed' (addr_delay) dist
      {
                0   := 30,
        [ - 1 : 1 ] := 30,
        [ - 3 : 3 ] := 35,
        [ - 5 : 5 ] := 5
      };
      `endif
    }

    //------------------------------------------------------------------------

    function string str ();

      string s;

      $sformat (s, "%s addr='h%0h", op.name, addr);

      if (op == read & id != 0)
        s = { s, $sformatf (" id=%0d", id) };

      if (op == write | data_is_set)
        s = { s, $sformatf (" d='h%h", data) };

      if (addr_delay > 0)
        s = { s, $sformatf (" addr_delay=%0d", addr_delay) };

      if (data_delay > 0)
        s = { s, $sformatf (" data_delay=%0d", data_delay) };

      return s;

    endfunction

  endclass

endpackage
