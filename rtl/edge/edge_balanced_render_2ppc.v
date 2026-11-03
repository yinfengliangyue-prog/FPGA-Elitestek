`timescale 1ns/1ps
// The 49 display transform, after the final Canny mask. Window memories carry
// only directional support bits; one shared delay preserves the magnitudes.
// Exact 49 BAL/CLEAN values, borders and latency: L=4*HT+19 intervals.
module edge_balanced_render_2ppc #(
 parameter W=1920,H=1080,HT=1100,CFG_ENABLE=1
)(
 input wire clk,rst_n,input wire [15:0] strength,
 input wire de,hs,vs,input wire [18:0] cfg,
 output wire [15:0] gray,clean,bw,output wire ode,ohs,ovs,output wire [18:0] ocfg
);
 wire [3:0] thresholds={strength[15:8]>=16,strength[15:8]>=5,
                        strength[7:0]>=16,strength[7:0]>=5};
 wire [7:0] flags1,flags2;wire d1,h1,s1,d2,h2,s2;
 // Per-pixel flags [1:0]=ordinary horizontal/vertical, [3:2]=strong H/V.
 edge_balance_geometry #(.W(W),.H(H),.HT(HT),.FIRST(1)) first(
  clk,rst_n,thresholds,de,hs,vs,flags1,d1,h1,s1);
 edge_balance_geometry #(.W(W),.H(H),.HT(HT),.FIRST(0)) second(
  clk,rst_n,flags1,d1,h1,s1,flags2,d2,h2,s2);
 wire [3:0] flags3,flags4;wire d3,h3,s3;
 edge_balance_axis #(.W(W),.H(H),.HT(HT)) third(
  clk,rst_n,{flags2[5:4],flags2[1:0]},d2,h2,s2,flags3,d3,h3,s3);
 edge_balance_axis #(.W(W),.H(H),.HT(HT)) fourth(
  clk,rst_n,flags3,d3,h3,s3,flags4,ode,ohs,ovs);
 wire [15:0] original;
 canny_delay #(.WIDTH(16),.DEPTH(4*HT+19)) magnitude_alignment(
  clk,rst_n,strength,original);
 wire [1:0] strong_support;
 canny_delay #(.WIDTH(2),.DEPTH(2*(HT+5)-1)) strong_alignment(
  clk,rst_n,{|flags2[7:6],|flags2[3:2]},strong_support);
 generate if(CFG_ENABLE)begin:settings_enabled
  canny_delay #(.WIDTH(19),.DEPTH(4*HT+19)) settings(clk,rst_n,cfg,ocfg);
 end else begin:no_settings
  assign ocfg=19'd0;
 end endgenerate
 function [7:0] tone(input [7:0] m);
 begin case(m)
 `include "rtl/final/edge_tone.vh"
 endcase end endfunction
 function [7:0] render_clean(input [7:0] s,input line_ok);
 begin
  if(s<16)render_clean={s[5:0],2'b0};
  else if(line_ok)render_clean=8'd192+{2'b0,s[7:2]};
  else render_clean=tone(s);
 end endfunction
 function [7:0] render_balance(input [7:0] s,c,input line_ok);
 begin
  if(s>=5&&s<16&&line_ok)render_balance=8'd112+s+{s[6:0],1'b0};
  else render_balance=c;
 end endfunction
 wire [7:0] c0=render_clean(original[7:0],strong_support[0]);
 wire [7:0] c1=render_clean(original[15:8],strong_support[1]);
 assign clean=ode?{c1,c0}:16'd0;
 assign gray=ode?{render_balance(original[15:8],c1,|flags4[3:2]),
                  render_balance(original[7:0],c0,|flags4[1:0])}:16'd0;
 assign bw=ode?{original[15:8]!=0?8'hff:8'd0,original[7:0]!=0?8'hff:8'd0}:16'd0;
endmodule

// FIRST expands two threshold flags to four directional flags. A later pass
// extends each existing direction separately, as in the original 49 RTL.
module edge_balance_geometry #(parameter W=1920,H=1080,HT=1100,FIRST=0)(
 input wire clk,rst_n,input wire [(FIRST?4:8)-1:0] din,input wire de,hs,vs,
 output reg [7:0] dout,output reg ode,ohs,ovs
);
 localparam B=FIRST?2:4;
 wire [9*B-1:0] a,b;wire d,v,h,s;wire [1:0] border;wire unused;
 canny_window_2ppc #(.B(B),.W(W),.H(H),.HT(HT),.C(1)) window(
  clk,rst_n,din,de,de,hs,vs,1'b0,a,b,d,v,h,s,border,unused);
 function [1:0] propagate(input [9*B-1:0] q,input integer bit_number);
  integer j;reg [8:0] horizontal,vertical;
  begin
   for(j=0;j<9;j=j+1)begin
    horizontal[j]=q[j*B+bit_number];
    vertical[j]=q[j*B+bit_number+(FIRST?0:1)];
   end
   propagate[0]=horizontal[4]&&(horizontal[0]||horizontal[3]||horizontal[6])&&
                                             (horizontal[2]||horizontal[5]||horizontal[8]);
   propagate[1]=vertical[4]&&(vertical[0]||vertical[1]||vertical[2])&&
                                         (vertical[6]||vertical[7]||vertical[8]);
  end
 endfunction
 always @(posedge clk)begin
  if(!rst_n)begin dout<=0;ode<=0;ohs<=0;ovs<=0;end
  else begin
   dout<={border[1]?4'd0:{propagate(b,FIRST?1:2),propagate(b,0)},
          border[0]?4'd0:{propagate(a,FIRST?1:2),propagate(a,0)}};
   {ode,ohs,ovs}<={d,h,s};
  end
 end
endmodule

module edge_balance_axis #(parameter W=1920,H=1080,HT=1100)(
 input wire clk,rst_n,input wire [3:0] din,input wire de,hs,vs,
 output reg [3:0] dout,output reg ode,ohs,ovs
);
 wire [17:0] a,b;wire d,v,h,s;wire [1:0] border;wire unused;
 canny_window_2ppc #(.B(2),.W(W),.H(H),.HT(HT),.C(1)) window(
  clk,rst_n,din,de,de,hs,vs,1'b0,a,b,d,v,h,s,border,unused);
 function [1:0] propagate(input [17:0] q);
 begin
  propagate[0]=q[8]&&(q[0]||q[6]||q[12])&&(q[4]||q[10]||q[16]);
  propagate[1]=q[9]&&(q[1]||q[3]||q[5])&&(q[13]||q[15]||q[17]);
 end endfunction
 always @(posedge clk)begin
  if(!rst_n)begin dout<=0;ode<=0;ohs<=0;ovs<=0;end
  else begin
   dout<={border[1]?2'd0:propagate(b),border[0]?2'd0:propagate(a)};
   {ode,ohs,ovs}<={d,h,s};
  end
 end
endmodule
