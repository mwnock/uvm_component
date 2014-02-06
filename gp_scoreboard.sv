`ifndef _GP_SCOREBOARD
`define _GP_SCOREBOARD

`uvm_analysis_imp_decl(_obs)
`uvm_analysis_imp_decl(_exp)
class gp_scoreboard #(type T=uvm_object, type M=uvm_object) extends uvm_scoreboard;
  uvm_analysis_imp_obs #(T, gp_scoreboard#(T,M)) ap_obs;
  uvm_analysis_imp_exp #(T, gp_scoreboard#(T,M)) ap_exp;

  protected bit   disable_scoreboard;
  protected byte  mode;
  protected event insert_obs_e;
  protected T     marked_db[M];		/// aa for marked item, used for mode2

  `uvm_component_param_utils_begin(gp_scoreboard#(T,M))
    `uvm_field_int(disable_scoreboard, UVM_DEFAULT)
    `uvm_field_int(mode, UVM_DEFAULT)
  `uvm_component_utils_end

  // queue x 2
  T obs_q [$], exp_q [$];
  T obs_err_q [$], exp_err_q [$];	/// for keep error items

  function new (string name, uvm_component parent);
    super.new(name, parent);
    // gen analysis port
    ap_obs = new("ap_obs", this);
    ap_exp = new("ap_exp", this);
    // initialize members
    disable_scoreboard = 1'b0;
    mode = 8'h0;
  endfunction : new

  /// 期待値書き込みメソッド
  /////////////////////////////
  function void write_exp(T data, M mark=null);
    uvm_report_info("SCRBD", "write expected data");
    case(mode)
      8'h00, 8'h01 : exp_q.push_back(data);
`ifdef _GP_SCOREBOARD_MODE2_MARK
      8'h02   : marked_db[data.mark] = data;
`endif
      default : exp_q.push_back(data);
    endcase
  endfunction

  /// 観測値書き込みメソッド
  /////////////////////////////
  function void write_obs(T data, M mark=null);
    uvm_report_info("SCRBD", "write observed data");
    case(mode)
      8'h00, 8'h01 : obs_q.push_back(data);
      8'h02   : mode2(data, mark);
      default : obs_q.push_back(data);
    endcase
    if(mode==8'h01 || mode==8'h02) -> insert_obs_e;
  endfunction

  // UVM run phase
  task run_phase(uvm_phase phase);
    if(disable_scoreboard==0)begin
      case(mode)
        8'h00 : mode0;
        8'h01 : mode1;
        8'h02 : ; // none
        default : mode0;
      endcase
    end
  endtask

  // UVM report phase
  virtual function void report_phase(uvm_phase phase);
    if(mode==8'h00)begin
      obs_q = obs_err_q;
      exp_q = exp_err_q;
    end
    if(obs_q.size()!=0)begin
      uvm_report_info("SCRBD", "observed data queue is not empty");
      foreach (obs_q[i]) obs_q[i].print;
    end
    if(exp_q.size()!=0)begin
      uvm_report_info("SCRBD", "expected data queue is not empty");
      foreach (exp_q[i]) exp_q[i].print;
    end
  endfunction

  ///////////////////////////////////////////////////
  /// compare mode0
  /// 順次比較
  virtual task mode0;
    forever begin
      wait(obs_q.size()!=0);
      if(exp_q[0].compare(obs_q[0]))begin
        uvm_report_info("SCRBD", "data compare OK");
        obs_q.delete(0);
        exp_q.delete(0);
      end else begin
        obs_err_q.push_back(obs_q.pop_front());
        exp_err_q.push_back(exp_q.pop_front());
      end
    end
  endtask

  /// compare mode1
  /// 網羅比較
  ///   観測値、期待値それぞれにmatching_index_qを用意し、比較でマッチした
  ///   indexを管理。網羅比較後、該当indexを削除する。
  virtual task mode1;
    uvm_comparer comparer;
    int unsigned obs_index_q[$], exp_index_q[$];

    comparer = new;
    comparer.show_max = 0;

    forever begin
      @insert_obs_e;
      obs_index_q.delete();
      exp_index_q.delete();

      /// compare all obs - all exp
      foreach (obs_q[i]) begin
        foreach (exp_q[j]) begin
          //if(obs_q[i].compare(exp_q[j]))begin
          if(obs_q[i].compare(exp_q[j], comparer))begin
            obs_index_q.push_back(i);
            exp_index_q.push_back(j);
          end
        end
      end

      /// delete matching item
      foreach (obs_index_q[i]) begin
        obs_q.delete(obs_index_q[i]);
      end
      foreach (exp_index_q[i]) begin
        exp_q.delete(exp_index_q[i]);
      end

    end
  endtask

  /// compare mode2
  /// マーク比較
  ///   期待値を、指定したindexで管理し、同じindexの観測値が入力されたら
  ///   比較を行う。
  virtual function void mode2(T data, M mark);
`ifdef _GP_SCOREBOARD_MODE2_MARK
  type `_GP_SCOREBOARD_MODE2_MARK mark;
    if(marked_db.exists(data.mark))begin
      data.compare(marked_db[data.mark]);
    end else begin
      uvm_report_info("SCRBD", "---------- following Observed Data exist, but Related Expected Data is not found. ----------");
      data.print;
    end
`endif
  endfunction

endclass

`endif
