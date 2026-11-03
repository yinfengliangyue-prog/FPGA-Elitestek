`timescale 1ns/1ps
module tb_mlp;
 reg clk=0;always #5 clk=~clk;
 reg rst_n=0,we=0,bit_in=0,start=0;reg [9:0] addr=0;
 wire busy,done,sv;wire [3:0] digit,sc;wire signed [31:0] margin,score;
 number_mlp dut(.clk(clk),.rst_n(rst_n),.pixel_we(we),.pixel_addr(addr),.pixel_bit(bit_in),.start(start),.busy(busy),.done(done),.digit(digit),.margin(margin),.score_valid(sv),.score_class(sc),.score_value(score));
 reg [7:0] images[0:78399],labels[0:99];reg signed [31:0] expected[0:999];
 integer n,i,c,count=0,correct=0;reg signed [31:0] best,second;integer winner;
 always @(posedge clk)if(sv)begin
  if(score!==expected[n*10+sc])$fatal(1,"score mismatch sample=%0d class=%0d got=%0d expected=%0d",n,sc,score,expected[n*10+sc]);
  count=count+1;
 end
 initial begin
  $readmemh("model/test_inputs.mem",images);$readmemh("model/test_scores.mem",expected);$readmemh("model/test_labels.mem",labels);
  repeat(5)@(negedge clk);rst_n=1;
  for(n=0;n<100;n=n+1)begin
   for(i=0;i<784;i=i+1)begin @(negedge clk);we=1;addr=i;bit_in=images[n*784+i]!=0;end
   @(negedge clk);we=0;start=1;@(negedge clk);start=0;
   wait(done);@(negedge clk);
   best=32'sh80000000;second=32'sh80000000;winner=0;
   for(c=0;c<10;c=c+1)begin
    if(expected[n*10+c]>best)begin second=best;best=expected[n*10+c];winner=c;end
    else if(expected[n*10+c]>second)second=expected[n*10+c];
   end
   if(digit!==winner||margin!==best-second)$fatal(1,"argmax/margin mismatch sample=%0d",n);
   if(digit==labels[n])correct=correct+1;
  end
  if(count!=1000)$fatal(1,"missing class scores");
  $display("PASS MLP: 1000 exact scores, 100 argmax/margins, sample accuracy=%0d/100",correct);$finish;
 end
 initial begin #200000000;$fatal(1,"timeout");end
endmodule
