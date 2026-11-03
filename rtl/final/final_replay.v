// Saved NMS can be reclassified with each window's H/L, with two bounded
// eight-neighbor passes. H6/L3 uses captured ORIGINAL-RESOLUTION 49 BAL/CLEAN.
// Changed H/L is a frozen-image preview: the new linked mask gates captured
// brightness. Newly accepted blocks use CLEAN's conservative strength rule.
// Continuity is never substituted with a thumbnail-resolution calculation.
module final_replay #(parameter W=1920,H=1080,HT=1066,PANEL_SWAP_RB_ON_EDGE=1,COMMON_MODE=0)(
 input wire clk,rst_n,input wire [127:0] pixels,input wire [5:0] modes,
 input wire [3:0] classes,input wire de,hs,vs,
 output reg [47:0] rgb_out,output reg de_out,hs_out,vs_out
);
 localparam L=2*(HT+5)-1;
 wire [3:0] c1,c2;wire d1,v1,h1,s1,d2,v2,h2,s2;
 canny_link_2ppc #(.W(W),.H(H),.HT(HT)) pass1(clk,rst_n,classes,de,de,hs,vs,c1,d1,v1,h1,s1);
 canny_link_2ppc #(.W(W),.H(H),.HT(HT)) pass2(clk,rst_n,c1,d1,v1,h1,s1,c2,d2,v2,h2,s2);
 function [7:0] tone(input [7:0] m);
 begin case(m)
 `include "rtl/final/edge_tone.vh"
 endcase end endfunction
 // Select and precompute the display gray BEFORE alignment, then discard
 // both NMS and accepted magnitudes. Only accepted's nonzero flag is needed
 // for exact-default acceptance. Independent lane modes remain supported.
 function [24:0] compact(input [63:0] p,input [2:0] mode);
 reg [7:0] selected,strength;
 begin
  selected=mode==2?p[31:24]:p[23:16];strength=p[47:40];
  if(!p[15]&&selected==0)selected=strength<16?{strength[5:0],2'b0}:tone(strength);
  compact={p[39:32]!=0,selected,p[15:0]};
 end endfunction
 wire [55:0] delayed;
 generate if(COMMON_MODE)begin:common_display_mode
 wire [52:0] common_delayed;
 canny_delay #(.WIDTH(53),.DEPTH(L)) alignment(
  clk,rst_n,{modes[2:0],compact(pixels[127:64],modes[2:0]),compact(pixels[63:0],modes[2:0])},common_delayed);
 assign delayed={common_delayed[52:50],common_delayed};
 // synthesis translate_off
 always @(posedge clk)if(rst_n&&de&&modes[5:3]!==modes[2:0])$fatal(1,"Common-mode display requires identical lane modes");
 // synthesis translate_on
 end else begin:independent_modes
 canny_delay #(.WIDTH(56),.DEPTH(L)) alignment(
  clk,rst_n,{modes,compact(pixels[127:64],modes[5:3]),compact(pixels[63:0],modes[2:0])},delayed);
 end endgenerate
 function [23:0] unpack554(input [13:0] p);
 unpack554={p[13:9],p[13:11],p[8:4],p[8:6],p[3:0],p[3:0]};
 endfunction
 function [23:0] render(input [24:0] p,input [2:0] mode,input linked);
 reg [23:0] color;reg [15:0] g;reg [7:0] gray;
 begin
 color=unpack554(p[13:0]);linked=p[15]?p[24]:linked;
 g=16'd77*color[23:16]+16'd150*color[15:8]+16'd29*color[7:0];
 gray=p[23:16];
 if(p[14])render=color;
 else case(mode)
  1:render=linked?(PANEL_SWAP_RB_ON_EDGE?24'h0000ff:24'hff0000):color;
  2,4:render=linked?{3{gray}}:24'd0;
  3:render={3{g[15:8]}};
  default:render=color;
 endcase
 end endfunction
 always @(posedge clk)begin
 if(!rst_n)begin rgb_out<=0;de_out<=0;hs_out<=0;vs_out<=0;end
 else begin
  rgb_out<=d2?{render(delayed[49:25],delayed[55:53],c2[3]),render(delayed[24:0],delayed[52:50],c2[1])}:48'd0;
  de_out<=d2;hs_out<=h2;vs_out<=s2;
 end end
endmodule
