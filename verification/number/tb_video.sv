`timescale 1ns/1ps
module tb_video;
 reg clk=0;always #5 clk=~clk;
 reg rst_n=0,enable=0,de=0,valid=0,vs=0,hs=0;reg [47:0] rgb=48'hffffff_ffffff;
 wire [47:0] out_rgb;wire od,ov,oh,os,on_frame,detected;
 number_video_pipeline dut(.clk(clk),.rst_n(rst_n),.enable(enable),.expression_mode(1'b0),.lock_pulse(1'b0),.rgb_in(rgb),.de_in(de),.valid_in(valid),.hs_in(hs),.vs_in(vs),.threshold_in(8'd2),.rgb_out(out_rgb),.de_out(od),.valid_out(ov),.hs_out(oh),.vs_out(os),.enabled_frame(on_frame),.detected_frame(detected),.ui_expression_locked());
 reg [7:0] grid[0:36863],noise[0:36863],expected[0:783],expected_digit[0:0];integer norm_count=0,results=0,xx,yy,n;
 reg blank=0;integer frame_no=0,preview_file,output_frame=0,edge_count=0;
 reg [7:0] edge_expected[0:589823],strong_expected[0:589823];integer weak_excluded=0;
 always @(posedge clk)begin
  if(rst_n)begin
   if({od,ov,oh,os}!=={dut.edge_de,dut.edge_valid,dut.edge_hs,dut.edge_vs})$fatal(1,"video sync changed");
   if(dut.sof)output_frame=output_frame+1;
   if(od&&ov&&output_frame>=2&&!blank&&dut.px>=576&&dut.px<1344&&dut.y>=156&&dut.y<924)begin
    if((dut.edgev[7:0]==255)!==(edge_expected[(dut.y-156)*768+dut.px-576]!=0))$fatal(1,"Sobel pixel0 mismatch x=%0d y=%0d",dut.px,dut.y);
    if((dut.edgev[15:8]==255)!==(edge_expected[(dut.y-156)*768+dut.px-575]!=0))$fatal(1,"Sobel pixel1 mismatch");
    if((dut.detect_edgev[7:0]==255)!==(strong_expected[(dut.y-156)*768+dut.px-576]!=0))$fatal(1,"strong pixel0 mismatch");
    if((dut.detect_edgev[15:8]==255)!==(strong_expected[(dut.y-156)*768+dut.px-575]!=0))$fatal(1,"strong pixel1 mismatch");
    if(dut.edgev[7:0]==255&&dut.detect_edgev[7:0]==0)weak_excluded=weak_excluded+1;
    edge_count=edge_count+2;
   end
   if(od&&ov&&output_frame==10&&dut.y%2==0)$fdisplay(preview_file,"%06x",out_rgb[23:0]);
   if(dut.we)begin
    if(dut.bit_in!==(expected[dut.addr]!=0))$fatal(1,"fullhd normalized pixel mismatch %0d",dut.addr);
    norm_count=norm_count+1;
   end
   if(dut.nn_done)begin if(dut.number!==expected_digit[0][3:0])$fatal(1,"fullhd inference mismatch");results=results+1;end
   if(od&&ov&&dut.px>=300&&dut.px<500&&dut.y>300&&out_rgb!==dut.red_edges)$fatal(1,"camera pixels changed outside HUD/ROI");
  end
 end
 function [23:0] pixel;input integer x,y;integer idx;reg [7:0] paper;begin
  paper=248-8*((x/8+y/8)%2);pixel={paper,paper,paper};
  if(x>=576&&x<1344&&y>=156&&y<924)begin idx=((y-156)/4)*192+(x-576)/4;if(blank?noise[idx]!=0:grid[idx]!=0)pixel=24'h000000;end
 end endfunction
 task frame_start;begin
  @(negedge clk);de=0;valid=0;vs=1;repeat(5)@(negedge clk);vs=0;repeat(5)@(negedge clk);
 end endtask
 task frame;begin
  frame_no=frame_no+1;
  frame_start;
  for(yy=0;yy<1080;yy=yy+1)begin
   for(xx=0;xx<1920;xx=xx+2)begin
    @(negedge clk);de=1;valid=1;rgb={pixel(xx+1,yy),pixel(xx,yy)};

   end
   @(negedge clk);de=0;valid=0;hs=1;repeat(105)@(negedge clk);hs=0;
  end
  repeat(2000)@(negedge clk);
 end endtask
 initial begin
  preview_file=$fopen("verification/number/preview_fullhd.hex","w");
  $readmemh("verification/number/camera_strong_edges.mem",strong_expected);$readmemh("verification/number/camera_edges.mem",edge_expected);$readmemh("verification/number/camera_grid.mem",grid);$readmemh("verification/number/camera_noise_grid.mem",noise);$readmemh("verification/number/camera_expected.mem",expected);$readmemh("verification/number/camera_result.mem",expected_digit);
  repeat(5)@(negedge clk);rst_n=1;enable=1;
  repeat(10)frame;
  if(results<2||!detected||dut.result!==expected_digit[0][3:0])$fatal(1,"stable display failed results=%0d result=%0d",results,dut.result);
  for(n=0;n<784;n=n+1)if((dut.front?dut.preview1[n]:dut.preview0[n])!==(expected[n]!=0))$fatal(1,"preview mismatch");
  blank=1;repeat(6)frame;
  if(detected||dut.result!=15)$fatal(1,"stale result after blank");
  enable=0;frame_start;repeat(5)@(negedge clk);repeat(2300)@(negedge clk);if(on_frame||detected)$fatal(1,"disable failed");
  if(edge_count<589824)$fatal(1,"no Sobel pixels verified");
  if(weak_excluded<1000)$fatal(1,"weak texture was not exercised");
  $fclose(preview_file);
  $display("PASS VIDEO: independent dual-threshold Sobel reference, full-HD wide off-center digit + strong isolated specks, pixel continuity + CCL + area bits, MLP/preview, noise-only clears result, weak excluded=%0d",weak_excluded);$finish;
 end
 initial begin #250000000;$fatal(1,"timeout");end
endmodule
