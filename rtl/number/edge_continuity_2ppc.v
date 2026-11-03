// Continuous 2 pixels/clock only. L = H_TOTAL_BEATS + 5.
// L counts rising-edge intervals from input sampling to output registration.
module edge_continuity_2ppc #(
    parameter integer IMG_W=1920, IMG_H=1080, H_TOTAL_BEATS=1066
)(
    input wire clk, rst_n,
    input wire [47:0] rgb_x2_in,
    input wire de_in, valid_in, hsync_in, vsync_in,
    input wire [15:0] display_in,strong_in,
    output wire [15:0] edge_x2_out,
    output wire [15:0] strong_edge_x2_out,
    output wire [47:0] rgb_x2_orig_out,
    output wire de_out, valid_out, hsync_out, vsync_out
);
    localparam integer PAIRS=IMG_W/2, L=H_TOTAL_BEATS+5;
    localparam integer XW=$clog2(PAIRS), YW=$clog2(IMG_H+1), PW=$clog2(L);
    reg vs_d, de_d, saw_vs, armed, vs_low_seen;
    reg [XW-1:0] x;
    reg [YW-1:0] y;
    wire sample=armed && !vsync_in && de_in && valid_in;
    wire [XW-1:0] xin=de_d ? x : {XW{1'b0}};
    reg [3:0] line1[0:PAIRS-1],line2[0:PAIRS-1];
    reg [3:0] gray,topq,midq,botq,tp,mp,bp;
    reg [1:0] tl,ml,bl;
    reg gs,flush,qs;reg [XW-1:0] gx;reg [YW-1:0] gy;reg [XW:0] qx;
    reg [3:0] cleaned,pipe4,binary;
    function clean;
     input a,b,c,d,e,f,g,h,i;integer n;
     begin n={3'd0,a}+{3'd0,b}+{3'd0,c}+{3'd0,d}+{3'd0,f}+{3'd0,g}+{3'd0,h}+{3'd0,i};clean=e&&(n>=2);end
    endfunction
    // Circular delay RAM includes border flags, data and ALL control signals.
    // It is never reset; fill gates stale entries following reset.
    reg [53:0] delay_ram [0:L-1];
    reg [PW-1:0] ptr;
    reg [PW:0] fill;
    reg [53:0] delayed;
    wire row_border=(y==0 || y==IMG_H-1);
    assign {rgb_x2_orig_out,de_out,valid_out,hsync_out,vsync_out}=delayed[51:0];
    assign edge_x2_out={delayed[53]?8'd0:{8{binary[1]}},delayed[52]?8'd0:{8{binary[0]}}};
    assign strong_edge_x2_out={delayed[53]?8'd0:{8{binary[3]}},delayed[52]?8'd0:{8{binary[2]}}};
    // synthesis translate_off
    initial begin
        if(IMG_W<4 || IMG_W%2 || IMG_H<3 || H_TOTAL_BEATS<PAIRS+1)
            $fatal(1,"Unsupported image dimensions/blanking");
    end
    always @(posedge clk) if(rst_n && armed && !vsync_in) begin
        if(valid_in!==de_in) $fatal(1,"Continuous video requires valid == DE");
    end
    // synthesis translate_on
    always @(posedge clk)begin
     if(!rst_n)begin
      vs_d<=0;de_d<=0;saw_vs<=0;armed<=0;vs_low_seen<=0;x<=0;y<=0;
      gs<=0;flush<=0;gx<=0;gy<=0;qx<=0;qs<=0;gray<=0;
      topq<=0;midq<=0;botq<=0;tp<=0;mp<=0;bp<=0;tl<=0;ml<=0;bl<=0;
      cleaned<=0;pipe4<=0;binary<=0;ptr<=0;fill<=0;delayed<=0;
     end else begin
      vs_d<=vsync_in;de_d<=de_in;
      if(!vsync_in)vs_low_seen<=1;
      if(vsync_in&&!vs_d&&vs_low_seen)saw_vs<=1;
      if(vsync_in)begin armed<=0;x<=0;y<=0;end
      if(vs_d&&!vsync_in&&saw_vs)begin armed<=1;x<=0;y<=0;end
      else if(!vsync_in&&armed)begin
       if(sample)x<=xin==PAIRS-1?0:xin+1'b1;
       if(de_d&&!de_in)begin x<=0;y<=y+1'b1;end
      end
      gray<={strong_in[15],strong_in[7],display_in[15],display_in[7]};
      gs<=sample;flush<=armed&&de_d&&!de_in&&!vsync_in;gx<=xin;gy<=y;
      qs<=gs||flush;qx<=gs?gx:PAIRS;
      if(gs)begin topq<=gy>=2?line2[gx]:4'd0;midq<=gy>=1?line1[gx]:4'd0;botq<=gray;line1[gx]<=gray;line2[gx]<=line1[gx];end
      else begin topq<=0;midq<=0;botq<=0;end
      if(qs)begin
       if(qx==0)begin tl<=0;ml<=0;bl<=0;end else begin tl<={tp[3],tp[1]};ml<={mp[3],mp[1]};bl<={bp[3],bp[1]};end
       tp<=topq;mp<=midq;bp<=botq;
      end
      cleaned[0]<=clean(tl[0],tp[0],tp[1],ml[0],mp[0],mp[1],bl[0],bp[0],bp[1]);
      cleaned[1]<=clean(tp[0],tp[1],topq[0],mp[0],mp[1],midq[0],bp[0],bp[1],botq[0]);
      cleaned[2]<=clean(tl[1],tp[2],tp[3],ml[1],mp[2],mp[3],bl[1],bp[2],bp[3]);
      cleaned[3]<=clean(tp[2],tp[3],topq[2],mp[2],mp[3],midq[2],bp[2],bp[3],botq[2]);
      pipe4<=cleaned;binary<=pipe4;
      delay_ram[ptr]<={(!sample||row_border||xin==PAIRS-1),(!sample||row_border||xin==0),sample?rgb_x2_in:48'd0,sample,sample,hsync_in,vsync_in};
      delayed<=fill>=L?delay_ram[ptr]:54'd0;ptr<=ptr==L-1?0:ptr+1'b1;if(fill<L)fill<=fill+1'b1;
     end
    end
endmodule
