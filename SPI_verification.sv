class transaction;
  
  rand bit new_data; // does not need to be randomize when data comes it should be 1
  rand bit [11:0] din;
  bit [11:0] dout;
  bit done;
  
  function void display(string tag);
    
    $display("[%0s] din: %0d, dout: %0d, done: %0d", tag, din, dout, done);
    
  endfunction
  
  function transaction copy();
    
    copy = new();
    copy.new_data = this.new_data;
    copy.din = this.din;
    copy.dout = this.dout;
    copy.done = this.done;
    
  endfunction
  
  constraint din_constraint { new_data == 0 -> din == 0; }
  constraint new_data_constraint { new_data dist {1:= 1, 0:= 0}; } // if first input is 0 then it wont work
  
endclass

class generator;
  
  transaction t;
  mailbox #(transaction) mbx_gd;
  mailbox #(transaction) mbx_gs;
  
  int count;

  event next_sc;
  event done;
  
  function new(mailbox #(transaction) mbx_gd, mailbox #(transaction) mbx_gs);
    
    this.mbx_gd = mbx_gd;
    this.mbx_gs = mbx_gs;
    t = new();
    
  endfunction
  
  task run();
    
    repeat(count) begin
      
      $display("------------------------------");
      assert(t.randomize()) else $display("[GEN] RANDOMIZATION FAILED");
      t.display("GEN");
      mbx_gd.put(t.copy());
      mbx_gs.put(t.copy());

      @(next_sc);
      
    end
    ->done;
    
  endtask
  
endclass

class driver;
  
  transaction t;
  mailbox #(transaction) mbx_gs;
  
  virtual SPI_intf intf;
  
  function new(mailbox #(transaction) mbx_gs);
    
    this.mbx_gs = mbx_gs;
    
  endfunction
  
  task reset();
    
    intf.rst <= 1'b1;
    intf.new_data <= 0;
    intf.din <= 0;
    repeat(5) @(posedge intf.clk);
    intf.rst <= 1'b0;
    @(posedge intf.clk);
    $display("[DRV] SYSTEM RESETED");
    $display("-----------------------------------------");
    
  endtask
  
  task run();
    
    forever begin
      
      mbx_gs.get(t);
      intf.new_data <= t.new_data;
      intf.din <= t.din;
      @(posedge intf.sclk);
      intf.new_data <= 1'b0;
      @(posedge intf.done); // waiting for done to get 1 ten send new data
      t.display("DRV");
      @(posedge intf.sclk);
      
    end
    
  endtask
  
endclass

class monitor;
  
  transaction t;
  mailbox #(transaction) mbx_ms;
  
  virtual SPI_intf intf;
  
  function new(mailbox #(transaction) mbx_ms);
    
    this.mbx_ms = mbx_ms;
    
  endfunction
  
  task run();
    
    t = new();
    forever begin
      
      @(posedge intf.sclk);
      @(posedge intf.done);
      t.dout = intf.dout;
      t.done = intf.done;
      t.din = intf.din;
      @(posedge intf.sclk);
      t.display("MON");
      mbx_ms.put(t);
      
    end
    
  endtask
  
endclass

class scoreboard;
  
  transaction t_gs;
  transaction t_ms;
  mailbox #(transaction) mbx_gs;
  mailbox #(transaction) mbx_ms;
  
  event next_sc;
  
  function new(mailbox #(transaction) mbx_gs, mailbox #(transaction) mbx_ms);
    
    this.mbx_gs = mbx_gs;
    this.mbx_ms = mbx_ms;
    
  endfunction
  
  task run();
    
    forever begin
      
      mbx_gs.get(t_gs);
      mbx_ms.get(t_ms);
      
      if(t_gs.din == t_ms.dout) begin
        
        $display("[SCO] DATA MATCHED");
        
      end
      else begin
        
        $display("[SCO] DATA MISMATCHED");
        
      end
      
      ->next_sc;
      
    end
    
  endtask
  
endclass

class environment;
  
  transaction t;
  generator g;
  driver d;
  monitor m;
  scoreboard s;
  
  mailbox #(transaction) mbx_gd;
  mailbox #(transaction) mbx_gs;
  mailbox #(transaction) mbx_ms;
  
  event done;
  event next_sc;
  
  virtual SPI_intf intf;
  
  function new(virtual SPI_intf intf);
    
    mbx_gd = new();
    mbx_gs = new();
    mbx_ms = new();
    
    t = new();
    g = new(mbx_gd, mbx_gs);
    d = new(mbx_gd);
    m = new(mbx_ms);
    s = new(mbx_gs, mbx_ms);
    
    g.done = done;
    s.next_sc = this.next_sc;
    g.next_sc = this.next_sc;

    
    this.intf = intf;
    d.intf = this.intf;
    m.intf = this.intf;
    
    g.count = 10;
    
  endfunction
  
  task pre_test();
	
    d.reset();
    
  endtask
  
  task test();
    
    fork
      
      g.run();
      d.run();
      m.run();
      s.run();
      
    join_any
    
  endtask
  
  task post_test();
    
    wait(done.triggered);
    $finish();
    
  endtask
  
  task run();
    
    pre_test();
    test();
    post_test();
    
  endtask
  
endclass

module tb;
  
  environment env;
  
  SPI_intf intf();
  
  top DUT(intf.clk, intf.rst, intf.new_data, intf.din, intf.dout, intf.done);
  
  initial begin
    
    intf.clk <= 0;
    
  end
  
  always #10 intf.clk <= ~intf.clk;
  
  assign intf.sclk = DUT.s0.sclk;
  
  initial begin
    
    env = new(intf);
    env.run();
    
  end
  
  initial begin
    
    $dumpfile("dump.vcd");
    $dumpvars;
    
  end
  
endmodule
