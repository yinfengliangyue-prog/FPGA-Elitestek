`timescale 1ns/1ps
module tb_expression_segments;
 reg clk=0;always #5 clk=~clk;
 reg rst_n=0,en=0,de=0,valid=0,vs=0,ib=0;reg [15:0] edges=0;
 wire we,pb,start,empty,busy,sel,overflow,ss,sd;wire [9:0] addr;wire [7:0] x0,x1,y0,y1;wire [2:0] ti,n;
 number_preprocess #(.CROP_PAD_CELLS(0),.IMG_W(320),.IMG_H(288),.ROI_SIZE(256),.ROI_X(32),.ROI_Y(16)) dut(
 .clk(clk),.rst_n(rst_n),.enable(en),.expression_enable(1'b1),.edge_bits(edges),.de(de),.valid(valid),.vs(vs),.inference_busy(ib),.pixel_we(we),.pixel_addr(addr),.pixel_bit(pb),.start(start),.empty(empty),.sequence_start(ss),.sequence_done(sd),.token_index(ti),.token_count(n),.busy(busy),.selection_valid(sel),.overflow(overflow),.noise_rejected(),.reject_reason(),.candidate_count(),.sampling_boxes(),.selected_xmin(x0),.selected_xmax(x1),.selected_ymin(y0),.selected_ymax(y1));
 reg [7:0] grids[0:6*4096-1],lengths[0:5],boxes[0:9*4-1],expected[0:9*784-1];
 integer scene=0,base=0,x,y,f,checks=0,done_count=0,blank_count=0,idx=0,nn_delay=0;
 always @(posedge clk)if(rst_n&&en)begin
  if(start)begin ib<=1;nn_delay<=5;end else if(nn_delay>0)begin nn_delay<=nn_delay-1;if(nn_delay==1)ib<=0;end
  if(we)begin
   if(lengths[scene]==0)$fatal(1,"invalid segmentation emitted crop scene%0d",scene);
   if(pb!==(expected[(base+ti)*784+addr]!=0))$fatal(1,"segmentation normalized crop scene%0d token%0d addr%0d",scene,ti,addr);
   checks=checks+1;
  end
  if(start)begin idx=(base+ti)*4;if({x0,x1,y0,y1}!=={boxes[idx],boxes[idx+1],boxes[idx+2],boxes[idx+3]})$fatal(1,"segmentation box");end
  if(sd)begin if(n!==lengths[scene])$fatal(1,"segmentation count");done_count=done_count+1;end
  if(empty)blank_count=blank_count+1;
 end
 function bit grid_pixel;input integer xx,yy;begin grid_pixel=xx>=32&&xx<288&&yy>=16&&yy<272?grids[scene*4096+((yy-16)/4)*64+(xx-32)/4]!=0:0;end endfunction
 task frame;begin
  @(negedge clk);de=0;valid=0;vs=1;repeat(4)@(negedge clk);vs=0;repeat(4)@(negedge clk);
  for(y=0;y<288;y=y+1)begin
   for(x=0;x<320;x=x+2)begin @(negedge clk);de=1;valid=1;edges={grid_pixel(x+1,y)?8'hff:8'd0,grid_pixel(x,y)?8'hff:8'd0};end
   @(negedge clk);de=0;valid=0;repeat(5)@(negedge clk);
  end
  repeat(50000)@(negedge clk);
 end endtask
 initial begin
  $readmemh("verification/number/expression_segment_grids.mem",grids);$readmemh("verification/number/expression_segment_lengths.mem",lengths);$readmemh("verification/number/expression_segment_boxes.mem",boxes);$readmemh("verification/number/expression_segment_expected.mem",expected);
  repeat(4)@(negedge clk);rst_n=1;
  for(scene=0;scene<6;scene=scene+1)begin
   en=0;frame;en=1;done_count=0;blank_count=0;for(f=0;f<4;f=f+1)frame;
   if(lengths[scene]!=0&&done_count==0||lengths[scene]==0&&blank_count==0)$fatal(1,"segmentation no result scene%0d",scene);
   base=base+lengths[scene];
  end
  if(checks<9*784)$fatal(1,"segmentation insufficient coverage");
  $display("PASS EXPRESSION_SEGMENTS: %0d normalized bits; left-right order, holes, small noise removal, short minus, one-column gap, six-symbol/border/blank rejection and recovery",checks);$finish;
 end
 initial begin #40000000;$fatal(1,"timeout");end
endmodule
