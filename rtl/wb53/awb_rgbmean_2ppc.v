// Filtered gray-world estimator. Statistics are measured BEFORE gain/gamma.
// Two pixels/clock. No backpressure; division runs off the pixel data path.
// cfg gains may finish at any clock; downstream latches all gains on valid SOF.
module awb_rgbmean_2ppc #(
 parameter FALLBACK_ENABLE=0, FALLBACK_MIN_SAMPLES=1024,
 parameter MIN_SAMPLES=256, SAMPLE_LOG2=2, LINE_LOG2=2,
 parameter MIN_LEVEL=8, MAX_LEVEL=240,
 parameter GAIN_MIN=128, GAIN_MAX=640, SMOOTH_SHIFT=4, MAX_STEP=16
)(input clk,rst,enable,hold_gain,input [47:0] rgb,input de,vs,
 output reg [11:0] gain_r,gain_b,gain_g,output reg update_pulse,
 output reg [31:0] accepted_samples,output reg rejected_frame);
 reg old_vs,old_de;reg [15:0] x,y;
 reg [31:0] sum_r,sum_g,sum_b,samples;
 wire frame_edge=vs && !old_vs;
 wire sample_now=de && ((x & ((1<<SAMPLE_LOG2)-1))==0) && ((y & ((1<<LINE_LOG2)-1))==0);
 function acceptable;
  input [23:0] p;reg [7:0] hi,lo;
  begin
   hi=(p[23:16]>p[15:8])?p[23:16]:p[15:8];if(p[7:0]>hi)hi=p[7:0];
   lo=(p[23:16]<p[15:8])?p[23:16]:p[15:8];if(p[7:0]<lo)lo=p[7:0];
   acceptable=(lo>=MIN_LEVEL)&&(hi<=MAX_LEVEL)&&((hi-lo)<=(hi>>1));
  end
 endfunction
 function fallback_ok;
  input [23:0] p;reg [7:0] r,g,b,hi,lo;
  begin
   r=p[23:16];g=p[15:8];b=p[7:0];
   hi=r>g?r:g;if(b>hi)hi=b;lo=r<g?r:g;if(b<lo)lo=b;
   // Low-light neutral pixels, or green-dominant pixels whose R/B agree.
   fallback_ok=(lo>=4)&&(hi<=240)&&
    (((hi-lo)<=(hi>>1)) || ((g>=r)&&(g>=b)&&
     ({1'b0,r}<={b,1'b0})&&({1'b0,b}<={r,1'b0})&&
     ({2'b0,g}<={lo,2'b0})));
  end
 endfunction
 reg [31:0] fr,fg,fb,fn;
 wire f0=sample_now && fallback_ok(rgb[23:0]);
 wire f1=sample_now && fallback_ok(rgb[47:24]);
 wire use_fallback=FALLBACK_ENABLE && samples<MIN_SAMPLES && fn>=FALLBACK_MIN_SAMPLES;
 wire [31:0] stat_r=use_fallback?fr:sum_r,stat_g=use_fallback?fg:sum_g;
 wire [31:0] stat_b=use_fallback?fb:sum_b,stat_n=use_fallback?fn:samples;
 always @(posedge clk)begin
  if(rst || frame_edge)begin fr<=0;fg<=0;fb<=0;fn<=0;end
  else if(FALLBACK_ENABLE && sample_now)begin
   fr<=fr+(f0?{24'd0,rgb[23:16]}:32'd0)+(f1?{24'd0,rgb[47:40]}:32'd0);
   fg<=fg+(f0?{24'd0,rgb[15:8]}:32'd0)+(f1?{24'd0,rgb[39:32]}:32'd0);
   fb<=fb+(f0?{24'd0,rgb[7:0]}:32'd0)+(f1?{24'd0,rgb[31:24]}:32'd0);
   fn<=fn+{31'd0,f0}+{31'd0,f1};
  end
 end
 wire a0=sample_now && acceptable(rgb[23:0]);
 wire a1=sample_now && acceptable(rgb[47:24]);
 wire [8:0] add_r=(a0?{1'b0,rgb[23:16]}:9'd0)+(a1?{1'b0,rgb[47:40]}:9'd0);
 wire [8:0] add_g=(a0?{1'b0,rgb[15:8]}:9'd0)+(a1?{1'b0,rgb[39:32]}:9'd0);
 wire [8:0] add_b=(a0?{1'b0,rgb[7:0]}:9'd0)+(a1?{1'b0,rgb[31:24]}:9'd0);
 // RGB gray-world: target = (sumR+sumG+sumB)/3.
 // Compute round(256*total/(3*channel_sum)) directly, without rounding target.
 // 42-bit numerator and 34-bit denominator preserve all 32-bit channel sums.
 // Three 42-cycle divisions; publish all smoothed gains atomically.
 reg [31:0] saved_g,saved_b;
 wire [33:0] sum_all={2'd0,stat_r}+{2'd0,stat_g}+{2'd0,stat_b};
 wire [33:0] den_r={2'd0,stat_r}+({2'd0,stat_r}<<1);
 wire [33:0] den_g={2'd0,saved_g}+({2'd0,saved_g}<<1);
 wire [33:0] den_b={2'd0,saved_b}+({2'd0,saved_b}<<1);
 reg [33:0] saved_total;
 reg busy;reg [1:0] channel;reg [5:0] bit_count;
 reg [41:0] quotient;reg [42:0] remainder;
 reg [33:0] denominator;
 reg [11:0] target_r,target_g;
 wire [42:0] shifted={remainder[41:0],quotient[41]};
 wire subtract_ok=shifted>={9'd0,denominator};
 wire [42:0] next_rem=subtract_ok?(shifted-{9'd0,denominator}):shifted;
 wire [41:0] next_q={quotient[40:0],subtract_ok};
 function [11:0] bound;
  input [41:0] q;
  begin bound=q<GAIN_MIN?GAIN_MIN:(q>GAIN_MAX?GAIN_MAX:q[11:0]);end
 endfunction
 function [11:0] smooth;
  input [11:0] previous,target;integer distance,step;
  begin
   distance=target-previous;
   if(distance<0)begin
    step=((-distance)+(1<<SMOOTH_SHIFT)-1)>>SMOOTH_SHIFT;
    if(step>MAX_STEP)step=MAX_STEP;smooth=previous-step;
   end else begin
    step=(distance+(1<<SMOOTH_SHIFT)-1)>>SMOOTH_SHIFT;
    if(step>MAX_STEP)step=MAX_STEP;smooth=previous+step;
   end
  end
 endfunction
 always @(posedge clk)begin
  if(rst)begin
   old_vs<=0;old_de<=0;x<=0;y<=0;sum_r<=0;sum_g<=0;sum_b<=0;samples<=0;
   gain_r<=256;gain_g<=256;gain_b<=256;update_pulse<=0;accepted_samples<=0;rejected_frame<=0;
   busy<=0;channel<=0;bit_count<=0;quotient<=0;remainder<=0;denominator<=0;
   saved_g<=0;saved_b<=0;saved_total<=0;target_r<=256;target_g<=256;
  end else begin
   old_vs<=vs;old_de<=de;update_pulse<=0;
   if(de)x<=x+1'b1;else x<=0;
   if(frame_edge)y<=0;else if(old_de && !de)y<=y+1'b1;
   if(frame_edge)begin
    sum_r<=0;sum_g<=0;sum_b<=0;samples<=0;
    accepted_samples<=stat_n;
    rejected_frame<=(stat_n<MIN_SAMPLES)||(stat_r==0)||(stat_g==0)||(stat_b==0)||busy;
    if(enable && !hold_gain && !busy && stat_n>=MIN_SAMPLES && stat_r!=0 && stat_g!=0 && stat_b!=0)begin
     busy<=1;channel<=0;bit_count<=0;remainder<=0;
     quotient<={sum_all,8'd0}+{8'd0,(den_r>>1)};denominator<=den_r;
     saved_total<=sum_all;saved_g<=stat_g;saved_b<=stat_b;
    end
   end else if(sample_now)begin
    sum_r<=sum_r+add_r;sum_g<=sum_g+add_g;sum_b<=sum_b+add_b;
    samples<=samples+{31'd0,a0}+{31'd0,a1};
   end
   if(busy)begin
    quotient<=next_q;remainder<=next_rem;bit_count<=bit_count+1'b1;
    if(bit_count==41)begin
     if(channel==0)begin
      target_r<=bound(next_q);channel<=1;bit_count<=0;remainder<=0;
      quotient<={saved_total,8'd0}+{8'd0,(den_g>>1)};denominator<=den_g;
     end else if(channel==1)begin
      target_g<=bound(next_q);channel<=2;bit_count<=0;remainder<=0;
      quotient<={saved_total,8'd0}+{8'd0,(den_b>>1)};denominator<=den_b;
     end else begin
      busy<=0;
      if(enable && !hold_gain)begin
       gain_r<=smooth(gain_r,target_r);gain_g<=smooth(gain_g,target_g);gain_b<=smooth(gain_b,bound(next_q));update_pulse<=1;
      end
     end
    end
   end
  end
 end
endmodule
