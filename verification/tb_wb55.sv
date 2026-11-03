`timescale 1ns/1ps
module tb_wb55;
`ifdef FULL_HD
localparam W=1920,H=1080,HT=1100,VT=1125,N=3;
`else
localparam W=64,H=32,HT=48,VT=42,N=48;
`endif
reg clk=0;always #5 clk=~clk;reg rn=0,lock=0,de=0,hs=0,vs=0;reg [47:0] rgb=0;
wire [47:0] out,ref_rgb;wire od,oh,ov,rd,rh,rv,locked,rejected;wire [11:0] qr,qg,qb;
final_wb55 #(.W(W),.H(H),.HT(HT),.MIN_SAMPLES(8)) dut(clk,rn,lock,rgb,de,hs,vs,out,od,oh,ov,locked,rejected,qr,qg,qb);
// Literal53 color/gamma/Gaussian/sharpen, with final effective gains (no double trim).
wb53_ref #(.WIDTH(W),.HEIGHT(H),.LINE_CLOCKS(HT),.AWB_ENABLE(0),.OSD_ENABLE(0),.GREEN_SCALE_Q8(256)) ref53(
.clk(clk),.rst(!rn),.in_rgb(rgb),.in_de(de),.in_hs(hs),.in_vs(vs),.out_rgb(ref_rgb),.out_de(rd),.out_hs(rh),.out_vs(rv),
.key_n(4'd15),.wb_mode(),.wb_rejected(),.ref_r(dut.nr),.ref_g(dut.ng),.ref_b(dut.nb));
integer checks=0,changes=0,f,y,k;reg [35:0] prev=0,saved=0;reg previous_sof=0;
always @(posedge clk)begin
if(rn)begin previous_sof=dut.sof;#1;
if({od,oh,ov}!=={rd,rh,rv}||(od&&out!==ref_rgb))$fatal(1,"accepted53 arithmetic mismatch checks=%0d actual=%h ref=%h",checks,out,ref_rgb);
if(od)checks+=2;
if(qr<304||qr>336||qg<151||qg>165||qb<313||qb>345)$fatal(1,"effective gains outside accepted +/-5%% envelope");
if(prev!=0&&{qr,qg,qb}!=prev)begin
 if(!previous_sof)$fatal(1,"Q8 changed inside frame");
 if((qr>prev[35:24]?qr-prev[35:24]:prev[35:24]-qr)>1||
    (qg>prev[23:12]?qg-prev[23:12]:prev[23:12]-qg)>1||
    (qb>prev[11:0]?qb-prev[11:0]:prev[11:0]-qb)>1)$fatal(1,"accepted update larger than 1 Q8");changes++;
end
prev={qr,qg,qb};end end
function [23:0] pixel(input integer x,y,f);
begin
if(f>=32)pixel=24'hffffff;
else pixel={8'(100+(x+y)%24),8'(136+(x*3+y)%24),8'(116+(x+y*3)%24)};
end endfunction
initial begin
repeat(8)@(negedge clk);rn=1;if({qr,qg,qb}!={12'd320,12'd158,12'd329})$fatal(1,"baseline start");
for(f=0;f<N;f++)begin
if(f==20)begin lock=1;saved={qr,qg,qb};end
if(f==28)lock=0;
for(y=0;y<VT;y++)for(k=0;k<HT;k++)begin
@(negedge clk);vs=y<2;hs=k<2;de=y>=4&&y<H+4&&k>=4&&k<W/2+4;
rgb=de?{pixel((k-4)*2+1,y-4,f),pixel((k-4)*2,y-4,f)}:0;
end
if(f>=21&&f<28&&{qr,qg,qb}!=saved)$fatal(1,"LOCK did not freeze actual effective values");
if(f==34)saved={qr,qg,qb};
if(f>34&&{qr,qg,qb}!=saved)$fatal(1,"rejected bright samples changed baseline");
end
@(negedge clk);de=0;vs=0;repeat(HT*4)@(negedge clk);
if(checks!=N*W*H||changes==0)$fatal(1,"insufficient evidence %0d changes=%0d",checks,changes);
$display("PASS WB55 accepted53 Gamma/Gaussian/sharpen bit-exact %0d pixels; reset Q320/158/329; bounded AUTO frame-atomic max1 Q8; LOCK and rejected-sample hold; no double green trim",checks);$finish;
end
endmodule
