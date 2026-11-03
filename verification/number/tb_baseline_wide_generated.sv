`timescale 1ns/1ps
module preprocess_test #(parameter G=16,CASES=10,Q=1024,parameter PREFIX="pre32");
 reg clk=0;always #5 clk=~clk;
 reg rst_n=0,enable=1,de=0,valid=0,vs=0,locked=0;reg [15:0] edges=0;
 wire we,bit_out,start,empty,busy,sel,overflow;wire [9:0] addr;wire [7:0] x0,x1,y0,y1;
 number_preprocess #(.CROP_PAD_CELLS(0),.IMG_W(G*4+16),.IMG_H(G*4+16),.ROI_SIZE(G*4),.ROI_X(8),.ROI_Y(8),.QUEUE_DEPTH(Q)) dut(
 .clk(clk),.rst_n(rst_n),.enable(enable),.expression_enable(1'b0),.edge_bits(edges),.de(de),.valid(valid),.vs(vs),.inference_busy(locked),
 .sequence_start(),.sequence_done(),.token_index(),.token_count(),.pixel_we(we),.pixel_addr(addr),.pixel_bit(bit_out),.start(start),.empty(empty),.busy(busy),.selection_valid(sel),.overflow(overflow),.noise_rejected(),.reject_reason(),.candidate_count(),.sampling_boxes(),
 .selected_xmin(x0),.selected_xmax(x1),.selected_ymin(y0),.selected_ymax(y1));
 reg [7:0] grids[0:CASES*G*G-1],expected[0:CASES*784-1],boxes[0:CASES*4-1],present[0:CASES-1],over_expected[0:CASES-1];
 integer n,count=0,starts=0,empties=0,x,y,idx,cycles;
 always @(posedge clk)begin
  if(we)begin
   if(addr!==count||bit_out!==(expected[n*784+count]!=0))$fatal(1,"area vote mismatch case=%0d bit=%0d got=%0d exp=%0d",n,count,bit_out,expected[n*784+count]);
   count=count+1;
  end
  if(start)starts=starts+1;if(empty)empties=empties+1;
 end
 function [7:0] sample;input integer xx,yy;begin
  sample=0;if(xx>=8&&xx<G*4+8&&yy>=8&&yy<G*4+8)sample=grids[n*G*G+((yy-8)/4)*G+(xx-8)/4]?255:0;
 end endfunction
 task sof;begin @(negedge clk);de=0;valid=0;vs=1;repeat(4)@(negedge clk);vs=0;repeat(4)@(negedge clk);end endtask
 initial begin
  $readmemh({"verification/number/",PREFIX,"_grid.mem"},grids);$readmemh({"verification/number/",PREFIX,"_expected.mem"},expected);
  $readmemh({"verification/number/",PREFIX,"_boxes.mem"},boxes);$readmemh({"verification/number/",PREFIX,"_present.mem"},present);$readmemh({"verification/number/",PREFIX,"_overflow.mem"},over_expected);
  if(^present[0]===1'bx||^grids[0]===1'bx)$fatal(1,"missing fixtures");
  repeat(5)@(negedge clk);rst_n=1;
  for(n=0;n<CASES;n=n+1)begin
   enable=0;repeat(4)@(negedge clk);enable=1;count=0;starts=0;empties=0;
   sof;
   for(y=0;y<G*4+16;y=y+1)begin
    for(x=0;x<G*4+16;x=x+2)begin
     @(negedge clk);de=1;valid=1;edges={sample(x+1,y),sample(x,y)};
     if(x==18)begin @(negedge clk);valid=0;repeat(2)@(negedge clk);end
    end
    @(negedge clk);de=0;valid=0;repeat(4)@(negedge clk);
   end
   sof;cycles=0;
   while(starts==0&&empties==0&&cycles<2000000)begin @(negedge clk);cycles=cycles+1;end
   if(present[n])begin
    if(count!=784||starts!=1||empties||overflow||{x0,x1,y0,y1}!=={boxes[n*4],boxes[n*4+1],boxes[n*4+2],boxes[n*4+3]})$fatal(1,"selected component mismatch case=%0d bits=%0d bbox=%0d,%0d,%0d,%0d",n,count,x0,x1,y0,y1);
    locked=1;repeat(50)@(negedge clk);locked=0;
   end else if(count||starts||empties!=1||overflow!==(over_expected[n]!=0))$fatal(1,"empty/touch rejection failed case=%0d",n);
  end
  $display("PASS PREPROCESS32: grid=%0d, %0d cases, all normalized bits and dominant boxes, 8-connectivity, exact component threshold, specks, border, high coordinates",G,CASES);$finish;
 end
 initial begin #200000000;$fatal(1,"timeout");end
endmodule
module tb_preprocess;preprocess_test t();endmodule

module tb_wide;preprocess_test #(.G(192),.CASES(10),.PREFIX("wide32")) t();endmodule
