`timescale 1ns/1ps
module tb_expression_operator;
 reg clk=0;always #5 clk=~clk;
 reg rst_n=0,we=0,pb=0;reg [9:0] addr=0;reg [7:0] x0=0,x1=0,y0=0,y1=0;
 wire [3:0] symbol;
 expression_operator dut(.clk(clk),.rst_n(rst_n),.pixel_we(we),.pixel_addr(addr),.pixel_bit(pb),.x0(x0),.x1(x1),.y0(y0),.y1(y1),.symbol(symbol));
 reg [7:0] inputs[0:144*784-1],boxes[0:144*4-1],labels[0:143];integer i,j,ok=0;
 initial begin
  $readmemh("verification/number/expression_op_inputs.mem",inputs);$readmemh("verification/number/expression_op_boxes.mem",boxes);$readmemh("verification/number/expression_op_labels.mem",labels);
  repeat(4)@(negedge clk);rst_n=1;
  for(i=0;i<144;i=i+1)begin
   x0=boxes[i*4];x1=boxes[i*4+1];y0=boxes[i*4+2];y1=boxes[i*4+3];
   for(j=0;j<784;j=j+1)begin @(negedge clk);we=1;addr=j;pb=inputs[i*784+j]!=0;end
   @(negedge clk);we=0;repeat(2)@(negedge clk);
   if(symbol!==labels[i])$fatal(1,"operator case=%0d expected=%0d got=%0d total=%0d cross=%0d diag=%0d arms=%0d,%0d,%0d,%0d",i,labels[i],symbol,dut.total,dut.cross_count,dut.diag_count,dut.left_arm,dut.right_arm,dut.top_arm,dut.bottom_arm);
   ok=ok+1;
  end
  $display("PASS EXPRESSION_OPERATOR: %0d synthetic shape grids across size/aspect/stroke/rotation (not camera accuracy)",ok);$finish;
 end
endmodule
