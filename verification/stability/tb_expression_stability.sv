`timescale 1ns/1ps
module crop_stability_test #(parameter STABLE=1,CASES=38)(output reg finished=0);
 localparam G=96,W=400,H=400;
 reg clk=0;always #5 clk=~clk;
 reg rst_n=0,en=0,de=0,valid=0,vs=0,ib=0;reg [15:0] edges=0;
 wire we,pb,start,empty,busy,sel,overflow,ss,sd;wire [9:0] addr;
 wire [7:0] x0,x1,y0,y1,dropped;wire [2:0] ti,n;wire [3:0] reason;
 wire [5:0] candidates;wire [159:0] samples;
 number_preprocess #(.IMG_W(W),.IMG_H(H),.ROI_SIZE(384),.ROI_X(8),.ROI_Y(8),.CROP_STABILIZE(STABLE)) dut(
 .clk(clk),.rst_n(rst_n),.enable(en),.expression_enable(1'b1),.edge_bits(edges),.de(de),.valid(valid),.vs(vs),.inference_busy(ib),
 .pixel_we(we),.pixel_addr(addr),.pixel_bit(pb),.start(start),.empty(empty),.sequence_start(ss),.sequence_done(sd),.token_index(ti),.token_count(n),.busy(busy),.selection_valid(sel),.overflow(overflow),
 .selected_xmin(x0),.selected_xmax(x1),.selected_ymin(y0),.selected_ymax(y1),.noise_rejected(dropped),.reject_reason(reason),.candidate_count(candidates),.sampling_boxes(samples));
 reg [7:0] grids[0:CASES*G*G-1],counts[0:CASES-1],expire[0:CASES-1];
 reg [7:0] boxes[0:CASES*5*4-1],crops[0:CASES*5*4-1],bits[0:CASES*5*784-1];
 integer scene=0,x,y,i,k,starts=0,checks=0,all_checks=0,total_starts=0,delay=0,cycles=0;reg done=0;
 always @(posedge clk)if(rst_n&&en&&!finished)begin
  if(we)begin
   if(addr!==checks||pb!==(bits[(scene*5+ti)*784+addr]!=0))$fatal(1,"stable%0d scene%0d token%0d pixel%0d normalization",STABLE,scene,ti,addr);
   checks=checks+1;all_checks=all_checks+1;
  end
  if(start)begin
   k=(scene*5+ti)*4;
   if(!sel||overflow||checks!=784||ti!==starts)$fatal(1,"crop transaction");
   if({x0,x1,y0,y1}!=={boxes[k],boxes[k+1],boxes[k+2],boxes[k+3]})$fatal(1,"raw geometry changed");
   if({dut.crop_xmin,dut.crop_xmax,dut.crop_ymin,dut.crop_ymax}!=={crops[k],crops[k+1],crops[k+2],crops[k+3]})
    $fatal(1,"stable%0d scene%0d token%0d crop got %0d,%0d,%0d,%0d expected %0d,%0d,%0d,%0d",STABLE,scene,ti,dut.crop_xmin,dut.crop_xmax,dut.crop_ymin,dut.crop_ymax,crops[k],crops[k+1],crops[k+2],crops[k+3]);
   if(samples[ti*32+:32]!=={crops[k],crops[k+1],crops[k+2],crops[k+3]})$fatal(1,"display/sampling crop disagree");
   if(dut.crop_xmin>x0||dut.crop_xmax<x1||dut.crop_ymin>y0||dut.crop_ymax<y1)$fatal(1,"historical crop clipped current foreground");
   if(ti>0&&dut.crop_xmin<=dut.sx1[ti-1])$fatal(1,"read previous character");
   if(ti+1<n&&dut.crop_xmax>=dut.sx0[ti+1])$fatal(1,"read next character");
   checks=0;starts=starts+1;total_starts=total_starts+1;ib<=1;delay<=6;
  end else if(delay>0)begin delay<=delay-1;if(delay==1)ib<=0;end
  if(sd||empty)begin
   if(counts[scene]==0)begin if(!empty||starts!=0||reason!=5)$fatal(1,"blank");end
   else if(!sd||n!==counts[scene]||starts!=counts[scene]||reason!=0)$fatal(1,"sequence");
   done=1;
  end
 end
 function [7:0] sample;input integer xx,yy;begin
  sample=0;if(xx>=8&&xx<392&&yy>=8&&yy<392)sample=grids[scene*G*G+((yy-8)/4)*G+(xx-8)/4]!=0?255:0;
 end endfunction
 task sof;begin @(negedge clk);de=0;valid=0;vs=1;repeat(4)@(negedge clk);vs=0;repeat(4)@(negedge clk);end endtask
 initial begin
  $readmemh("verification/stability/grids.mem",grids);$readmemh("verification/stability/counts.mem",counts);
  $readmemh("verification/stability/expire.mem",expire);$readmemh("verification/stability/boxes.mem",boxes);
  if(STABLE)begin $readmemh("verification/stability/stable_crops.mem",crops);$readmemh("verification/stability/stable_bits.mem",bits);end
  else begin $readmemh("verification/stability/bypass_crops.mem",crops);$readmemh("verification/stability/bypass_bits.mem",bits);end
  repeat(5)@(negedge clk);rst_n=1;en=1;
  for(scene=0;scene<CASES;scene=scene+1)begin
   if(expire[scene])begin
    ib=1;for(i=0;i<12;i=i+1)sof;ib=0;
    if(dut.history_valid)$fatal(1,"expired history retained");
   end
   starts=0;checks=0;done=0;sof;
   for(y=0;y<H;y=y+1)begin
    for(x=0;x<W;x=x+2)begin @(negedge clk);de=1;valid=1;edges={sample(x+1,y),sample(x,y)};end
    @(negedge clk);de=0;valid=0;repeat(4)@(negedge clk);
   end
   sof;cycles=0;
   while(!done&&cycles<G*G*150)begin @(negedge clk);cycles=cycles+1;end
   if(!done)$fatal(1,"crop stability timeout");repeat(4)@(negedge clk);
  end
  en=0;finished=1;
  $display("PASS CROP_STABILITY: enabled%0d, %0d consecutive scenes, %0d raw boxes and actual sampling boxes, %0d normalized bits; jitter/expansion/three-observation contraction/motion/count/neighbour/expiry",STABLE,CASES,total_starts,all_checks);
 end
endmodule

module wait_display_test(output reg finished=0);
 reg clk=0;always #5 clk=~clk;
 reg rst_n=0,en=1,sof=0,update=0,confirmed=1,valid=1,lp=0;
 reg [39:0] tokens=40'hff_ff_03_0a_02;reg [159:0] boxes=0;reg [2:0] n=3;
 reg [3:0] reason=0;wire pending,locked,cf;wire [47:0] rgb;
 expression_overlay #(.CLK_HZ(1000),.WAIT_MS(80)) dut(.ui_text(),.ui_boxes(),.ui_count(),.ui_holding(),.clk(clk),.rst_n(rst_n),.enable(en),.sof(sof),.de(1'b0),.valid(1'b0),.px(12'd0),.y(12'd0),.rgb_in(48'd0),
 .update(update),.confirmed(confirmed),.candidate_valid(valid),.tokens(tokens),.boxes(boxes),.count(n),.magnitude(14'd5),.remainder(7'd0),.negative(1'b0),.divide_zero(1'b0),.operation(4'd10),.lock_pulse(lp),
 .diag_noise(8'd0),.diag_candidates(6'd3),.diag_tokens(n),.diag_reason(reason),.pending(pending),.locked(locked),.confirmed_frame(cf),.rgb_out(rgb));
 task frame;begin @(negedge clk);sof=1;@(negedge clk);sof=0;end endtask
 task publish;begin @(negedge clk);update=1;@(negedge clk);update=0;end endtask
 task good;begin valid=1;confirmed=1;reason=0;tokens=40'hff_ff_03_0a_02;boxes=0;publish;frame;
  if(!cf||dut.holding_frame||dut.text_frame!=="2+3=5                           ")$fatal(1,"confirmed result");
 end endtask
 integer j,previous_ticks;
 initial begin
  repeat(4)@(negedge clk);rst_n=1;good;
  valid=0;confirmed=0;reason=6;publish;
  if(!cf||dut.holding_frame)$fatal(1,"midframe WAIT publication");frame;
  if(cf||!dut.holding_frame||dut.count_frame!=3||dut.text_frame!=="2+3=5                           ")$fatal(1,"brief miss not retained as WAIT");
  @(negedge clk);lp=1;@(negedge clk);lp=0;frame;if(locked)$fatal(1,"WAIT LAST locked");
  previous_ticks=dut.wait_ticks;
  for(j=0;j<3;j=j+1)begin repeat(8)@(negedge clk);publish;frame;end
  if(dut.wait_ticks<=previous_ticks+24)$fatal(1,"miss restarted grace timer");
  valid=1;confirmed=0;publish;frame;if(cf||!dut.holding_frame)$fatal(1,"same unconfirmed result should remain WAIT");
  good;if(!cf||dut.waiting)$fatal(1,"recovery before timeout");
  valid=0;confirmed=0;reason=5;publish;frame;repeat(85)@(negedge clk);
  if(dut.last_valid||dut.waiting)$fatal(1,"WAIT timeout did not run without observations");
  frame;if(cf||dut.holding_frame||dut.count_frame!=0||dut.text_frame!=="EXPR ?                          ")$fatal(1,"timeout did not clear");
  publish;frame;if(dut.holding_frame||dut.count_frame!=0)$fatal(1,"expired answer resurrected");
  good;tokens=40'hff_ff_04_0a_02;confirmed=0;publish;frame;
  if(cf||dut.holding_frame||dut.last_valid||dut.text_frame!=="2+4=?                           ")$fatal(1,"different expression reused old answer");
  good;confirmed=0;boxes[31:24]=20;publish;frame;if(dut.holding_frame||dut.last_valid)$fatal(1,"large motion retained old answer");
  good;valid=0;confirmed=0;reason=2;publish;frame;if(dut.holding_frame||dut.count_frame!=0)$fatal(1,"structural rejection retained answer");
  good;valid=0;confirmed=0;reason=6;publish;frame;en=0;frame;en=1;publish;frame;
  if(dut.holding_frame||dut.last_valid||cf)$fatal(1,"OFF retained history");
  // Consume one pending publication and receive another on the same SOF.
  valid=1;confirmed=0;reason=0;tokens=40'hff_ff_03_0a_02;publish;
  @(negedge clk);sof=1;update=1;tokens=40'hff_ff_04_0a_02;@(negedge clk);sof=0;update=0;
  if(!pending||dut.text_frame!=="2+3=?                           ")$fatal(1,"simultaneous SOF/update lost transaction");
  frame;if(dut.text_frame!=="2+4=?                           ")$fatal(1,"latest pending result lost");
  finished=1;$display("PASS WAIT_DISPLAY: frame-atomic WAIT LAST, no READY/lock during misses, nonrenewable wall-clock expiry, recovery, conflicting expression/motion/structural rejection, OFF reset, simultaneous SOF/update");
 end
endmodule
module tb_expression_stability;
 wire a,b,c;crop_stability_test #(.STABLE(1)) stable(a);crop_stability_test #(.STABLE(0)) bypass(b);wait_display_test display(c);
 initial begin wait(a&&b&&c);$display("PASS EXPRESSION_STABILITY_ALL");$finish;end
 initial begin #1000000000;$fatal(1,"stability suite timeout");end
endmodule
