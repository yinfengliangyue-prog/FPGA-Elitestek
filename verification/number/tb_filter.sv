`timescale 1ns/1ps
module tb_filter;
 reg clk=0;always #5 clk=~clk;
 reg rst_n=0,enable=1,observation=0,blank=0;reg [3:0] digit=0;reg signed [31:0] margin=0;
 wire updated;wire [3:0] result;integer checks=0;
 number_result_filter dut(.clk(clk),.rst_n(rst_n),.enable(enable),.observation(observation),.blank(blank),.digit(digit),.margin(margin),.updated(updated),.result(result));
 task sample;input [3:0] d;input integer m;input [3:0] expected;begin
  @(negedge clk);digit=d;margin=m;observation=1;@(negedge clk);
  if(!updated||result!==expected)$fatal(1,"filter d=%0d m=%0d got=%0d expected=%0d check=%0d",d,m,result,expected,checks);
  observation=0;checks=checks+1;repeat(2)@(negedge clk);
 end endtask
 task clear;begin @(negedge clk);blank=1;@(negedge clk);if(result!=15)$fatal(1,"blank clear");blank=0;end endtask
 initial begin
  repeat(4)@(negedge clk);rst_n=1;
  sample(2,300,15);sample(2,300,15);sample(2,300,2);
  repeat(3)begin sample(7,900,2);sample(2,900,2);end
  sample(2,299,2);sample(2,299,2);sample(2,299,2);sample(2,299,15);
  sample(5,900,15);sample(5,900,15);sample(5,900,5);
  sample(6,600,5);sample(6,600,5);sample(6,600,5);sample(6,600,6);
  sample(5,599,6);sample(5,599,6);sample(5,599,6);sample(5,599,15);sample(5,599,5);
  clear;
  repeat(5)begin sample(1,900,15);sample(8,900,15);end
  clear;sample(8,900,15);sample(8,900,15);sample(8,900,8);
  repeat(100)@(negedge clk);if(result!=8)$fatal(1,"idle consumed budget");
  clear;sample(10,999,15);sample(15,999,15);
  enable=0;@(negedge clk);if(result!=15)$fatal(1,"disable clear");
  $display("PASS FILTER32: %0d observations, 3/5 acquisition, no alternating acquisition, 4/5 strong switching, margin boundaries, bounded expiry, blank/disable",checks);$finish;
 end
 initial begin #1000000;$fatal(1,"timeout");end
endmodule
