`timescale 1ns/1ps
module tb_targets;
 reg clk=0;always #5 clk=~clk;
 reg rst_n=0,en=1,de=0,valid=0,hs=0,vs=0;reg [47:0] rgb=0;
 wire [47:0] out_rgb;wire od,ov,oh,os,on_frame,detected;
 number_video_pipeline #(.IMG_W(480),.IMG_H(384),.ROI_SIZE(320),.ROI_X(80),.ROI_Y(32),.H_TOTAL_BEATS(250)) dut(
 .clk(clk),.rst_n(rst_n),.enable(en),.expression_mode(1'b0),.lock_pulse(1'b0),.rgb_in(rgb),.de_in(de),.valid_in(valid),.hs_in(hs),.vs_in(vs),.threshold_in(8'd2),.rgb_out(out_rgb),.de_out(od),.valid_out(ov),.hs_out(oh),.vs_out(os),.enabled_frame(on_frame),.detected_frame(detected),.ui_expression_locked());
 reg [7:0] images[0:5*480*384-1],expected[0:5*784-1],boxes[0:19],labels[0:4];
 integer scene=0,capture=0,nn_scene=0,count=0,starts=0,predictions=0,checks=0,x,y,f,idx;
 reg published=0;integer display_scene=0;
 always @(posedge clk)if(rst_n)begin
  if(dut.prep.sof&&dut.prep.state==0&&!(dut.nn_busy|dut.pending))capture=scene;
  if(dut.we)begin
   if(dut.bit_in!==(expected[capture*784+dut.addr]!=0))$fatal(1,"target normalization mismatch scene=%0d index=%0d",capture,dut.addr);
   count=count+1;
  end
  if(dut.start)begin
   if({dut.sel_x0,dut.sel_x1,dut.sel_y0,dut.sel_y1}!=={boxes[capture*4],boxes[capture*4+1],boxes[capture*4+2],boxes[capture*4+3]})$fatal(1,"target selection mismatch scene=%0d",capture);
   nn_scene=capture;starts=starts+1;
  end
  if(dut.nn_done)begin
   if(dut.number!==labels[nn_scene][3:0])$fatal(1,"target MLP mismatch scene=%0d got=%0d",nn_scene,dut.number);
   predictions=predictions+1;
  end
  if(dut.sof&&dut.pending)begin published=1;display_scene=nn_scene;end
  // Check painted box coordinates at the left border, away from HUD/crosshair.
  if(od&&ov&&dut.box_valid&&dut.y==32+dut.box_y0*4+4&&dut.px==80+dut.box_x0*4)begin
   if(out_rgb[23:0]!==((dut.result<10)?24'h00ff00:24'h00ffff))$fatal(1,"painted target-box coordinate mismatch");
   checks=checks+1;
  end
 end
 function [23:0] pixel;input integer xx,yy;reg [7:0] v;begin v=images[scene*480*384+yy*480+xx];pixel={v,v,v};end endfunction
 task frame;begin
  @(negedge clk);de=0;valid=0;vs=1;repeat(5)@(negedge clk);vs=0;repeat(5)@(negedge clk);
  for(y=0;y<384;y=y+1)begin
   for(x=0;x<480;x=x+2)begin @(negedge clk);de=1;valid=1;rgb={pixel(x+1,y),pixel(x,y)};end
   @(negedge clk);de=0;valid=0;hs=1;repeat(9)@(negedge clk);hs=0;
  end
  repeat(1200)@(negedge clk);
 end endtask
 initial begin
  $readmemh("verification/number/targets33_images.mem",images);$readmemh("verification/number/targets33_inputs.mem",expected);
  $readmemh("verification/number/targets33_boxes.mem",boxes);$readmemh("verification/number/targets33_labels.mem",labels);
  repeat(5)@(negedge clk);rst_n=1;
  for(scene=0;scene<5;scene=scene+1)begin
   for(f=0;f<20;f=f+1)frame;
   if(dut.result!==labels[scene][3:0]||dut.box_valid!==(scene!=4))$fatal(1,"target final display scene=%0d result=%0d",scene,dut.result);
   if(scene<4)for(idx=0;idx<784;idx=idx+1)if((dut.front?dut.preview1[idx]:dut.preview0[idx])!==(expected[scene*784+idx]!=0))$fatal(1,"target final preview mismatch scene=%0d",scene);
  end
  if(predictions<12||checks<10)$fatal(1,"insufficient full-path coverage");
  $display("PASS TARGETS33: centre selection over larger neighbour, moved7, thin8, thin0, blank; %0d inferences, %0d painted box rows",predictions,checks);$finish;
 end
 initial begin #150000000;$fatal(1,"timeout");end
endmodule
