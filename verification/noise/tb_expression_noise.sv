`timescale 1ns/1ps
module noise_test #(parameter G=64,CASES=1,parameter PREFIX="noise64")(output reg finished=0);
 localparam W=G*4+16,H=G*4+16;
 reg clk=0;always #5 clk=~clk;
 reg rst_n=0,en=0,de=0,valid=0,vs=0,ib=0;reg [15:0] edges=0;
 wire we,pb,start,empty,busy,sel,overflow,ss,sd;
 wire [9:0] addr;wire [7:0] x0,x1,y0,y1,nnoise;wire [2:0] ti,n;
 wire [3:0] reason;wire [5:0] candidates;
 number_preprocess #(.IMG_W(W),.IMG_H(H),.ROI_SIZE(G*4),.ROI_X(8),.ROI_Y(8)) dut(
  .clk(clk),.rst_n(rst_n),.enable(en),.expression_enable(1'b1),.edge_bits(edges),
  .de(de),.valid(valid),.vs(vs),.inference_busy(ib),.pixel_we(we),.pixel_addr(addr),.pixel_bit(pb),
  .start(start),.empty(empty),.sequence_start(ss),.sequence_done(sd),.token_index(ti),.token_count(n),
  .busy(busy),.selection_valid(sel),.overflow(overflow),
  .selected_xmin(x0),.selected_xmax(x1),.selected_ymin(y0),.selected_ymax(y1),
  .noise_rejected(nnoise),.reject_reason(reason),.candidate_count(candidates),.sampling_boxes());
 reg [7:0] grids[0:CASES*G*G-1],counts[0:CASES-1],reason_masks[0:CASES-1],noise_min[0:CASES-1],valid_expected[0:CASES-1];
 reg [7:0] expected[0:CASES*5*784-1],boxes[0:CASES*5*4-1],crops[0:CASES*5*4-1],labels[0:CASES*5-1];
 integer scene=0,x,y,checks=0,starts=0,done_count=0,blank_count=0,nn_delay=0,cycles=0;
 integer crop_bits=0,all_checks=0,total_starts=0,k=0,engine_count=0;
 reg nn_done=0;
 wire [3:0] token_label=labels[scene*5+ti][3:0];
 wire engine_done,engine_valid;
 expression_engine engine(.clk(clk),.rst_n(rst_n),.enable(en),.sequence_start(ss),.sequence_done(sd),.blank(empty),
  .token_start(start),.nn_done(nn_done),.token_index(ti),.token_count(n),
  .digit(token_label<10?token_label:4'd0),.operator_symbol(token_label>=10?token_label:4'd15),
  .margin(32'sd1000),.x0(x0),.x1(x1),.y0(y0),.y1(y1),.busy(),.done(engine_done),.valid(engine_valid),
  .divide_zero(),.negative(),.tokens(),.boxes(),.count(),.magnitude(),.remainder(),.operation());
 always @(posedge clk)if(rst_n&&en&&!finished)begin
  nn_done<=0;
  if(start)begin ib<=1;nn_delay<=6;end
  else if(nn_delay>0)begin nn_delay<=nn_delay-1;if(nn_delay==1)begin ib<=0;nn_done<=1;end end
  if(we)begin
   if(counts[scene]==0)$fatal(1,"grid%0d scene%0d rejected input emitted crop",G,scene);
   if(addr!==crop_bits)$fatal(1,"grid%0d scene%0d token%0d address",G,scene,ti);
   if(pb!==(expected[(scene*5+ti)*784+addr]!=0))
    $fatal(1,"grid%0d scene%0d token%0d bit%0d got%0d expected%0d",G,scene,ti,addr,pb,expected[(scene*5+ti)*784+addr]);
   crop_bits=crop_bits+1;checks=checks+1;all_checks=all_checks+1;
  end
  if(start)begin
   k=(scene*5+ti)*4;
   if(!sel||crop_bits!=784||ti!==starts||overflow)$fatal(1,"grid%0d scene%0d invalid crop transaction",G,scene);
   if({x0,x1,y0,y1}!=={boxes[k],boxes[k+1],boxes[k+2],boxes[k+3]})
    $fatal(1,"grid%0d scene%0d token%0d box got%0d,%0d,%0d,%0d expected%0d,%0d,%0d,%0d",G,scene,ti,x0,x1,y0,y1,boxes[k],boxes[k+1],boxes[k+2],boxes[k+3]);
   if({dut.crop_xmin,dut.crop_xmax,dut.crop_ymin,dut.crop_ymax}!=={crops[k],crops[k+1],crops[k+2],crops[k+3]})
    $fatal(1,"grid%0d scene%0d token%0d padded crop bounds",G,scene,ti);
   crop_bits=0;starts=starts+1;total_starts=total_starts+1;
  end
  if(sd)begin
   if(n!==counts[scene]||starts!=counts[scene])$fatal(1,"grid%0d scene%0d sequence length",G,scene);
   done_count=done_count+1;
  end
  if(empty)blank_count=blank_count+1;
  if(engine_done)begin
   if(counts[scene]!=0&&engine_valid!==(valid_expected[scene]!=0))$fatal(1,"grid%0d scene%0d parser result got%0d expected%0d",G,scene,engine_valid,valid_expected[scene]);
   engine_count=engine_count+1;
  end
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
  $readmemh({"verification/noise/",PREFIX,"_grids.mem"},grids);
  $readmemh({"verification/noise/",PREFIX,"_counts.mem"},counts);
  $readmemh({"verification/noise/",PREFIX,"_reason_masks.mem"},reason_masks);
  $readmemh({"verification/noise/",PREFIX,"_noise_min.mem"},noise_min);
  $readmemh({"verification/noise/",PREFIX,"_valid.mem"},valid_expected);
  $readmemh({"verification/noise/",PREFIX,"_labels.mem"},labels);
  $readmemh({"verification/noise/",PREFIX,"_boxes.mem"},boxes);
  $readmemh({"verification/noise/",PREFIX,"_expected.mem"},expected);
  $readmemh({"verification/noise/",PREFIX,"_crops.mem"},crops);
  if(^counts[0]===1'bx||^expected[0]===1'bx)$fatal(1,"missing noise fixtures");
  repeat(5)@(negedge clk);rst_n=1;
  for(scene=0;scene<CASES;scene=scene+1)begin
   en=0;ib=0;nn_done=0;nn_delay=0;repeat(4)@(negedge clk);
   starts=0;done_count=0;blank_count=0;checks=0;crop_bits=0;engine_count=0;en=1;
   sof;
   for(y=0;y<H;y=y+1)begin
    for(x=0;x<W;x=x+2)begin
     @(negedge clk);de=1;valid=1;edges={sample(x+1,y),sample(x,y)};
    end
    @(negedge clk);de=0;valid=0;repeat(4)@(negedge clk);
   end
   sof;cycles=0;
   while((counts[scene]==0?blank_count==0:engine_count==0)&&cycles<G*G*150)begin
    @(negedge clk);cycles=cycles+1;
   end
   if(counts[scene]==0)begin
    if(blank_count!=1||checks||starts||done_count||!reason_masks[scene][reason])$fatal(1,"grid%0d scene%0d rejection got reason%0d blank%0d starts%0d",G,scene,reason,blank_count,starts);
   end else begin
    if(starts!=counts[scene]||checks!=counts[scene]*784||blank_count||overflow||done_count!=1||engine_count!=1||reason!=0)
     $fatal(1,"grid%0d scene%0d incomplete crops starts%0d count%0d blank%0d reason%0d state%0d",G,scene,starts,counts[scene],blank_count,reason,dut.state);
    if(nnoise<noise_min[scene])$fatal(1,"grid%0d scene%0d noise rejected %0d expected at least %0d",G,scene,nnoise,noise_min[scene]);
   end
   $display("NOISE scene grid%0d index%0d complete candidates%0d removed%0d reason%0d",G,scene,candidates,nnoise,reason);
  end
  en=0;finished=1;
  $display("PASS EXPRESSION_NOISE_VARIANT: grid%0d, %0d scenes, %0d exact normalized bits, %0d character boxes, raw point removal/ownership/capacity/parser semantics",G,CASES,all_checks,total_starts);
 end
endmodule
