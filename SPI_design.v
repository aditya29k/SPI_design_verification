module SPI_master(
  input clk, rst,
  input new_data,
  input [11:0] din,
  output reg sclk, cs,
  output reg mosi
);
  
  // generating sclk
  
  integer clock_counter = 0;
  
  always@(posedge clk) begin
    
    if(rst) begin
      
      clock_counter <= 0;
      sclk <= 1'b0;
      cs <= 1'b1;
      mosi <= 1'b0;
      
    end
    else begin
      
      if(clock_counter<10) begin
        
        clock_counter <= clock_counter + 1;
        
      end
      else begin
        
        sclk <= ~sclk;
        clock_counter <= 0;
        
      end
      
    end
    
  end
  
  // FSM
  
  reg [11:0] temp;
  
  integer counter = 0;
  
  typedef enum bit { idle = 1'b0, tx = 1'b1} state_type;
  state_type state = idle;
  
  always@(posedge sclk) begin
    
    case(state)
      
      idle: begin
        
        if(new_data) begin
          
          state <= tx;
          cs <= 1'b0;
          //counter <= 0;
          temp <= din;
          
        end
        else begin
          
          state <= idle;
          temp <= 0;
          
        end
        
      end
      
      tx: begin
        
        if(counter <= 11) begin
          
          mosi <= temp[counter];
          counter <= counter + 1;
          
        end
        else begin
          
          counter <= 0;
          state <= idle;
          cs <= 1'b1;
          mosi <= 1'b0;
          
        end
        
      end
      
      default: state <= idle;
      
    endcase
    
  end
  
endmodule

module SPI_slave(
  input sclk, cs, mosi,
  output reg [11:0] dout,
  output reg done
);
  
  int counter = 0;
  reg [11:0] temp;
  
  typedef enum bit { detect = 1'b0, read = 1'b1 } state_type;
  state_type state;
  
  always@(posedge sclk) begin
    
    case(state)
      
      detect: begin
        
        done <= 1'b0;
        
        if(cs==1'b0) begin
          
          state <= read;
          
        end
        else begin
          
          state <= detect;
          
        end
        
      end
      
      read: begin
        
        if(counter<=11) begin
          
          counter <= counter + 1;
          temp <= {mosi, temp[11:1]};
          
        end
        else begin
          
          counter <= 0;
          done <= 1'b1;
          state <= detect;
          
        end
        
      end
      
    endcase
    
  end
  
  assign dout = temp;
  
endmodule

module top(
  input clk, rst, new_data,
  input [11:0] din,
  output [11:0] dout,
  output done
);
  
  wire sclk, cs, mosi;
  
  SPI_master s0(clk, rst, new_data, din, sclk, cs, mosi);
  SPI_slave s1(sclk, cs, mosi, dout, done);
  
endmodule

interface SPI_intf();
  
  logic clk;
  logic rst;       // Reset signal
  logic new_data;      // New data flag
  logic [11:0] din;  // Data input
  logic [11:0] dout; // Data output
  logic done;      // Done signal
  logic sclk;      // SPI clock
  logic cs;        // Chip select
  logic mosi;      // Master Out Slave In



endinterface
