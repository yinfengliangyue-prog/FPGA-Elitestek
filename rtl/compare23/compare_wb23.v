// WB is applied to the saved color, AFTER linear Sobel; edge magnitudes are unchanged.
// Three registered gain stages; RGB, gradient and all video controls stay aligned.
module compare_wb23 #(parameter MIN_SAMPLES=256,FALLBACK_MIN_SAMPLES=1024)(
 input wire clk,rst_n,lock_request,input wire [47:0] rgb_in,input wire [15:0] mag_in,
 input wire de_in,hs_in,vs_in,output reg [47:0] rgb_out,output wire [15:0] mag_out,
 output wire de_out,hs_out,vs_out,output reg locked,output wire rejected
);
 reg pending,vs_d,request_d;
 reg [11:0] applied_r,applied_b,locked_r,locked_b;
 wire [11:0] auto_r,auto_b;
 wire sof=de_in && (pending || (vs_in && !vs_d));
 wire [11:0] selected_r=lock_request ? (request_d ? locked_r : applied_r) : auto_r;
 wire [11:0] selected_b=lock_request ? (request_d ? locked_b : applied_b) : auto_b;
 wire [11:0] use_r=sof ? selected_r : applied_r,use_b=sof ? selected_b : applied_b;
 awb_grayworld_2ppc #(.FALLBACK_ENABLE(1),.MIN_SAMPLES(MIN_SAMPLES),
  .FALLBACK_MIN_SAMPLES(FALLBACK_MIN_SAMPLES)) estimator(
  .clk(clk),.rst(!rst_n),.enable(1'b1),.hold_gain(lock_request),.rgb(rgb_in),.de(de_in),.vs(vs_in),
  .gain_r(auto_r),.gain_b(auto_b),.update_pulse(),.accepted_samples(),.rejected_frame(rejected));
 reg [19:0] pr0,pb0,pr1,pb1;reg [8:0] r0,b0,r1,b1;
 reg [7:0] g0a,g1a,g0b,g1b;
 reg [2:0] ds,hs,vs;reg [15:0] mags[0:2];
 function [8:0] halfscale(input [19:0] n);
  reg [20:0] q;begin q=({1'b0,n}+21'd64)>>7;halfscale=q>511 ? 9'd511 : q[8:0];end
 endfunction
 function [7:0] integer_value(input [8:0] q);
  reg [9:0] n;begin n={1'b0,q}+10'd1;integer_value=n>=510 ? 8'd255 : n[8:1];end
 endfunction
 assign de_out=ds[2];assign hs_out=hs[2];assign vs_out=vs[2];assign mag_out=mags[2];
 always @(posedge clk) begin
  if(!rst_n) begin
   pending<=1;vs_d<=0;request_d<=0;locked<=0;
   applied_r<=256;applied_b<=256;locked_r<=256;locked_b<=256;
   pr0<=0;pb0<=0;pr1<=0;pb1<=0;r0<=0;b0<=0;r1<=0;b1<=0;
   g0a<=0;g1a<=0;g0b<=0;g1b<=0;ds<=0;hs<=0;vs<=0;
   mags[0]<=0;mags[1]<=0;mags[2]<=0;rgb_out<=0;
  end else begin
   vs_d<=vs_in;request_d<=lock_request;
   if(vs_in && !vs_d) pending<=1;
   if(sof) begin pending<=0;applied_r<=selected_r;applied_b<=selected_b;locked<=lock_request;end
   if(lock_request && !request_d) begin locked_r<=applied_r;locked_b<=applied_b;end
   pr0<=rgb_in[23:16]*use_r;pb0<=rgb_in[7:0]*use_b;
   pr1<=rgb_in[47:40]*use_r;pb1<=rgb_in[31:24]*use_b;
   g0a<=rgb_in[15:8];g1a<=rgb_in[39:32];g0b<=g0a;g1b<=g1a;
   r0<=halfscale(pr0);b0<=halfscale(pb0);r1<=halfscale(pr1);b1<=halfscale(pb1);
   rgb_out<={integer_value(r1),g1b,integer_value(b1),integer_value(r0),g0b,integer_value(b0)};
   ds<={ds[1:0],de_in};hs<={hs[1:0],hs_in};vs<={vs[1:0],vs_in};
   mags[0]<=mag_in;mags[1]<=mags[0];mags[2]<=mags[1];
  end
 end
endmodule
