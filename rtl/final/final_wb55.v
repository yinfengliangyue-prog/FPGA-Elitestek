module final_wb55 #(parameter W=1920,H=1080,HT=1100,MIN_SAMPLES=256)(
 input wire clk,rst_n,lock_request,input wire [47:0] rgb_in,input wire de_in,hs_in,vs_in,
 output wire [47:0] rgb_out,output wire de_out,hs_out,vs_out,output reg locked,
 output wire rejected,output wire [11:0] gain_r,gain_g,gain_b);
 reg pending,oldvs;wire sof=de_in&&(pending||(vs_in&&!oldvs));
 wire [11:0] ar,ag,ab;wire updated;wire [31:0] samples;
 awb_rgbmean_2ppc #(.FALLBACK_ENABLE(1),.MIN_SAMPLES(MIN_SAMPLES)) estimator(
 .clk(clk),.rst(!rst_n),.enable(1'b1),.hold_gain(lock_request),.rgb(rgb_in),.de(de_in),.vs(vs_in),
 .gain_r(ar),.gain_g(ag),.gain_b(ab),.update_pulse(updated),.accepted_samples(samples),.rejected_frame(rejected));
 reg [11:0] applied_r,applied_g,applied_b,target_r,target_g,target_b;
 reg have_target;wire [23:0] green_product=ag*12'd224;
 wire [11:0] green_target=(green_product+24'd128)>>8;
 function [11:0] bound(input [11:0] n,lo,hi);bound=n<lo?lo:n>hi?hi:n;endfunction
 function [11:0] step(input [11:0] a,b);step=a<b?a+1'b1:a>b?a-1'b1:a;endfunction
 wire advance=sof&&!lock_request&&have_target;
 wire [11:0] nr=advance?step(applied_r,target_r):applied_r;
 wire [11:0] ng=advance?step(applied_g,target_g):applied_g;
 wire [11:0] nb=advance?step(applied_b,target_b):applied_b;
 assign gain_r=applied_r;assign gain_g=applied_g;assign gain_b=applied_b;
 always @(posedge clk)begin
 if(!rst_n)begin pending<=1;oldvs<=0;locked<=0;applied_r<=320;applied_g<=158;applied_b<=329;
 target_r<=320;target_g<=158;target_b<=329;have_target<=0;end
 else begin
 oldvs<=vs_in;if(vs_in&&!oldvs)pending<=1;
 if(updated&&!lock_request)begin target_r<=bound(ar,304,336);target_g<=bound(green_target,151,165);target_b<=bound(ab,313,345);have_target<=1;end
 if(rejected||lock_request)have_target<=0;
 if(sof)begin pending<=0;locked<=lock_request;applied_r<=nr;applied_g<=ng;applied_b<=nb;if(advance)have_target<=0;end
 end end
 wire [47:0] corrected;wire cd,ch,cv;
 color_enhance_rgb888 lane0(clk,!rst_n,rgb_in[23:0],de_in,sof,hs_in,vs_in,nr,ng,nb,1'b1,1'b0,corrected[23:0],cd,,ch,cv);
 color_enhance_rgb888 lane1(clk,!rst_n,rgb_in[47:24],de_in,sof,hs_in,vs_in,nr,ng,nb,1'b1,1'b0,corrected[47:24],,,,);
 wire [63:0] horizontal;wire hd,hh,hv;
 gaussian_horizontal_2ppc horizontal_filter(clk,!rst_n,corrected,cd,ch,cv,horizontal,hd,hh,hv);
 gaussian_vertical_sharpen_compact_2ppc #(.WIDTH(W),.HEIGHT(H),.LINE_CLOCKS(HT),.STRENGTH(4),.DETAIL_LIMIT(16)) vertical_filter(
 clk,!rst_n,horizontal,hd,hh,hv,rgb_out,de_out,hs_out,vs_out);
endmodule
