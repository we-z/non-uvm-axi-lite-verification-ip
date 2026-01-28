//----------------------------------------------------------------------------
//  AXI Sequence Item (Transaction)
//
//  UVM transaction class for AXI-Lite operations
//  Supports constrained randomization with distribution constraints
//----------------------------------------------------------------------------

class axi_seq_item extends uvm_sequence_item;

  //--------------------------------------------------------------------------
  // Transaction Fields
  //--------------------------------------------------------------------------

  rand axi_op_t op;
  rand addr_t   addr;
  rand data_t   data;
  rand id_t     id;
  rand delay_t  addr_delay;
  rand delay_t  data_delay;

  // Status flags (not randomized)
  bit           data_is_set;
  bit           addr_is_sent;
  bit           data_is_sent;
  bit           in_order;

  //--------------------------------------------------------------------------
  // UVM Factory Registration
  //--------------------------------------------------------------------------

  `uvm_object_utils_begin(axi_seq_item)
    `uvm_field_enum(axi_op_t, op,     UVM_ALL_ON)
    `uvm_field_int(addr,              UVM_ALL_ON | UVM_HEX)
    `uvm_field_int(data,              UVM_ALL_ON | UVM_HEX)
    `uvm_field_int(id,                UVM_ALL_ON)
    `uvm_field_int(addr_delay,        UVM_ALL_ON)
    `uvm_field_int(data_delay,        UVM_ALL_ON)
    `uvm_field_int(data_is_set,       UVM_ALL_ON | UVM_NOCOMPARE)
    `uvm_field_int(addr_is_sent,      UVM_ALL_ON | UVM_NOCOMPARE)
    `uvm_field_int(data_is_sent,      UVM_ALL_ON | UVM_NOCOMPARE)
    `uvm_field_int(in_order,          UVM_ALL_ON | UVM_NOCOMPARE)
  `uvm_object_utils_end

  //--------------------------------------------------------------------------
  // Constraints
  //--------------------------------------------------------------------------

  // Address distribution constraint
  constraint addr_c {
    addr dist {
      [0     : 3]            := 10,
      [4     : 9]            :/ 50,
      [32'ha : 32'hffffffff] :/ 10
    };
  }

  // ID constraint: writes use ID=0, reads can use any ID
  constraint id_c {
    id < N_IDS;
    op == AXI_WRITE -> id == 0;
    in_order -> id == 0;
  }

  // Delay constraints
  constraint addr_data_delay_c {
    addr_delay <= MAX_DELAY;

    if (op == AXI_READ)
      data_delay == 0;
    else
      data_delay <= MAX_DELAY;

    // Distribution for relative timing between address and data
    signed'(data_delay) - signed'(addr_delay) dist {
              0   := 30,  // Simultaneous
      [-1 : 1]    := 30,  // Near simultaneous
      [-3 : 3]    := 35,  // Small difference
      [-5 : 5]    := 5    // Larger difference
    };
  }

  //--------------------------------------------------------------------------
  // Constructor
  //--------------------------------------------------------------------------

  function new(string name = "axi_seq_item");
    super.new(name);
    data_is_set  = 0;
    addr_is_sent = 0;
    data_is_sent = 0;
    in_order     = 0;
  endfunction

  //--------------------------------------------------------------------------
  // Convert to String
  //--------------------------------------------------------------------------

  virtual function string convert2string();
    string s;

    s = $sformatf("%s addr='h%0h", op.name(), addr);

    if (op == AXI_READ && id != 0)
      s = {s, $sformatf(" id=%0d", id)};

    if (op == AXI_WRITE || data_is_set)
      s = {s, $sformatf(" d='h%h", data)};

    if (addr_delay > 0)
      s = {s, $sformatf(" addr_delay=%0d", addr_delay)};

    if (data_delay > 0)
      s = {s, $sformatf(" data_delay=%0d", data_delay)};

    return s;
  endfunction

  //--------------------------------------------------------------------------
  // Clone
  //--------------------------------------------------------------------------

  virtual function uvm_object clone();
    axi_seq_item item;
    item = axi_seq_item::type_id::create("clone");
    item.copy(this);
    return item;
  endfunction

endclass
