// Continuous 2 pixels/clock only. L = H_TOTAL_BEATS + 5.
// L counts rising-edge intervals from input sampling to output registration.
module edge_detect_2ppc #(
    parameter integer IMG_W=1920, IMG_H=1080, H_TOTAL_BEATS=1066,
    parameter [7:0] STRONG_THRESHOLD_MIN=8'd6
)(
    input wire clk, rst_n,
    input wire [47:0] rgb_x2_in,
    input wire de_in, valid_in, hsync_in, vsync_in,
    input wire [7:0] threshold_in,
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
    reg [7:0] threshold_frame;
    wire sample=armed && !vsync_in && de_in && valid_in;
    wire [XW-1:0] xin=de_d ? x : {XW{1'b0}};
    // Two synchronous read-before-write line memories, 16 bits per pair.
    reg [15:0] line1 [0:PAIRS-1], line2 [0:PAIRS-1];
    reg [15:0] gray;
    reg gs, flush;
    reg [XW-1:0] gx;
    reg [YW-1:0] gy;
    reg [7:0] gt;
    reg [15:0] topq, midq, botq;
    reg qs;
    reg [XW:0] qx;
    reg [YW-1:0] qy;
    reg [7:0] qt;
    reg [15:0] tp, mp, bp;
    reg [7:0] tl, ml, bl;
    reg signed [10:0] dx0, dy0, dx1, dy1;
    reg [10:0] magnitude0, magnitude1;
    reg [7:0] th1, th2;
    reg [15:0] binary,strong_binary;
    // Detection threshold can never be weaker than the displayed edge threshold.
    wire [7:0] strong_threshold=th2>STRONG_THRESHOLD_MIN?th2:STRONG_THRESHOLD_MIN;
    function [7:0] luminance;
        input [23:0] rgb;
        reg [15:0] sum;
        begin
            sum=16'd77*rgb[23:16]+16'd150*rgb[15:8]+16'd29*rgb[7:0];
            luminance=sum[15:8];
        end
    endfunction
    function signed [10:0] grad;
        input [7:0] a,b,c,d,e,f;
        begin grad=$signed({3'b0,a})+($signed({3'b0,b})<<<1)+$signed({3'b0,c})
                   -$signed({3'b0,d})-($signed({3'b0,e})<<<1)-$signed({3'b0,f}); end
    endfunction
    function [10:0] absolute;
        input signed [10:0] v;
        begin absolute=v[10] ? -v : v; end
    endfunction
    // Circular delay RAM includes border flags, data and ALL control signals.
    // It is never reset; fill gates stale entries following reset.
    reg [53:0] delay_ram [0:L-1];
    reg [PW-1:0] ptr;
    reg [PW:0] fill;
    reg [53:0] delayed;
    wire row_border=(y==0 || y==IMG_H-1);
    assign {rgb_x2_orig_out,de_out,valid_out,hsync_out,vsync_out}=delayed[51:0];
    assign edge_x2_out={delayed[53] ? 8'd0 : binary[15:8],
                        delayed[52] ? 8'd0 : binary[7:0]};
    assign strong_edge_x2_out={delayed[53] ? 8'd0 : strong_binary[15:8],
                               delayed[52] ? 8'd0 : strong_binary[7:0]};
    // synthesis translate_off
    initial begin
        if(IMG_W<4 || IMG_W%2 || IMG_H<3 || H_TOTAL_BEATS<PAIRS+1)
            $fatal(1,"Unsupported image dimensions/blanking");
    end
    always @(posedge clk) if(rst_n && armed && !vsync_in) begin
        if(valid_in!==de_in) $fatal(1,"Continuous video requires valid == DE");
    end
    // synthesis translate_on
    always @(posedge clk) begin
        if (!rst_n) begin
            vs_d<=0; de_d<=0; saw_vs<=0; armed<=0; vs_low_seen<=0; x<=0; y<=0; threshold_frame<=32;
            gs<=0; flush<=0; gx<=0; gy<=0; gt<=0;
            topq<=0; midq<=0; botq<=0; qs<=0; qx<=0; qy<=0; qt<=0;
            tp<=0; mp<=0; bp<=0; tl<=0; ml<=0; bl<=0; gray<=0;
            dx0<=0; dy0<=0; dx1<=0; dy1<=0; magnitude0<=0; magnitude1<=0;
            th1<=0; th2<=0; binary<=0; strong_binary<=0; ptr<=0; fill<=0; delayed<=0;
        end else begin
            vs_d<=vsync_in; de_d<=de_in;
            if(!vsync_in) vs_low_seen<=1;
            if(vsync_in && !vs_d && vs_low_seen) saw_vs<=1;
            if(vsync_in) begin armed<=0; x<=0; y<=0; end
            if(vs_d && !vsync_in && saw_vs) begin
                armed<=1; x<=0; y<=0; threshold_frame<=threshold_in;
            end else if(!vsync_in && armed) begin
                if(sample) x<=(xin==PAIRS-1) ? 0 : xin+1'b1;
                if(de_d && !de_in) begin x<=0; y<=y+1'b1; end
            end
            gray<={luminance(rgb_x2_in[47:24]),luminance(rgb_x2_in[23:0])};
            gs<=sample; flush<=armed && de_d && !de_in && !vsync_in;
            gx<=xin; gy<=y; gt<=threshold_frame;
            qs<=gs || flush; qx<=gs ? gx : PAIRS; qy<=gy; qt<=gt;
            if(gs) begin
                topq <= gy>=2 ? line2[gx] : 16'd0;
                midq <= gy>=1 ? line1[gx] : 16'd0;
                botq <= gray;
                line1[gx]<=gray;
                line2[gx]<=line1[gx];
            end else begin topq<=0; midq<=0; botq<=0; end
            // At pair k, produce both pixels of pair k-1. tl/ml/bl are
            // the high pixel of pair k-2; q low pixel supplies right neighbor.
            if(qs) begin
                if(qx==0) begin tl<=0; ml<=0; bl<=0; end
                else begin tl<=tp[15:8]; ml<=mp[15:8]; bl<=bp[15:8]; end
                tp<=topq; mp<=midq; bp<=botq;
            end
            dx0<=grad(tp[15:8],mp[15:8],bp[15:8],tl,ml,bl);
            dy0<=grad(bl,bp[7:0],bp[15:8],tl,tp[7:0],tp[15:8]);
            dx1<=grad(topq[7:0],midq[7:0],botq[7:0],tp[7:0],mp[7:0],bp[7:0]);
            dy1<=grad(bp[7:0],bp[15:8],botq[7:0],tp[7:0],tp[15:8],topq[7:0]);
            th1<=qt;
            magnitude0<=absolute(dx0)+absolute(dy0);
            magnitude1<=absolute(dx1)+absolute(dy1); th2<=th1;
            binary<={(magnitude1[10:3]>th2)?8'hff:8'h00,
                     (magnitude0[10:3]>th2)?8'hff:8'h00};
            strong_binary<={(magnitude1[10:3]>strong_threshold)?8'hff:8'h00,
                            (magnitude0[10:3]>strong_threshold)?8'hff:8'h00};
            delay_ram[ptr]<={(!sample || row_border || xin==PAIRS-1),
                             (!sample || row_border || xin==0),
                             sample ? rgb_x2_in : 48'd0,sample,sample,hsync_in,vsync_in};
            delayed<=fill>=L ? delay_ram[ptr] : 54'd0;
            ptr<=ptr==L-1 ? 0 : ptr+1'b1;
            if(fill<L) fill<=fill+1'b1;
        end
    end
endmodule
