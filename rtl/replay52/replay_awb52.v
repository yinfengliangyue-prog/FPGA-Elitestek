// Linear RGB three-channel AUTO WB. Estimator from 50; no gamma/spatial filter.
// All three gains latch together at the first active pair of a frame.
module replay_awb52 #(parameter MIN_SAMPLES=256)(
 input wire clk,rst_n,input wire [47:0] rgb,input wire de,hs,vs,
 output reg [47:0] out_rgb,output reg out_de,out_hs,out_vs,
 output reg [11:0] gain_r,gain_g,gain_b
);
 wire [11:0] ar,ag,ab;reg old_vs,pending;
 wire sof=de&&(pending||(vs&&!old_vs));
 awb_grayworld_rgb_2ppc #(.FALLBACK_ENABLE(1),.MIN_SAMPLES(MIN_SAMPLES)) estimator(
  .clk(clk),.rst(!rst_n),.enable(1'b1),.hold_gain(1'b0),.rgb(rgb),.de(de),.vs(vs),
  .gain_r(ar),.gain_g(ag),.gain_b(ab),.update_pulse(),.accepted_samples(),.rejected_frame());
 wire [11:0] gr=sof?ar:gain_r,gg=sof?ag:gain_g,gb=sof?ab:gain_b;
 reg [19:0] product[0:5];reg dd,dh,dv;integer k;
 function [7:0] clip(input [19:0] p);clip=(p+20'd128)>=20'd65536 ? 8'd255 : ((p+20'd128)>>8);endfunction
 always @(posedge clk)begin
  if(!rst_n)begin
   old_vs<=0;pending<=1;gain_r<=256;gain_g<=256;gain_b<=256;
   dd<=0;dh<=0;dv<=0;out_rgb<=0;out_de<=0;out_hs<=0;out_vs<=0;
   for(k=0;k<6;k=k+1)product[k]<=0;
  end else begin
   old_vs<=vs;if(vs&&!old_vs)pending<=1;
   if(sof)begin pending<=0;gain_r<=ar;gain_g<=ag;gain_b<=ab;end
   product[0]<=rgb[7:0]*gb;product[1]<=rgb[15:8]*gg;product[2]<=rgb[23:16]*gr;
   product[3]<=rgb[31:24]*gb;product[4]<=rgb[39:32]*gg;product[5]<=rgb[47:40]*gr;
   dd<=de;dh<=hs;dv<=vs;out_de<=dd;out_hs<=dh;out_vs<=dv;
   for(k=0;k<6;k=k+1)out_rgb[k*8+:8]<=clip(product[k]);
  end
 end
endmodule
