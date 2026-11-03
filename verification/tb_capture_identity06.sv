`timescale 1ns/1ps
`include "verification/baselines/recognition56_literal.vh"
module tb_capture_identity06;
localparam W=384,H=256,HT=220,VT=280;
reg clk=0;always #5 clk=~clk;reg rn=0,en=0,aux=1,lockreq=0,de=0,hs=0,vs=0;
reg [47:0] rgb=0;reg [15:0] edgev=0,mag=0,accepted=0;
wire [47:0] a,b;wire [1:0] am,bm;wire [15:0] ag,bg,aa,ba;wire ad,bd,ah,bh,av,bv,al,bl,ar,br;wire [2:0] at,bt;
final_recognition #(.UI_V2(1),.W(W),.H(H),.HT(HT)) dut(
.clk(clk),.rst_n(rn),.shape_enable(en),.number_enable(1'b0),.aux_visible(aux),.shape_lock_request(lockreq),.shape_locked(al),.shape_result_valid(ar),.capture_tag(at),
.rgb_in(rgb),.edges(edgev),.number_edges(edgev),.mag(mag),.accepted(accepted),.de(de),.hs(hs),.vs(vs),.rgb_out(a),.overlay_mask(am),.mag_out(ag),.accepted_out(aa),.de_out(ad),.hs_out(ah),.vs_out(av));
golden_recognition56 #(.UI_V2(1),.W(W),.H(H),.HT(HT)) golden(
.clk(clk),.rst_n(rn),.shape_enable(en),.number_enable(1'b0),.aux_visible(aux),.shape_lock_request(lockreq),.shape_locked(bl),.shape_result_valid(br),.capture_tag(bt),
.rgb_in(rgb),.edges(edgev),.number_edges(edgev),.mag(mag),.accepted(accepted),.de(de),.hs(hs),.vs(vs),.rgb_out(b),.overlay_mask(bm),.mag_out(bg),.accepted_out(ba),.de_out(bd),.hs_out(bh),.vs_out(bv));
integer checks=0,pubs=0,f,y,x,xx,yy;
always @(negedge clk)if(rn)begin
 if({a,am,ag,aa,ad,ah,av,al,ar,at}!=={b,bm,bg,ba,bd,bh,bv,bl,br,bt})$fatal(1,"56 capture difference frame=%0d xy=%0d,%0d",f,x,y);
 checks++;
 if(dut.ack)pubs++;
end
function hit(input integer xx,yy);
begin hit=((xx>=64&&xx<=256)&&(yy==40||yy==200))||((yy>=40&&yy<=200)&&(xx==64||xx==256));end endfunction
initial begin
repeat(5)@(negedge clk);rn=1;
for(f=0;f<24;f++)begin
en=f>=1&&f!=22;aux=!(f>=12&&f<16);lockreq=f>=17&&f<20;
for(y=0;y<VT;y++)for(x=0;x<HT;x++)begin
 @(posedge clk);#1;vs=y<2;hs=x<2;de=y>=4&&y<4+H&&x>=8&&x<8+W/2;
 xx=(x-8)*2;yy=y-4;rgb={24'(xx*101+yy*83+f*41),24'(xx*71+yy*59+f*31)};
 edgev=de?{hit(xx+1,yy)?8'hff:8'h00,hit(xx,yy)?8'hff:8'h00}:16'd0;
 mag={8'(xx+yy),8'(xx*3+yy)};accepted=edgev;
end end
if(checks<1000000||pubs<1)$fatal(1,"insufficient capture equivalence coverage checks=%0d pubs=%0d",checks,pubs);
$display("PASS CAPTURE_IDENTITY06 %0d every-cycle comparisons against literal56; real rectangle classifier publications=%0d; RGB, edges, masks, thresholds, AUX, result lock and task reentry unchanged",checks,pubs);$finish;
end
initial begin #30000000;$fatal(1,"capture timeout");end
endmodule
