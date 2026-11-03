`timescale 1ns/1ps
module tb_key;
 reg clk=0;always #5 clk=~clk;
 reg rst=0,key=0;wire enabled;
 shape_key_toggle #(.DEBOUNCE_CYCLES(4)) dut(clk,rst,key,enabled);
 task automatic settle(input bit value);begin @(negedge clk);key=value;repeat(12) @(negedge clk);end endtask
 initial begin
  repeat(8) @(negedge clk);rst=1;settle(0);
  if(enabled) $fatal(1,"Startup-held key toggled");
  settle(1);if(enabled) $fatal(1,"Startup release toggled");
  @(negedge clk);key=0;@(negedge clk);key=1;repeat(12) @(negedge clk);
  if(enabled) $fatal(1,"Bounce toggled");
  settle(0);if(enabled) $fatal(1,"Press should wait for release");
  repeat(30) @(negedge clk);settle(1);if(!enabled) $fatal(1,"Release did not enable");
  settle(0);repeat(30) @(negedge clk);if(!enabled) $fatal(1,"Long hold repeated");
  settle(1);if(enabled) $fatal(1,"Second release did not disable");
  $display("PASS KEY startup bounce long-hold release-toggle");$finish;
 end
 initial begin #100000;$fatal(1,"Key timeout");end
endmodule
