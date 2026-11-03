`timescale 1ns/1ps
// Streaming Canny approximation. Exact full-frame hysteresis is NOT implemented.
// Two pixels/clock; no backpressure; fixed complete rows and frame timing.
module canny_delay #(parameter WIDTH=1, DEPTH=1)(
 input wire clk,rst_n,input wire [WIDTH-1:0] din,output wire [WIDTH-1:0] dout
);
 localparam AW=DEPTH>1?$clog2(DEPTH):1;
 localparam BANK_DEPTH=WIDTH<=5?2048:WIDTH<=10?1024:512;
 localparam LANE_WIDTH=WIDTH<=5?5:WIDTH<=10?10:18;
 localparam LB=$clog2(BANK_DEPTH),BANKS=(DEPTH+BANK_DEPTH-1)/BANK_DEPTH;
 localparam BW=BANKS>1?$clog2(BANKS):1;
 reg [AW-1:0] ptr;reg [AW:0] fill;reg [BW-1:0] read_bank;reg read_valid;
 wire [31:0] address=ptr;wire [WIDTH-1:0] bank_data[0:BANKS-1];
 genvar k,j;
 generate if(DEPTH<=4)begin:short_storage
  (* syn_ramstyle="registers" *) reg [WIDTH-1:0] mem[0:DEPTH-1];
  reg [WIDTH-1:0] q;
  always @(posedge clk)begin if(rst_n)begin mem[ptr]<=din;q<=mem[ptr];end end
  assign bank_data[0]=q;
 end else begin:banked_storage
 for(k=0;k<BANKS;k=k+1)begin:bank
  for(j=0;j<(WIDTH+LANE_WIDTH-1)/LANE_WIDTH;j=j+1)begin:lane
   localparam B=(WIDTH-j*LANE_WIDTH)>LANE_WIDTH?LANE_WIDTH:(WIDTH-j*LANE_WIDTH);
   (* syn_ramstyle="block_ram",syn_ramdecomp="area" *) reg [B-1:0] mem[0:BANK_DEPTH-1];
   reg [B-1:0] q;
   always @(posedge clk)begin
    if(rst_n&&address[31:LB]==k)begin
     mem[address[LB-1:0]]<=din[j*LANE_WIDTH+:B];q<=mem[address[LB-1:0]];
    end
   end
   assign bank_data[k][j*LANE_WIDTH+:B]=q;
  end
 end end endgenerate
 assign dout=read_valid?bank_data[read_bank]:{WIDTH{1'b0}};
 always @(posedge clk)begin
 if(!rst_n)begin ptr<=0;fill<=0;read_bank<=0;read_valid<=0;end
 else begin
  read_bank<=address[31:LB];read_valid<=fill>=DEPTH;
  ptr<=ptr==DEPTH-1?0:ptr+1'b1;if(fill<DEPTH)fill<=fill+1'b1;
 end end
endmodule

// Centered 3x3 windows for adjacent pixels. L = HT + 3 edge intervals.
// Window fields [i*B+:B]: 0..8 = TL,TC,TR,ML,MC,MR,BL,BC,BR.
// Line memories intentionally not reset. Row masks prevent stale frame data.
module canny_window_2ppc #(
 parameter B=8, W=1920,H=1080,HT=1066,C=8
)(
 input wire clk,rst_n,input wire [2*B-1:0] data_in,
 input wire de_in,valid_in,hs_in,vs_in,input wire [C-1:0] cfg_in,
 output reg [9*B-1:0] win0,win1,
 output wire de_out,valid_out,hs_out,vs_out,
 output wire [1:0] border_out,output wire [C-1:0] cfg_out
);
 localparam P=W/2, XW=$clog2(P),YW=$clog2(H+1);
 reg [2*B-1:0] line1[0:P-1],line2[0:P-1];
 reg [2*B-1:0] data_q,topq,midq,botq,tp,mp,bp;
 reg [B-1:0] tl,ml,bl;
 reg [XW-1:0] x,gx; reg [YW-1:0] y,gy;
 reg de_d,gs,flush,qs; reg [XW:0] qx;
 wire sample=de_in&&valid_in&&!vs_in;
 wire [XW-1:0] xin=de_d?x:{XW{1'b0}};
 wire rb=(y==0 || y==H-1);
 wire [4:0] control;
 canny_delay #(.WIDTH(5),.DEPTH(HT+3)) control_delay(
  .clk(clk),.rst_n(rst_n),
  .din({(!sample||rb||xin==P-1),(!sample||rb||xin==0),
         sample,hs_in,vs_in}),.dout(control));
 assign {border_out,de_out,hs_out,vs_out}=control;assign valid_out=de_out;
 assign cfg_out=cfg_in; // Frame-stable configuration, blanking contract above.
 always @(posedge clk) begin
  if(!rst_n) begin
   x<=0;y<=0;gx<=0;gy<=0;de_d<=0;gs<=0;flush<=0;qs<=0;qx<=0;
   data_q<=0;topq<=0;midq<=0;botq<=0;tp<=0;mp<=0;bp<=0;
   tl<=0;ml<=0;bl<=0;win0<=0;win1<=0;
  end else begin
   de_d<=de_in;
   if(vs_in) begin x<=0;y<=0;end
   else begin
    if(sample) x<=(xin==P-1)?0:xin+1'b1;
    if(de_d&&!de_in) begin x<=0;y<=y+1'b1;end
   end
   data_q<=data_in;gs<=sample;gx<=xin;gy<=y;
   flush<=de_d&&!de_in&&!vs_in;
   qs<=gs||flush;qx<=gs?{1'b0,gx}:P;
   if(gs) begin
    topq<=gy>=2?line2[gx]:{2*B{1'b0}};
    midq<=gy>=1?line1[gx]:{2*B{1'b0}};
    botq<=data_q;line1[gx]<=data_q;line2[gx]<=line1[gx];
   end else begin topq<=0;midq<=0;botq<=0;end
   if(qs) begin
    if(qx==0) begin tl<=0;ml<=0;bl<=0;end
    else begin tl<=tp[2*B-1:B];ml<=mp[2*B-1:B];bl<=bp[2*B-1:B];end
    tp<=topq;mp<=midq;bp<=botq;
   end
   win0<={bp[2*B-1:B],bp[B-1:0],bl,mp[2*B-1:B],mp[B-1:0],ml,
          tp[2*B-1:B],tp[B-1:0],tl};
   win1<={botq[B-1:0],bp[2*B-1:B],bp[B-1:0],midq[B-1:0],mp[2*B-1:B],mp[B-1:0],
          topq[B-1:0],tp[2*B-1:B],tp[B-1:0]};
  end
 end
endmodule

module canny_impulse_2ppc #(parameter W=1920,H=1080,HT=1066)(
 input wire clk,rst_n,input wire [15:0] din,
 input wire de,valid,hs,vs,input wire [21:0] cfg,
 output reg [15:0] dout,output reg ode,ovalid,ohs,ovs,output reg [21:0] ocfg
);
 wire [71:0] a,b;wire d,v,h,s;wire [1:0] border;wire [21:0] c;
 canny_window_2ppc #(.B(8),.C(22),.W(W),.H(H),.HT(HT)) window(
 clk,rst_n,din,de,valid,hs,vs,cfg,a,b,d,v,h,s,border,c);
 wire [15:0] centered_gray;
 canny_delay #(.WIDTH(16),.DEPTH(HT+3)) original(clk,rst_n,din,centered_gray);
 function [7:0] clean;
  input [71:0] q;
  reg [7:0] lo[0:6],hi[0:6];reg [7:0] n[0:7];integer i;
  begin
   n[0]=q[0+:8];n[1]=q[8+:8];n[2]=q[16+:8];n[3]=q[24+:8];
   n[4]=q[40+:8];n[5]=q[48+:8];n[6]=q[56+:8];n[7]=q[64+:8];
   for(i=0;i<4;i=i+1)begin
    lo[i]=n[2*i]<n[2*i+1]?n[2*i]:n[2*i+1];
    hi[i]=n[2*i]>n[2*i+1]?n[2*i]:n[2*i+1];
   end
   lo[4]=lo[0]<lo[1]?lo[0]:lo[1];lo[5]=lo[2]<lo[3]?lo[2]:lo[3];
   hi[4]=hi[0]>hi[1]?hi[0]:hi[1];hi[5]=hi[2]>hi[3]?hi[2]:hi[3];
   lo[6]=lo[4]<lo[5]?lo[4]:lo[5];hi[6]=hi[4]>hi[5]?hi[4]:hi[5];
   clean=q[32+:8];
   if({1'b0,q[32+:8]}>{1'b0,hi[6]}+9'd12)clean=hi[6];
   else if({1'b0,q[32+:8]}+9'd12<{1'b0,lo[6]})clean=lo[6];
  end
 endfunction
 always @(posedge clk)begin
  if(!rst_n)begin dout<=0;ode<=0;ovalid<=0;ohs<=0;ovs<=0;ocfg<=0;end
  else begin
   dout<={(border[1]||!c[21])?centered_gray[15:8]:clean(b),(border[0]||!c[21])?centered_gray[7:0]:clean(a)};
   {ode,ovalid,ohs,ovs,ocfg}<={d,v,h,s,c};
  end
 end
endmodule

module canny_gaussian_2ppc #(parameter W=1920,H=1080,HT=1066)(
 input wire clk,rst_n,input wire [15:0] din,
 input wire de,valid,hs,vs,input wire [21:0] cfg,
 output reg [15:0] dout,output reg ode,ovalid,ohs,ovs,output reg [21:0] ocfg
);
 wire [71:0] a,b;wire d,v,h,s;wire [1:0] border;wire [21:0] c;
 canny_window_2ppc #(.B(8),.C(22),.W(W),.H(H),.HT(HT)) window(
 clk,rst_n,din,de,valid,hs,vs,cfg,a,b,d,v,h,s,border,c);
 // Preserve the input gray at the outer border. Zero padding here would
 // create a false frame-shaped edge on an otherwise uniform image.
 wire [15:0] centered_gray;
 canny_delay #(.WIDTH(16),.DEPTH(HT+3)) gray_border_delay(
  clk,rst_n,din,centered_gray);
 function [7:0] gaussian;
  input [71:0] q;integer sum;
  begin
   sum=q[0+:8]+2*q[8+:8]+q[16+:8]+2*q[24+:8]+4*q[32+:8]+2*q[40+:8]
       +q[48+:8]+2*q[56+:8]+q[64+:8];
   gaussian=(sum+8)>>4; // one final rounding preserves weak contrasts
  end
 endfunction
 always @(posedge clk) begin
  if(!rst_n) begin dout<=0;ode<=0;ovalid<=0;ohs<=0;ovs<=0;ocfg<=0;end
  else begin
   dout<={border[1]?centered_gray[15:8]:gaussian(b),border[0]?centered_gray[7:0]:gaussian(a)};
   {ode,ovalid,ohs,ovs,ocfg}<={d,v,h,s,c};
  end
 end
endmodule

module canny_gradient_2ppc #(parameter W=1920,H=1080,HT=1066)(
 input wire clk,rst_n,input wire [15:0] din,
 input wire de,valid,hs,vs,input wire [21:0] cfg,
 output reg [19:0] dout,output reg ode,ovalid,ohs,ovs,output reg [21:0] ocfg
);
 wire [71:0] a,b;wire d,v,h,s;wire [1:0] border;wire [21:0] c;
 canny_window_2ppc #(.B(8),.C(22),.W(W),.H(H),.HT(HT)) window(
 clk,rst_n,din,de,valid,hs,vs,cfg,a,b,d,v,h,s,border,c);
 function signed [10:0] gx;
  input [71:0] q;
  begin gx=$signed({3'b0,q[16+:8]})+2*$signed({3'b0,q[40+:8]})+$signed({3'b0,q[64+:8]})
          -$signed({3'b0,q[0+:8]})-2*$signed({3'b0,q[24+:8]})-$signed({3'b0,q[48+:8]});end
 endfunction
 function signed [10:0] gy;
  input [71:0] q;
  begin gy=$signed({3'b0,q[48+:8]})+2*$signed({3'b0,q[56+:8]})+$signed({3'b0,q[64+:8]})
          -$signed({3'b0,q[0+:8]})-2*$signed({3'b0,q[8+:8]})-$signed({3'b0,q[16+:8]});end
 endfunction
 reg signed [10:0] dx0,dy0,dx1,dy1;
 reg [1:0] mask,boost_q;reg [25:0] meta;reg [3:0] noise_q;
 function [9:0] magnitude_direction;
  input signed [10:0] x,y;input [1:0] boost;input [3:0] noise;integer ax,ay,m,floor_;reg [1:0] dir;
  begin
   ax=x<0?-x:x;ay=y<0?-y:y;floor_=boost==0?0:(boost==2?2*noise:noise);
   m=ax+ay-floor_;if(m<0)m=0;m=(m<<boost)>>1; // quarter of v25 gradient unit; retain weaker edges
   if(ay*256<=ax*106) dir=0; // ~22.5 deg, no division/atan
   else if(ax*256<=ay*106) dir=2;
   else if(x[10]==y[10]) dir=1;else dir=3;
   magnitude_direction={dir,(m>255?8'd255:m[7:0])};
  end
 endfunction
 always @(posedge clk) begin
  if(!rst_n) begin
   dx0<=0;dy0<=0;dx1<=0;dy1<=0;mask<=3;boost_q<=0;noise_q<=0;meta<=0;
   dout<=0;ode<=0;ovalid<=0;ohs<=0;ovs<=0;ocfg<=0;
  end else begin
   dx0<=gx(a);dy0<=gy(a);dx1<=gx(b);dy1<=gy(b);mask<=border;boost_q<=c[17:16];noise_q<=c[21:18];
   meta<={d,v,h,s,c};
   dout<={mask[1]?10'd0:magnitude_direction(dx1,dy1,boost_q,noise_q),mask[0]?10'd0:magnitude_direction(dx0,dy0,boost_q,noise_q)};
   {ode,ovalid,ohs,ovs,ocfg}<=meta;
  end
 end
endmodule

module canny_nms_classify_2ppc #(parameter W=1920,H=1080,HT=1066)(
 input wire clk,rst_n,input wire [19:0] din,
 input wire de,valid,hs,vs,input wire [21:0] cfg,
 output reg [3:0] dout,output reg ode,ovalid,ohs,ovs,output reg [15:0] nms_strength
);
 wire [89:0] a,b;wire d,v,h,s;wire [1:0] border;wire [21:0] levels;
 canny_window_2ppc #(.B(10),.C(22),.W(W),.H(H),.HT(HT)) window(
 clk,rst_n,din,de,valid,hs,vs,cfg,a,b,d,v,h,s,border,levels);
 // Class [1]=accepted linked_any, [0]=candidate; 00 off,01 weak,11 linked_any.
 function [1:0] classify;
  input [89:0] q;input [7:0] hi,low;
  reg [7:0] m,neg,pos,lo,hh;reg [1:0] dir;
  begin
   m=q[40+:8];dir=q[48+:2];hh=hi==0?8'd1:hi;
   lo=low==0?8'd1:low;if(lo>hh)lo=hh;
   case(dir)
    0:begin neg=q[30+:8];pos=q[50+:8];end
    1:begin neg=q[0+:8];pos=q[80+:8];end
    2:begin neg=q[10+:8];pos=q[70+:8];end
    default:begin neg=q[20+:8];pos=q[60+:8];end
   endcase
   // Asymmetric tie break keeps one side of a flat two-pixel ridge.
   if(m!=0 && m>neg && m>=pos)
    classify=(m>=hh)?2'b11:((m>=lo)?2'b01:2'b00);
   else classify=0;
  end
 endfunction
 function [7:0] strength(input [89:0] q);
  reg [7:0] m,neg,pos;reg [1:0] dir;
  begin m=q[40+:8];dir=q[48+:2];
   case(dir)
    0:begin neg=q[30+:8];pos=q[50+:8];end
    1:begin neg=q[0+:8];pos=q[80+:8];end
    2:begin neg=q[10+:8];pos=q[70+:8];end
    default:begin neg=q[20+:8];pos=q[60+:8];end
   endcase
   strength=(m!=0&&m>neg&&m>=pos)?m:8'd0;
  end
 endfunction
 always @(posedge clk) begin
  if(!rst_n) begin dout<=0;ode<=0;ovalid<=0;ohs<=0;ovs<=0;nms_strength<=0;end
  else begin
   nms_strength<={border[1]?8'd0:strength(b),border[0]?8'd0:strength(a)};
   dout<={border[1]?2'd0:classify(b,levels[7:0],levels[15:8]),border[0]?2'd0:classify(a,levels[7:0],levels[15:8])};
   {ode,ovalid,ohs,ovs}<={d,v,h,s};
  end
 end
endmodule

// One simultaneous 8-neighbor propagation pass, NOT scan-order recursion.
module canny_link_2ppc #(parameter W=1920,H=1080,HT=1066)(
 input wire clk,rst_n,input wire [3:0] din,input wire de,valid,hs,vs,
 output reg [3:0] dout,output reg ode,ovalid,ohs,ovs
);
 wire [17:0] a,b;wire d,v,h,s;wire [1:0] border;wire [7:0] unused_cfg;
 canny_window_2ppc #(.B(2),.W(W),.H(H),.HT(HT)) window(
 clk,rst_n,din,de,valid,hs,vs,8'd0,a,b,d,v,h,s,border,unused_cfg);
 function [1:0] connect;
  input [17:0] q;integer i;reg linked_any;
  begin
   linked_any=0;for(i=0;i<9;i=i+1) linked_any=linked_any|q[i*2+1];
   connect={q[8]&&linked_any,q[8]};
  end
 endfunction
 always @(posedge clk) begin
  if(!rst_n) begin dout<=0;ode<=0;ovalid<=0;ohs<=0;ovs<=0;end
  else begin
   dout<={border[1]?2'd0:connect(b),border[0]?2'd0:connect(a)};
   {ode,ovalid,ohs,ovs}<={d,v,h,s};
  end
 end
endmodule

module canny_stream_2ppc #(
 parameter integer IMG_W=1920,IMG_H=1080,H_TOTAL_BEATS=1066,HYSTERESIS_PASSES=2,ORIGINAL_ENABLE=1
)(
 input wire clk,rst_n,input wire [47:0] rgb_x2_in,
 input wire de_in,valid_in,hsync_in,vsync_in,input wire [7:0] threshold_in,
 input wire [7:0] threshold_low_in,input wire [1:0] exposure_level_in,input wire [3:0] noise_in,
 output wire [7:0] active_high,active_low,output wire [1:0] active_exposure,output wire [3:0] active_noise,
 output wire [15:0] edge_x2_out,output wire [47:0] rgb_x2_orig_out,
 output wire de_out,valid_out,hsync_out,vsync_out,output wire [15:0] nms_x2_out,output wire [15:0] gray_x2_out
);
 // Rising-edge intervals include the next-stage input sampling edge.
 // Gray->Gaussian 1 + HT+4; each later stage contributes 1 + its latency.
 localparam TOTAL_L=1+(H_TOTAL_BEATS+4)+1+(H_TOTAL_BEATS+5)+1+(H_TOTAL_BEATS+4)
                       +HYSTERESIS_PASSES*(H_TOTAL_BEATS+5)+(H_TOTAL_BEATS+5);
 reg vs_d,saw_vs,vs_low_seen,armed;reg [21:0] threshold_frame;
 assign active_noise=threshold_frame[21:18];
 assign active_high=threshold_frame[7:0];assign active_low=threshold_frame[15:8];assign active_exposure=threshold_frame[17:16];
 wire sample=armed&&!vsync_in&&de_in&&valid_in;
 reg [15:0] gray;reg gd,gv,gh,gs;reg [21:0] gc;
 function [7:0] luminance;
  input [23:0] rgb;reg [15:0] sum;
  begin sum=16'd77*rgb[23:16]+16'd150*rgb[15:8]+16'd29*rgb[7:0];luminance=sum[15:8];end
 endfunction
 always @(posedge clk) begin
  if(!rst_n) begin
   vs_d<=0;saw_vs<=0;vs_low_seen<=0;armed<=0;threshold_frame<={4'd0,2'd0,8'd3,8'd6};
   gray<=0;gd<=0;gv<=0;gh<=0;gs<=0;gc<=0;
  end else begin
   vs_d<=vsync_in;
   if(!vsync_in)vs_low_seen<=1;
   if(vsync_in&&!vs_d&&vs_low_seen)saw_vs<=1;
   if(vsync_in)armed<=0;
   if(vs_d&&!vsync_in&&saw_vs)begin armed<=1;threshold_frame<={noise_in,exposure_level_in,threshold_low_in,threshold_in};end
   gray<={luminance(rgb_x2_in[47:24]),luminance(rgb_x2_in[23:0])};
   {gd,gv,gh,gs,gc}<={sample,sample,hsync_in,vsync_in,threshold_frame};
  end
 end
 wire [15:0] clean;wire nd,nv,nh,ns;wire [21:0] nc;
 canny_impulse_2ppc #(.W(IMG_W),.H(IMG_H),.HT(H_TOTAL_BEATS)) impulse(
 clk,rst_n,gray,gd,gv,gh,gs,gc,clean,nd,nv,nh,ns,nc);
 wire [15:0] smooth;wire ad,av,ah,as_;wire [21:0] ac;
 canny_gaussian_2ppc #(.W(IMG_W),.H(IMG_H),.HT(H_TOTAL_BEATS)) gaussian(
 clk,rst_n,clean,nd,nv,nh,ns,nc,smooth,ad,av,ah,as_,ac);
 wire [19:0] gradient;wire bd,bv,bh,bs;wire [21:0] bc;
 canny_gradient_2ppc #(.W(IMG_W),.H(IMG_H),.HT(H_TOTAL_BEATS)) sobel(
 clk,rst_n,smooth,ad,av,ah,as_,ac,gradient,bd,bv,bh,bs,bc);
 wire [3:0] cls[0:HYSTERESIS_PASSES];
 wire [HYSTERESIS_PASSES:0] ld,lv,lh,ls;
 wire [15:0] nms_gray,linked_gray;
 canny_nms_classify_2ppc #(.W(IMG_W),.H(IMG_H),.HT(H_TOTAL_BEATS)) nms(
 clk,rst_n,gradient,bd,bv,bh,bs,bc,cls[0],ld[0],lv[0],lh[0],ls[0],nms_gray);
 genvar k;
 generate for(k=0;k<HYSTERESIS_PASSES;k=k+1) begin:link_pass
  canny_link_2ppc #(.W(IMG_W),.H(IMG_H),.HT(H_TOTAL_BEATS)) link(
   clk,rst_n,cls[k],ld[k],lv[k],lh[k],ls[k],cls[k+1],ld[k+1],lv[k+1],lh[k+1],ls[k+1]);
 end endgenerate
 canny_delay #(.WIDTH(16),.DEPTH(HYSTERESIS_PASSES*(H_TOTAL_BEATS+5)-1)) gray_delay(
 clk,rst_n,nms_gray,linked_gray);
 assign nms_x2_out=de_out?linked_gray:16'd0;
 assign gray_x2_out=de_out?{cls[HYSTERESIS_PASSES][3]?linked_gray[15:8]:8'd0,cls[HYSTERESIS_PASSES][1]?linked_gray[7:0]:8'd0}:16'd0;
 function [15:0] pack565(input [23:0] p);
  pack565={p[23:19],p[15:10],p[7:3]};
 endfunction
 function [23:0] unpack565(input [15:0] p);
  unpack565={p[15:11],p[15:13],p[10:5],p[10:9],p[4:0],p[4:2]};
 endfunction
 generate if(ORIGINAL_ENABLE)begin:original_enabled
 wire [35:0] delayed;
 canny_delay #(.WIDTH(36),.DEPTH(TOTAL_L)) original_delay(
 clk,rst_n,{sample?{pack565(rgb_x2_in[47:24]),pack565(rgb_x2_in[23:0])}:32'd0,sample,sample,hsync_in,vsync_in},delayed);
 assign rgb_x2_orig_out={unpack565(delayed[35:20]),unpack565(delayed[19:4])};
 assign {de_out,valid_out,hsync_out,vsync_out}=delayed[3:0];
 end else begin:no_original
 assign rgb_x2_orig_out=48'd0;
 assign {de_out,valid_out,hsync_out,vsync_out}={ld[HYSTERESIS_PASSES],lv[HYSTERESIS_PASSES],lh[HYSTERESIS_PASSES],ls[HYSTERESIS_PASSES]};
 end endgenerate
 assign edge_x2_out=de_out?{(cls[HYSTERESIS_PASSES][3]?8'hff:8'h00),
                           (cls[HYSTERESIS_PASSES][1]?8'hff:8'h00)}:16'd0;
 // synthesis translate_off
 initial begin
  if(IMG_W<4||IMG_W%2||IMG_H<3||H_TOTAL_BEATS<IMG_W/2+1||HYSTERESIS_PASSES<1)
   $fatal(1,"Unsupported Canny dimensions/blanking/pass count");
 end
 always @(posedge clk) if(rst_n) begin
  if(armed&&!vsync_in&&valid_in!==de_in)$fatal(1,"Canny requires continuous valid==DE");
  if({ld[HYSTERESIS_PASSES],lv[HYSTERESIS_PASSES],lh[HYSTERESIS_PASSES],ls[HYSTERESIS_PASSES]}
     !=={de_out,valid_out,hsync_out,vsync_out}) $fatal(1,"Canny control/original alignment");
 end
 // synthesis translate_on
endmodule


