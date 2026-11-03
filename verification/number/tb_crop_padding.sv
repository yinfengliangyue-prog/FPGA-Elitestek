`timescale 1ns/1ps
module crop_padding_test #(parameter PAD=1,G=32,CASES=8,parameter PREFIX="crop_padding_pad1",DATA_PREFIX="crop_padding") (output reg finished=0);
 localparam W=G*4+16,H=G*4+16;
 reg clk=0;always #5 clk=~clk;
 reg rst_n=0,en=0,de=0,valid=0,vs=0,ib=0,expression=0;
 reg [15:0] edges=0;
 wire we,pb,start,empty,busy,sel,overflow,ss,sd;
 wire [9:0] addr;wire [7:0] x0,x1,y0,y1;wire [2:0] ti,n;
 number_preprocess #(.IMG_W(W),.IMG_H(H),.ROI_SIZE(G*4),.ROI_X(8),.ROI_Y(8),.CROP_PAD_CELLS(PAD)) dut(
  .clk(clk),.rst_n(rst_n),.enable(en),.expression_enable(expression),.edge_bits(edges),
  .de(de),.valid(valid),.vs(vs),.inference_busy(ib),.pixel_we(we),.pixel_addr(addr),.pixel_bit(pb),
  .start(start),.empty(empty),.sequence_start(ss),.sequence_done(sd),.token_index(ti),.token_count(n),
  .busy(busy),.selection_valid(sel),.overflow(overflow),
  .selected_xmin(x0),.selected_xmax(x1),.selected_ymin(y0),.selected_ymax(y1));
 reg [7:0] grids[0:CASES*G*G-1],modes[0:CASES-1],counts[0:CASES-1];
 reg [7:0] expected[0:CASES*5*784-1],boxes[0:CASES*5*4-1],crops[0:CASES*5*4-1];
 integer scene=0,x,y,checks=0,starts=0,done_count=0,blank_count=0,nn_delay=0,cycles=0;
 integer crop_bits=0,token_starts=0,k=0,all_checks=0;
 always @(posedge clk)if(rst_n&&en&&!finished)begin
  if(start)begin ib<=1;nn_delay<=5;end
  else if(nn_delay>0)begin nn_delay<=nn_delay-1;if(nn_delay==1)ib<=0;end
  if(we)begin
   if(counts[scene]==0)$fatal(1,"padding%0d scene%0d rejected input emitted crop",PAD,scene);
   if(addr!==crop_bits)$fatal(1,"padding%0d scene%0d token%0d non-sequential address",PAD,scene,ti);
   if(pb!==(expected[(scene*5+ti)*784+addr]!=0))
    $fatal(1,"padding%0d scene%0d token%0d bit%0d got%0d expected%0d",PAD,scene,ti,addr,pb,expected[(scene*5+ti)*784+addr]);
   crop_bits=crop_bits+1;checks=checks+1;all_checks=all_checks+1;
  end
  if(start)begin
   k=(scene*5+ti)*4;
   if(!sel||crop_bits!=784||ti!==token_starts||overflow)$fatal(1,"padding%0d bad crop transaction scene%0d",PAD,scene);
   if({x0,x1,y0,y1}!=={boxes[k],boxes[k+1],boxes[k+2],boxes[k+3]})
    $fatal(1,"padding%0d scene%0d token%0d original geometry changed",PAD,scene,ti);
   if({dut.crop_xmin,dut.crop_xmax,dut.crop_ymin,dut.crop_ymax}!=={crops[k],crops[k+1],crops[k+2],crops[k+3]})
    $fatal(1,"padding%0d scene%0d token%0d sampling bounds mismatch",PAD,scene,ti);
   crop_bits=0;token_starts=token_starts+1;starts=starts+1;
  end
  if(sd)begin
   if(n!==counts[scene]||starts!=counts[scene])$fatal(1,"padding%0d scene%0d wrong sequence length",PAD,scene);
   done_count=done_count+1;
  end
  if(empty)blank_count=blank_count+1;
 end
 function [7:0] sample;
  input integer xx,yy;
  begin sample=0;
   if(xx>=8&&xx<G*4+8&&yy>=8&&yy<G*4+8)
    sample=grids[scene*G*G+((yy-8)/4)*G+(xx-8)/4]!=0?255:0;
  end
 endfunction
 task sof;begin
  @(negedge clk);de=0;valid=0;vs=1;repeat(4)@(negedge clk);vs=0;repeat(4)@(negedge clk);
 end endtask
 initial begin
  $readmemh({"verification/number/",DATA_PREFIX,"_grids.mem"},grids);
  $readmemh({"verification/number/",DATA_PREFIX,"_modes.mem"},modes);
  $readmemh({"verification/number/",DATA_PREFIX,"_counts.mem"},counts);
  $readmemh({"verification/number/",DATA_PREFIX,"_boxes.mem"},boxes);
  $readmemh({"verification/number/",PREFIX,"_expected.mem"},expected);
  $readmemh({"verification/number/",PREFIX,"_crops.mem"},crops);
  if(^counts[0]===1'bx||^expected[0]===1'bx)$fatal(1,"missing padding fixtures");
  repeat(5)@(negedge clk);rst_n=1;
  for(scene=0;scene<CASES;scene=scene+1)begin
   en=0;ib=0;nn_delay=0;repeat(4)@(negedge clk);
   expression=modes[scene]!=0;starts=0;done_count=0;blank_count=0;checks=0;crop_bits=0;token_starts=0;en=1;
   sof;
   for(y=0;y<H;y=y+1)begin
    for(x=0;x<W;x=x+2)begin
     @(negedge clk);de=1;valid=1;edges={sample(x+1,y),sample(x,y)};
    end
    @(negedge clk);de=0;valid=0;repeat(4)@(negedge clk);
   end
   sof;cycles=0;
   while((counts[scene]==0?blank_count==0:expression?done_count==0:starts==0)&&cycles<G*G*40)begin
    @(negedge clk);cycles=cycles+1;
   end
   if(counts[scene]==0)begin
    if(blank_count!=1||checks||starts||done_count)$fatal(1,"padding%0d scene%0d rejection failed",PAD,scene);
   end else begin
    if(starts!=counts[scene]||checks!=counts[scene]*784||blank_count||overflow)
     $fatal(1,"padding%0d scene%0d incomplete crops got%0d expected%0d",PAD,scene,starts,counts[scene]);
    if(expression&&done_count!=1)$fatal(1,"padding%0d scene%0d no sequence completion",PAD,scene);
   end
  end
  en=0;finished=1;
  $display("PASS CROP_PADDING_VARIANT: grid=%0d, pad=%0d cells, %0d bit-exact samples, %0d video scenes, original geometry/ROI/adjacent isolation/rejection",G,PAD,all_checks,CASES);
 end
endmodule

module tb_crop_padding;
 wire zero_done,one_done,four_done,high_done;
 crop_padding_test #(.PAD(0),.PREFIX("crop_padding_pad0")) zero(zero_done);
 crop_padding_test #(.PAD(1),.PREFIX("crop_padding_pad1")) one(one_done);
 crop_padding_test #(.PAD(4),.PREFIX("crop_padding_pad4")) four(four_done);
 crop_padding_test #(.PAD(4),.G(192),.CASES(1),.PREFIX("crop_padding_high_pad4"),.DATA_PREFIX("crop_padding_high")) high(high_done);
 initial begin
  wait(zero_done&&one_done&&four_done&&high_done);
  $display("PASS CROP_PADDING: zero/default/stress padding through captured video; 25 scenes, 45 original boxes and 35280 normalized bits, including 192-grid coordinate overflow checks");
  $finish;
 end
 initial begin #100000000;$fatal(1,"crop padding timeout");end
endmodule
