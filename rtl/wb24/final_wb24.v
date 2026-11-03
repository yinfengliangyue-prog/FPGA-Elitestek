// Full-precision RGB888 statistics, gain, reference Gamma 2.2 and mild sharpening.
// Exposure is outside this module and stays at the FINAL01 half-exposure table.
module final_wb24 #(parameter W=1920,H=1080,HT=1066,MIN_SAMPLES=256,FALLBACK_MIN_SAMPLES=1024,RGB_AUTO=1)(
 input clk,rst_n,lock_request,input [47:0] rgb_in,input de_in,hs_in,vs_in,
 output [47:0] rgb_out,output de_out,hs_out,vs_out,output reg locked,output rejected,
 output [11:0] gain_r,gain_g,gain_b
);
 reg pending,previous_vs,request_d,lock_state;
 reg [11:0] applied_r,applied_g,applied_b,locked_r,locked_g,locked_b;
 wire sof=de_in&&(pending||(vs_in&&!previous_vs));
 wire [11:0] auto_r,auto_g,auto_b;
 wire [11:0] selected_r=lock_state?locked_r:auto_r;
 wire [11:0] selected_g=lock_state?locked_g:auto_g;
 wire [11:0] selected_b=lock_state?locked_b:auto_b;
 assign gain_r=applied_r;assign gain_g=applied_g;assign gain_b=applied_b;
 always @(posedge clk)begin
  if(!rst_n)begin pending<=1;previous_vs<=0;request_d<=0;lock_state<=0;locked<=0;
   applied_r<=256;applied_g<=256;applied_b<=256;locked_r<=256;locked_g<=256;locked_b<=256;end
  else begin
   previous_vs<=vs_in;request_d<=lock_request;
   if(vs_in&&!previous_vs)pending<=1;
   if(sof)begin pending<=0;applied_r<=selected_r;applied_g<=selected_g;applied_b<=selected_b;locked<=lock_state;end
   if(lock_request!=request_d)begin
    lock_state<=lock_request;
    if(lock_request)begin locked_r<=sof?selected_r:applied_r;locked_g<=sof?selected_g:applied_g;locked_b<=sof?selected_b:applied_b;end
   end
  end
 end
 generate if(RGB_AUTO)begin:rgb_auto
 awb_grayworld_rgb_2ppc #(.FALLBACK_ENABLE(1),.MIN_SAMPLES(MIN_SAMPLES),.FALLBACK_MIN_SAMPLES(FALLBACK_MIN_SAMPLES)) estimator(
 .clk(clk),.rst(!rst_n),.enable(1'b1),.hold_gain(lock_state),.rgb(rgb_in),.de(de_in),.vs(vs_in),
 .gain_r(auto_r),.gain_g(auto_g),.gain_b(auto_b),.update_pulse(),.accepted_samples(),.rejected_frame(rejected));
 end else begin:legacy_auto
 assign auto_g=12'd256;
 awb_grayworld_2ppc #(.FALLBACK_ENABLE(1),.MIN_SAMPLES(MIN_SAMPLES),.FALLBACK_MIN_SAMPLES(FALLBACK_MIN_SAMPLES)) estimator(
 .clk(clk),.rst(!rst_n),.enable(1'b1),.hold_gain(lock_state),.rgb(rgb_in),.de(de_in),.vs(vs_in),
 .gain_r(auto_r),.gain_b(auto_b),.update_pulse(),.accepted_samples(),.rejected_frame(rejected));
 end endgenerate
 wire [47:0] corrected;wire cd,ch,cv;
 color_enhance_rgb888 lane0(clk,!rst_n,rgb_in[23:0],de_in,sof,hs_in,vs_in,selected_r,selected_g,selected_b,1'b1,1'b0,corrected[23:0],cd,,ch,cv);
 color_enhance_rgb888 lane1(clk,!rst_n,rgb_in[47:24],de_in,sof,hs_in,vs_in,selected_r,selected_g,selected_b,1'b1,1'b0,corrected[47:24],,,,);
 wire [63:0] horizontal;wire hd,hh,hv;
 gaussian_horizontal_2ppc horizontal_filter(clk,!rst_n,corrected,cd,ch,cv,horizontal,hd,hh,hv);
 gaussian_vertical_sharpen_compact_2ppc #(.WIDTH(W),.HEIGHT(H),.LINE_CLOCKS(HT),.STRENGTH(4),.DETAIL_LIMIT(16)) vertical_filter(
 clk,!rst_n,horizontal,hd,hh,hv,rgb_out,de_out,hs_out,vs_out);
endmodule
