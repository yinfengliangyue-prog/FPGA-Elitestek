// Camera display integration. Full WIDTH*HEIGHT pixels, original RGB byte order.
module wb53_ref #(
 parameter LIVE_CONTROL=0,OSD_ENABLE=1,KEY_DEBOUNCE=1400000,
 parameter WIDTH=1920,HEIGHT=1080,LINE_CLOCKS=1066,
 parameter GAIN_R=256,GAIN_G=256,GAIN_B=256,TONE_ENABLE=1,
 parameter AWB_ENABLE=1,AWB_HOLD=0,AWB_MIN_SAMPLES=256,SHARP_ENABLE=1,
 parameter SHARP_STRENGTH=4,DETAIL_LIMIT=16,GREEN_SCALE_Q8=256
)(input clk,rst,input [47:0] in_rgb,input in_de,in_hs,in_vs,
 output [47:0] out_rgb,output out_de,out_hs,out_vs, input [3:0] key_n,output [1:0] wb_mode,output wb_rejected,input [11:0] ref_r,ref_g,ref_b);
 reg frame_pending,previous_vs;
 wire sof=in_de && (frame_pending || (in_vs && !previous_vs));
 always @(posedge clk)begin
  if(rst)begin frame_pending<=1;previous_vs<=0;end
  else begin previous_vs<=in_vs;
   if(in_vs && !previous_vs)frame_pending<=1;
   if(sof)frame_pending<=0;
  end
 end
 wire [11:0] auto_r,auto_g,auto_b;
 wire awb_update,awb_rejected,live_hold;wire [31:0] awb_sample_count;
 awb_rgbmean_2ppc #(.MIN_SAMPLES(AWB_MIN_SAMPLES),.FALLBACK_ENABLE(LIVE_CONTROL)) awb(
  .clk(clk),.rst(rst),.enable(AWB_ENABLE[0]),.hold_gain(AWB_HOLD[0] | (LIVE_CONTROL && live_hold)),
  .rgb(in_rgb),.de(in_de),.vs(in_vs),.gain_r(auto_r),.gain_g(auto_g),.gain_b(auto_b),
  .update_pulse(awb_update),.accepted_samples(awb_sample_count),.rejected_frame(awb_rejected));
 wire [11:0] selected_r,selected_g,selected_b;wire [1:0] control_channel;wire control_fine;
 assign wb_rejected=awb_rejected;
 generate if(LIVE_CONTROL)begin: live
  wire [3:0] command;wire command_valid;wire [1:0] channel;
  assign control_channel=channel;
  wb_key_events #(.DEBOUNCE_CYCLES(KEY_DEBOUNCE)) keys(
   .clk(clk),.rst_n(~rst),.key_n(key_n),.command(command),.command_valid(command_valid));
  wb_live_control #(.RGB_AUTO(1)) control(.clk(clk),.rst(rst),.sof(sof),.command(command),.command_valid(command_valid),
   .auto_r(auto_r),.auto_g(auto_g),.auto_b(auto_b),.rejected(awb_rejected),.mode(wb_mode),.channel(channel),
   .gain_r(selected_r),.gain_g(selected_g),.gain_b(selected_b),.hold_gain(live_hold),.fine_step(control_fine));
 end else begin: fixed
  assign control_fine=0;assign live_hold=0;assign wb_mode=0;assign control_channel=0;
  assign selected_r=ref_r;
  assign selected_g=ref_g;
  assign selected_b=ref_b;
 end endgenerate
 // Apply the green trim after AUTO/LOCK/MANUAL selection, before gamma.
 // AWB measures the untrimmed camera input, so it cannot cancel this trim.
 // Controller snapshots remain untrimmed: LOCK and mode changes apply it once.
 wire [23:0] green_product=selected_g*GREEN_SCALE_Q8;
 wire [24:0] green_rounded={1'b0,green_product}+25'd128;
 wire [11:0] effective_g=(green_rounded>>8)>4095 ? 12'hfff : green_rounded[19:8];
 wire [47:0] corrected;wire cd,ch,cv,unused;
 color_enhance_rgb888 lane0(.clk(clk),.rst(rst),.in_rgb(in_rgb[23:0]),.in_de(in_de),.in_sof(sof),
  .in_hsync(in_hs),.in_vsync(in_vs),.cfg_gain_r(selected_r),.cfg_gain_g(effective_g),.cfg_gain_b(selected_b),
  .cfg_tone(TONE_ENABLE[0]),.cfg_bypass(1'b0),.out_rgb(corrected[23:0]),.out_de(cd),.out_sof(unused),.out_hsync(ch),.out_vsync(cv));
 color_enhance_rgb888 lane1(.clk(clk),.rst(rst),.in_rgb(in_rgb[47:24]),.in_de(in_de),.in_sof(sof),
  .in_hsync(in_hs),.in_vsync(in_vs),.cfg_gain_r(selected_r),.cfg_gain_g(effective_g),.cfg_gain_b(selected_b),
  .cfg_tone(TONE_ENABLE[0]),.cfg_bypass(1'b0),.out_rgb(corrected[47:24]),.out_de(),.out_sof(),.out_hsync(),.out_vsync());
 wire [47:0] video_rgb;wire video_de,video_hs,video_vs;
 generate if(SHARP_ENABLE)begin: sharpen
 wire [63:0] horizontal;wire hd,hh,hv;
 gaussian_horizontal_2ppc horizontal_filter(clk,rst,corrected,cd,ch,cv,horizontal,hd,hh,hv);
 gaussian_vertical_sharpen_2ppc #(.WIDTH(WIDTH),.HEIGHT(HEIGHT),.LINE_CLOCKS(LINE_CLOCKS),
  .STRENGTH(SHARP_STRENGTH),.DETAIL_LIMIT(DETAIL_LIMIT)) vertical_filter(clk,rst,horizontal,hd,hh,hv,video_rgb,video_de,video_hs,video_vs);
 end else begin: color_only
 assign video_rgb=corrected;assign video_de=cd;assign video_hs=ch;assign video_vs=cv;
 end endgenerate
 generate if(LIVE_CONTROL && OSD_ENABLE)begin: status_overlay
  wb_status_osd osd(.clk(clk),.rst(rst),.cfg_sof(sof),.cfg_mode(wb_mode),.cfg_channel(control_channel),
   .cfg_r(selected_r),.cfg_g(effective_g),.cfg_b(selected_b),.cfg_rejected(awb_rejected),
   .in_rgb(video_rgb),.in_de(video_de),.in_hs(video_hs),.in_vs(video_vs),
   .out_rgb(out_rgb),.out_de(out_de),.out_hs(out_hs),.out_vs(out_vs),.cfg_fine(control_fine));
 end else begin: no_overlay
  assign out_rgb=video_rgb;assign out_de=video_de;assign out_hs=video_hs;assign out_vs=video_vs;
 end endgenerate
endmodule
