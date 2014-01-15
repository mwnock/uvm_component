class gp_scoreboard #(type T=uvm_object) extends uvm_scoreboard;

  `uvm_component_param_utils(gp_scoreboard#(T))

  // queue x 2
  T data_q [$];
  T exp_q  [$];

  function new (string name, uvm_component parent);
    super.new(name, parent);
  endfunction : new

  function void write_data(T data);
    uvm_report_info("SCRBD", "write data");
    data_q.push_back(data);
  endfunction

  function void write_exp(T data);
    uvm_report_info("SCRBD", "write exp");
    exp_q.push_back(data);
  endfunction

  task run_phase(uvm_phase phase);
    T tmp_data0, tmp_data1;
    uvm_report_info("SCRBD", "Called run_phase");
    forever begin
      while(data_q.size()==0) #1;
      tmp_data0 = new;
      tmp_data1 = new;
      tmp_data0 = data_q.pop_front();
      tmp_data1 = exp_q.pop_front();
      if(tmp_data1.compare(tmp_data0))begin
        uvm_report_info("SCRBD", "data compare OK");
      end
      tmp_data0 = null;
      tmp_data1 = null;
    end
  endtask

endclass
