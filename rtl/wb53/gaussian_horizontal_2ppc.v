// Each word is {RGB888 lane1,RGB888 lane0}; lane0 is spatially first.
// Replicate left/right border; use one-word lookahead; no pixel cropping.
// RGB and horizontal luminance blur are packed into a 64-bit word.
module gaussian_horizontal_2ppc (
 input clk,rst,input [47:0] in_rgb,input in_de,in_hs,in_vs,
 output reg [63:0] out_word,output reg out_de,out_hs,out_vs);
 `include "enhance_math.vh"
 reg [47:0] previous;
 reg [7:0] previous_y0,previous_y1,left_y;
 reg previous_de,hs_d,vs_d;
 wire [7:0] y0=luminance(in_rgb[23:0]),y1=luminance(in_rgb[47:24]);
 wire [7:0] right_y=in_de?y0:previous_y1;
 wire [9:0] blur0={2'd0,left_y}+({2'd0,previous_y0}<<1)+{2'd0,previous_y1}+10'd2;
 wire [9:0] blur1={2'd0,previous_y0}+({2'd0,previous_y1}<<1)+{2'd0,right_y}+10'd2;
 always @(posedge clk)begin
  if(rst)begin previous<=0;previous_y0<=0;previous_y1<=0;left_y<=0;
   previous_de<=0;hs_d<=0;vs_d<=0;out_word<=0;out_de<=0;out_hs<=0;out_vs<=0;end
  else begin
   out_word<={blur1[9:2],blur0[9:2],previous};out_de<=previous_de;out_hs<=hs_d;out_vs<=vs_d;
   previous<=in_rgb;previous_y0<=y0;previous_y1<=y1;
   left_y<=previous_de?previous_y1:y0;
   previous_de<=in_de;hs_d<=in_hs;vs_d<=in_vs;
  end
 end
endmodule
