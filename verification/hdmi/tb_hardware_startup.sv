`timescale 1ns/1ps
module tb_hardware_startup;
 reg vid_clk_dvi2=0;always #6.734 vid_clk_dvi2=~vid_clk_dvi2;
 reg w_arstn=0,cal_done=0;
reg [1:0] cal_ready_sync;
always @(posedge vid_clk_dvi2 or negedge w_arstn) begin
    if(!w_arstn) cal_ready_sync<=0;
    else cal_ready_sync<={cal_ready_sync[0],cal_done};
end
reg [19:0] hdmi_start_count;
always @(posedge vid_clk_dvi2 or negedge w_arstn) begin
    if(!w_arstn) hdmi_start_count<=0;
    else if(!cal_ready_sync[1]) hdmi_start_count<=0;
    else if(!(&hdmi_start_count)) hdmi_start_count<=hdmi_start_count+1'b1;
end
wire pixel_data_en=&hdmi_start_count;
 integer n;
 initial begin
  #1;w_arstn=0;repeat(5)@(negedge vid_clk_dvi2);
  w_arstn=1;repeat(20)@(negedge vid_clk_dvi2);
  if(pixel_data_en!==0)$fatal(1,"started without calibration");
  cal_done=1;
  for(n=0;n<1048575;n=n+1)begin
   @(negedge vid_clk_dvi2);
   if(pixel_data_en!==0)$fatal(1,"startup delay too short");
  end
  repeat(8)@(negedge vid_clk_dvi2);
  if(pixel_data_en!==1)$fatal(1,"did not start");
  #2;w_arstn=0;#1;
  if(pixel_data_en!==0)$fatal(1,"PLL loss did not reset immediately");
  repeat(5)@(negedge vid_clk_dvi2);cal_done=0;w_arstn=1;
  repeat(20)@(negedge vid_clk_dvi2);
  if(pixel_data_en!==0)$fatal(1,"restart bypassed calibration");
  cal_done=1;repeat(1048585)@(negedge vid_clk_dvi2);
  if(pixel_data_en!==1)$fatal(1,"restart failed");
  cal_done=0;repeat(5)@(negedge vid_clk_dvi2);
  if(pixel_data_en!==0)$fatal(1,"calibration loss failed to gate output");
  $display("PASS HARDWARE_STARTUP no LED0 reset dependency, calibration sync, full 20-bit delay, PLL loss, restart, calibration loss");$finish;
 end
endmodule
