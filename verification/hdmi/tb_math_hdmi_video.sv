`timescale 1ns/1ps
// Production 1080p60 raster into the production arithmetic/HDMI RGB wrapper.
// The encrypted TMDS encoder and DDR electrical model are outside this test.
module tb_math_hdmi_video;
 reg clk=0,pixel_clk=0;
 always #6.734 clk=~clk;
 always #3.367 pixel_clk=~pixel_clk;
 reg rst_n=0,arst_n=0,de=0,valid=0,hs=0,vs=0;
 reg [47:0] rgb=0;
 wire [47:0] pair;wire pd,pvalid,ph,pv,on_frame,detected;
 wire [23:0] hdmi_rgb;wire hdmi_de,hdmi_hs,hdmi_vs,fault;
 math_hdmi_video #(.SLIM_OSD(1'b0)) dut(
  .clk(clk),.pixel_clk(pixel_clk),.rst_n(rst_n),.arst_n(arst_n),
  .enable(1'b1),.expression_mode(1'b1),.lock_pulse(1'b0),
  .menu_page(2'd2),.osd_activity_toggle(1'b0),.osd_help_toggle(1'b0),.osd_context(3'd0),
  .rgb_in(rgb),.de_in(de),.valid_in(valid),.hs_in(hs),.vs_in(vs),
  .rgb_pair(pair),.de_pair(pd),.valid_pair(pvalid),.hs_pair(ph),.vs_pair(pv),
  .enabled_frame(on_frame),.detected_frame(detected),
  .hdmi_rgb(hdmi_rgb),.hdmi_de(hdmi_de),.hdmi_hs(hdmi_hs),.hdmi_vs(hdmi_vs),.fault(fault)
 );
 reg [7:0] images[0:1920*1080-1],expected[0:5*784-1],boxes[0:19];
 integer row,col,f,i,checks=0,starts=0,observations=0,red_checks=0;
 integer nn_checks=0;
 reg [3:0] labels[0:4];
 always @(posedge clk)if(rst_n)begin
  if(dut.pipeline.we)begin
   if(dut.pipeline.bit_in!==(expected[dut.pipeline.token_index*784+dut.pipeline.addr]!=0))
    $fatal(1,"HDMI normalization token%0d addr%0d",dut.pipeline.token_index,dut.pipeline.addr);
   checks=checks+1;
  end
  if(dut.pipeline.start)begin
   i=dut.pipeline.token_index*4;
   if({dut.pipeline.sel_x0,dut.pipeline.sel_x1,dut.pipeline.sel_y0,dut.pipeline.sel_y1}!=={boxes[i],boxes[i+1],boxes[i+2],boxes[i+3]})
    $fatal(1,"HDMI original bbox");
   starts=starts+1;
  end
  if(dut.pipeline.nn_done)begin
   if(labels[dut.pipeline.token_index]<10)begin
    if(dut.pipeline.number!==labels[dut.pipeline.token_index]||dut.pipeline.margin<300)$fatal(1,"HDMI digit");
   end else if(dut.pipeline.operator_symbol!==10)$fatal(1,"HDMI plus");
   nn_checks=nn_checks+1;
  end
  if(dut.pipeline.expr_done)observations=observations+1;
  if(pd&&pvalid&&dut.pipeline.detect_edgev[7:0]==255)begin
   if(dut.pipeline.red_edges[23:0]!==24'hff0000)$fatal(1,"HDMI R/B channel swap");
   red_checks=red_checks+1;
  end
 end

 // Observe exactly what the gearbox samples before each pair-clock NBA.
 // A bounded queue checks every transported blank and active pixel in order.
 reg [26:0] stream_expected[0:255];
 integer tail=0,head=0,stream_checks=0;
 reg active_before;
 always @(posedge clk)begin
  if(!arst_n)tail=0;
  else if(dut.gearbox.pair_reset[1])begin
   if(tail-head>250)$fatal(1,"test scoreboard overflow");
   stream_expected[tail&255]={pair[23:0],pd,ph,pv};
   stream_expected[(tail+1)&255]={pair[47:24],pd,ph,pv};
   tail=tail+2;
  end
 end
 reg old_h=0,old_v=0,old_d=0;
 integer pixel_cycle=0,last_h=-1,last_v=-1,hwidth=0,vwidth=0;
 integer hchecks=0,vchecks=0,active_lines=0,active_pixels=0,line_width=0,output_frames=0;
 reg capture_arm=0,capture_active=0,capture_done=0;
 integer fd=0,captured=0,captured_red=0;
 always @(posedge pixel_clk)begin
  if(!arst_n)begin head=0;stream_checks=0;old_h=0;old_v=0;old_d=0;pixel_cycle=0;end
  else begin
   active_before=dut.gearbox.pixel_reset[1]&&dut.gearbox.started;
   #0.1;
   if(fault)$fatal(1,"HDMI gearbox fault");
   if(active_before)begin
    if(head>=tail||{hdmi_rgb,hdmi_de,hdmi_hs,hdmi_vs}!==stream_expected[head&255])
     $fatal(1,"HDMI pair serialization index%0d got%h expected%h",head,{hdmi_rgb,hdmi_de,hdmi_hs,hdmi_vs},stream_expected[head&255]);
    head=head+1;stream_checks=stream_checks+1;pixel_cycle=pixel_cycle+1;
    if(hdmi_hs&&!old_h)begin
     if(last_h>=0&&output_frames>1)begin
      if(pixel_cycle-last_h!=2200)$fatal(1,"HDMI H total %0d",pixel_cycle-last_h);
      hchecks=hchecks+1;
     end
     last_h=pixel_cycle;hwidth=0;
    end
    if(hdmi_hs)hwidth=hwidth+1;
    if(!hdmi_hs&&old_h&&hchecks>0&&hwidth!=44)$fatal(1,"HDMI HS width %0d",hwidth);
    if(hdmi_vs&&!old_v)begin
     if(last_v>=0&&output_frames>1)begin
      if(pixel_cycle-last_v!=2475000)$fatal(1,"HDMI frame total %0d",pixel_cycle-last_v);
      if(active_lines!=1080||active_pixels!=2073600)$fatal(1,"HDMI active raster %0d lines %0d pixels",active_lines,active_pixels);
      vchecks=vchecks+1;
     end
     last_v=pixel_cycle;vwidth=0;active_lines=0;active_pixels=0;output_frames=output_frames+1;
     if(capture_active)begin
      capture_active=0;capture_done=1;$fclose(fd);
      if(captured!=2073600||captured_red==0)$fatal(1,"HDMI captured frame incomplete %0d red%0d",captured,captured_red);
     end else if(capture_arm&&!capture_done)begin
      capture_active=1;fd=$fopen("verification/hdmi/math_hdmi_confirmed_pixels.hex","w");
      if(fd==0)$fatal(1,"HDMI capture open failed");
     end
    end
    if(hdmi_vs)vwidth=vwidth+1;
    if(!hdmi_vs&&old_v&&output_frames>1&&vwidth!=11000)$fatal(1,"HDMI VS width %0d",vwidth);
    if(hdmi_de)begin
     line_width=line_width+1;active_pixels=active_pixels+1;
     if(capture_active)begin
      $fwrite(fd,"%06x\n",hdmi_rgb);captured=captured+1;
      if(hdmi_rgb==24'hff0000)captured_red=captured_red+1;
     end
    end
    if(!hdmi_de&&old_d)begin
     if(line_width!=1920)$fatal(1,"HDMI DE width %0d",line_width);
     active_lines=active_lines+1;line_width=0;
    end
    old_h=hdmi_hs;old_v=hdmi_vs;old_d=hdmi_de;
   end
  end
 end
 function [23:0] pixel;
  input integer xx,yy;reg [7:0] v;
  begin v=images[yy*1920+xx];pixel={v,v,v};end
 endfunction
 task frame;begin
  // Standard positive-polarity 1080p60: 2200 pixels x 1125 lines.
  // Pair raster: HS22, back74, active960, front44. VS5/back36/active1080/front4.
  for(row=0;row<1125;row=row+1)begin
   for(col=0;col<1100;col=col+1)begin
    @(negedge clk);hs=col<22;vs=row<5;
    de=col>=96&&col<1056&&row>=41&&row<1121;valid=de;
    if(de)rgb={pixel((col-96)*2+1,row-41),pixel((col-96)*2,row-41)};else rgb=0;
   end
  end
 end endtask
 initial begin
  if(dut.pipeline.expression_hud.WAIT_CYCLES!=14850000||dut.pipeline.prep.CROP_STABILIZE!=1)
   $fatal(1,"production stability/grace timer configuration");
  $readmemh("verification/number/expression_hd_images.mem",images);
  $readmemh("verification/number/expression_hd_padding_expected.mem",expected);
  $readmemh("verification/number/expression_hd_boxes.mem",boxes);
  labels[0]=1;labels[1]=2;labels[2]=10;labels[3]=3;labels[4]=4;
  repeat(8)@(negedge clk);arst_n=1;rst_n=1;
  for(f=0;f<20&&(f<4||!dut.pipeline.expr_confirmed_frame);f=f+1)frame;
  if(!dut.pipeline.expr_confirmed_frame||dut.pipeline.expression_hud.text_frame!=="12+34=46                        ")
   $fatal(1,"HDMI full-HD expression not confirmed");
  $display("HDMI expression confirmed after %0d input frames",f);
  capture_arm=1;
  for(f=0;f<3&&!capture_done;f=f+1)frame;
  if(!capture_done||checks<3*5*784||starts<15||observations<3||nn_checks<15||red_checks==0||vchecks<2)
   $fatal(1,"HDMI incomplete integration coverage");
  $display("PASS MATH_HDMI_VIDEO: HT1100/1125-line raster, %0d normalized bits, %0d symbols, %0d expressions, 12+34=46 READY, %0d serialized RGB/DE/HS/VS pixels, %0d complete 1080p frames, one %0d-pixel RGB capture, red channel correct, no gearbox fault",checks,starts,observations,stream_checks,vchecks,captured);
  $finish;
 end
 initial begin #600000000;$fatal(1,"HDMI video timeout");end
endmodule
