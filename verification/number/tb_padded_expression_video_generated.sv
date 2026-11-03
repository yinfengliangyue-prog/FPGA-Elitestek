`timescale 1ns/1ps
module tb_expression_video;
 reg clk=0;always #5 clk=~clk;
 reg rst_n=0,en=0,em=1,lp=0,de=0,valid=0,hs=0,vs=0;reg [47:0] rgb=0;
 wire [47:0] out_rgb;wire od,ov,oh,os,on_frame,detected;
 number_video_pipeline #(.IMG_W(640),.IMG_H(512),.ROI_SIZE(448),.ROI_X(96),.ROI_Y(32),.H_TOTAL_BEATS(330)) dut(
 .clk(clk),.rst_n(rst_n),.enable(en),.expression_mode(em),.lock_pulse(lp),.rgb_in(rgb),.de_in(de),.valid_in(valid),.hs_in(hs),.vs_in(vs),.threshold_in(8'd2),.rgb_out(out_rgb),.de_out(od),.valid_out(ov),.hs_out(oh),.vs_out(os),.enabled_frame(on_frame),.detected_frame(detected),.ui_expression_locked());
 reg [7:0] images[0:8*640*512-1],expected[0:22*784-1],boxes[0:22*4-1],lengths[0:7],tokens[0:21];
 integer scene=0,x,y,f,base=0,idx=0,checks=0,starts=0,observations=0,paint_checks=0,token_checks=0,oldobs=0;
 reg [159:0] locked_boxes;reg [255:0] locked_text;
 always @(posedge clk)if(rst_n&&en)begin
  if(dut.we&&scene<6)begin
   if(dut.bit_in!==(expected[(base+dut.token_index)*784+dut.addr]!=0))$fatal(1,"expression normalization scene%0d token%0d addr%0d",scene,dut.token_index,dut.addr);
   checks=checks+1;
  end
  if(dut.start&&scene<6)begin
   idx=base+dut.token_index;
   if({dut.sel_x0,dut.sel_x1,dut.sel_y0,dut.sel_y1}!=={boxes[idx*4],boxes[idx*4+1],boxes[idx*4+2],boxes[idx*4+3]})$fatal(1,"expression bbox scene%0d token%0d",scene,dut.token_index);
   starts=starts+1;
  end
  if(dut.nn_done&&scene<6)begin
   idx=base+dut.token_index;
   if(tokens[idx]<10)begin if(dut.number!==tokens[idx][3:0])$fatal(1,"expression digit mismatch");end
   else if(dut.operator_symbol!==tokens[idx][3:0])$fatal(1,"expression operator mismatch");
   token_checks=token_checks+1;
  end
  if(dut.expr_done)observations=observations+1;
  if(od&&ov&&scene<6&&dut.expr_confirmed_frame&&dut.y==32+boxes[base*4+2]*4+4&&dut.px==96+boxes[base*4]*4)begin
   if(out_rgb[23:0]!==24'h00ff00)$fatal(1,"painted expression box mismatch");
   paint_checks=paint_checks+1;
  end
 end
 function [23:0] pixel;input integer xx,yy;reg [7:0] v;begin v=images[scene*640*512+yy*640+xx];pixel={v,v,v};end endfunction
 task frame;begin
  @(negedge clk);de=0;valid=0;vs=1;repeat(5)@(negedge clk);vs=0;repeat(5)@(negedge clk);
  for(y=0;y<512;y=y+1)begin
   for(x=0;x<640;x=x+2)begin @(negedge clk);de=1;valid=1;rgb={pixel(x+1,y),pixel(x,y)};end
   @(negedge clk);de=0;valid=0;hs=1;repeat(9)@(negedge clk);hs=0;
  end
  repeat(2000)@(negedge clk);
 end endtask
 task check_text;input [255:0] text;begin if(dut.expression_hud.text_frame!==text)$fatal(1,"expression text scene%0d got '%s' expected '%s'",scene,dut.expression_hud.text_frame,text);end endtask
 initial begin
  $readmemh("verification/number/expression_images.mem",images);$readmemh("verification/number/expression_padding_expected.mem",expected);$readmemh("verification/number/expression_boxes.mem",boxes);$readmemh("verification/number/expression_lengths.mem",lengths);$readmemh("verification/number/expression_tokens.mem",tokens);
  repeat(5)@(negedge clk);rst_n=1;
  for(scene=0;scene<8;scene=scene+1)begin
   en=0;frame;en=1;
   if(scene<6)begin for(f=0;f<20&&(f<3||!dut.expr_confirmed_frame);f=f+1)frame;end
   else repeat(5)frame;
   $display("EXPR scene %0d complete, observations=%0d",scene,observations);
   if(dut.expr_confirmed_frame!==(scene<6))$fatal(1,"expression confirmation scene%0d obs%0d got%0d",scene,observations,dut.expr_confirmed_frame);
   case(scene)
    0:check_text("2+3=5                           ");
    1:check_text("7-9=-2                          ");
    2:check_text("8X2=16                          ");
    3:check_text("9/4=2 R1                        ");
    4:check_text("12+34=46                        ");
    5:check_text("11+11=22                        ");
   endcase
   if(scene==5)begin
    locked_text=dut.expression_hud.text_frame;locked_boxes=dut.expression_hud.boxes_frame;
    @(negedge clk);lp=1;@(negedge clk);lp=0;frame;
    if(!dut.expr_locked)$fatal(1,"confirmed lock ignored");oldobs=observations;
    scene=7;repeat(3)frame;scene=5;
    if(dut.expression_hud.text_frame!==locked_text||dut.expression_hud.boxes_frame!==locked_boxes||observations!=oldobs)$fatal(1,"lock mutated result or kept inference running");
    @(negedge clk);lp=1;@(negedge clk);lp=0;frame;
    if(dut.expr_locked||dut.expr_confirmed_frame)$fatal(1,"unlock retained confirmed stale answer");
   end
   base=base+lengths[scene];
  end
  // Mode changes abort work and reset the complete-expression history.
  em=0;frame;if(dut.expression_frame||dut.expr_confirmed_frame)$fatal(1,"NUMBER switch failed");
  em=1;frame;if(dut.expr_confirmed_frame)$fatal(1,"EXPR switch retained old answer");
  if(checks<22*784||starts<22||observations<18||paint_checks<6||token_checks<22)$fatal(1,"insufficient full expression coverage");
  $display("PASS EXPRESSION_VIDEO: real Sobel/continuity/CCL/segmentation/normalization/shared MLP/operators/arithmetic/filter/OSD; %0d crop bits %0d tokens %0d analyses %0d box rows; repeated digits, two-digit operands, negative, remainder, invalid/blank, lock/unlock, mode switch",checks,token_checks,observations,paint_checks);$finish;
 end
 initial begin #600000000;$fatal(1,"timeout");end
endmodule
