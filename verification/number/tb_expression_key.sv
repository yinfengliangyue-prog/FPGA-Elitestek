`timescale 1ns/1ps
module tb_expression_key;
 reg clk=0;always #5 clk=~clk;
 reg rst_n=0,key_n=0;wire enabled,expr,lock_pulse;integer pulses=0;
 expression_key_control #(.DEBOUNCE_CYCLES(3),.LONG_CYCLES(30)) dut(.clk(clk),.rst_n(rst_n),.key_n(key_n),.inhibit(1'b0),.enabled(enabled),.expression_mode(expr),.lock_pulse(lock_pulse));
 always @(posedge clk)if(lock_pulse)pulses=pulses+1;
 task key;input integer cycles;begin @(negedge clk);key_n=0;repeat(cycles)@(negedge clk);key_n=1;repeat(12)@(negedge clk);end endtask
 initial begin
  repeat(4)@(negedge clk);rst_n=1;repeat(50)@(negedge clk);key_n=1;repeat(12)@(negedge clk);if(enabled)$fatal(1,"held reset key activated");
  key(12);if(!enabled||expr)$fatal(1,"NUMBER missing");
  key(12);if(!enabled||!expr)$fatal(1,"EXPR missing");
  key(50);if(!expr||pulses!=1)$fatal(1,"long press repeated/cycled");
  key(50);if(pulses!=2)$fatal(1,"unlock pulse missing");
  key(12);if(enabled||expr)$fatal(1,"OFF missing");
  @(negedge clk);key_n=0;@(negedge clk);key_n=1;repeat(12)@(negedge clk);if(enabled)$fatal(1,"bounce activated");
  key(50);if(enabled||pulses!=2)$fatal(1,"OFF long press activated");
  $display("PASS EXPRESSION_KEY: reset-held, bounce, OFF/NUMBER/EXPR, long lock/unlock without repeats");$finish;
 end
endmodule
