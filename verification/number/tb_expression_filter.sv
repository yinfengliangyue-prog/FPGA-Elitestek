`timescale 1ns/1ps
module tb_expression_filter;
 reg clk=0;always #5 clk=~clk;
 reg rst_n=0,en=1,obs=0,valid=1;reg [39:0] tokens=40'hff_ff_03_0a_02;
 reg [159:0] boxes=160'h10203050_10203050_10203050_10203050_10203050;reg [2:0] count=3;
 wire updated,confirmed;
 expression_result_filter dut(.clk(clk),.rst_n(rst_n),.enable(en),.observation(obs),.valid(valid),.tokens(tokens),.boxes(boxes),.count(count),.updated(updated),.confirmed(confirmed));
 task observe;input expected;begin @(negedge clk);obs=1;@(negedge clk);obs=0;if(!updated||confirmed!==expected)$fatal(1,"whole-expression vote");@(negedge clk);end endtask
 initial begin
  repeat(4)@(negedge clk);rst_n=1;observe(0);observe(0);observe(1);
  tokens[7:0]=4;observe(0);observe(0);observe(1);
  valid=0;observe(0);valid=1;observe(0);observe(0);observe(1);
  boxes[23:16]=100;observe(0);observe(0);observe(1);
  en=0;repeat(2)@(negedge clk);if(confirmed)$fatal(1,"OFF retains answer");
  en=1;observe(0);observe(0);observe(1);
  $display("PASS EXPRESSION_FILTER: whole-sequence confirmation, immediate conflict/blank hiding, each-symbol spatial context, OFF restart");$finish;
 end
endmodule
