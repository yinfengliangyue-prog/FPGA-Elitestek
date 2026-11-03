// Regular display stream only: contiguous DE per row; fixed LINE_CLOCKS period.
// Complete frame with replicated top/bottom border. Bottom row flushed in V blank.
// Two alternating synchronous read-before-write row banks, no RAM reset.
module gaussian_vertical_sharpen_2ppc #(
 parameter WIDTH=1920,HEIGHT=1080,LINE_CLOCKS=1066,STRENGTH=8,DETAIL_LIMIT=16
)(input clk,rst,input [63:0] in_word,input in_de,in_hs,in_vs,
 output reg [47:0] out_rgb,output reg out_de,out_hs,out_vs);
 `include "enhance_math.vh"
 localparam PAIRS=WIDTH/2,BLANK=LINE_CLOCKS-PAIRS;
 reg [63:0] bank0[0:PAIRS-1],bank1[0:PAIRS-1];
 reg [63:0] read0,read1,pixel_d;
 reg [15:0] x,row_y,gap,y_d;
 reg previous_de,previous_vs,active_d,flush_d;
 wire flush=(row_y==HEIGHT) && !in_de && (gap>=BLANK) && (gap<LINE_CLOCKS);
 wire active=in_de||flush;
 always @(posedge clk)begin
  if(!rst && active)begin
   read0<=bank0[x];read1<=bank1[x];
   if(in_de)begin if(row_y[0])bank1[x]<=in_word;else bank0[x]<=in_word;end
  end
 end
 // Delay HS/VS by one complete line and the two arithmetic pipeline intervals.
 reg [1:0] sync_ram[0:LINE_CLOCKS-1];
 reg [15:0] sync_addr,warm;
 reg [1:0] sync0,sync1;
 always @(posedge clk)begin
  if(!rst)sync_ram[sync_addr]<={in_vs,in_hs};
 end
 wire [63:0] center=y_d[0]?read0:read1;
 wire [63:0] upper=(y_d==1)?center:(y_d[0]?read1:read0);
 wire [63:0] lower=flush_d?center:pixel_d;
 wire [9:0] sum0={2'd0,upper[55:48]}+({2'd0,center[55:48]}<<1)+{2'd0,lower[55:48]}+10'd2;
 wire [9:0] sum1={2'd0,upper[63:56]}+({2'd0,center[63:56]}<<1)+{2'd0,lower[63:56]}+10'd2;
 reg [47:0] center_rgb;
 reg [7:0] blur0,blur1;reg center_valid;
 integer detail0,detail1,delta0,delta1;
 always @* begin
  detail0=luminance(center_rgb[23:0])-blur0;
  detail1=luminance(center_rgb[47:24])-blur1;
  if(detail0>DETAIL_LIMIT)detail0=DETAIL_LIMIT;
  if(detail0< -DETAIL_LIMIT)detail0= -DETAIL_LIMIT;
  if(detail1>DETAIL_LIMIT)detail1=DETAIL_LIMIT;
  if(detail1< -DETAIL_LIMIT)detail1= -DETAIL_LIMIT;
  delta0=(detail0*STRENGTH+8)>>>4;delta1=(detail1*STRENGTH+8)>>>4;
 end
 always @(posedge clk)begin
  if(rst)begin
   x<=0;row_y<=0;gap<=0;previous_de<=0;previous_vs<=0;
   pixel_d<=0;y_d<=0;active_d<=0;flush_d<=0;center_rgb<=0;blur0<=0;blur1<=0;center_valid<=0;
   out_rgb<=0;out_de<=0;out_hs<=0;out_vs<=0;sync_addr<=0;warm<=0;sync0<=0;sync1<=0;
  end else begin
   previous_de<=in_de;previous_vs<=in_vs;
   if(in_vs && !previous_vs)row_y<=0;
   else if(previous_de && !in_de)row_y<=row_y+16'd1;
   if(in_de || (in_vs && !previous_vs))gap<=0;
   else if(gap<LINE_CLOCKS+1)gap<=gap+16'd1;
   if(active)x<=(x==PAIRS-1)?16'd0:x+16'd1;else x<=0;
   pixel_d<=in_word;y_d<=row_y;flush_d<=flush;
   active_d<=active && (row_y>=1) && (row_y<=HEIGHT);
   center_rgb<=center[47:0];blur0<=sum0[9:2];blur1<=sum1[9:2];center_valid<=active_d;
   out_rgb<={clip8(center_rgb[47:40]+delta1),clip8(center_rgb[39:32]+delta1),clip8(center_rgb[31:24]+delta1),
             clip8(center_rgb[23:16]+delta0),clip8(center_rgb[15:8]+delta0),clip8(center_rgb[7:0]+delta0)};
   out_de<=center_valid;
   sync_addr<=(sync_addr==LINE_CLOCKS-1)?16'd0:sync_addr+16'd1;
   if(warm<LINE_CLOCKS)begin warm<=warm+16'd1;sync0<=0;end else sync0<=sync_ram[sync_addr];
   sync1<=sync0;{out_vs,out_hs}<=sync1;
  end
 end
endmodule
