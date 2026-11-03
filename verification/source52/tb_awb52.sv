`timescale 1ns/1ps
module tb_awb52;
reg clk=0;always #5 clk=~clk;
reg rn=0,de=0,hs=0,vs=0;reg [47:0] rgb=0;
wire [47:0] out;wire od,oh,ov;wire [11:0] gr,gg,gb;
replay_awb52 #(.MIN_SAMPLES(32)) dut(clk,rn,rgb,de,hs,vs,out,od,oh,ov,gr,gg,gb);
integer f,y,x,checks=0,er=256,eg=256,eb=256;
function integer smooth(input integer old,target);
integer d,step;begin d=target-old;step=((d<0?-d:d)+15)/16;if(step>16)step=16;smooth=d<0?old-step:old+step;end
endfunction
function [7:0] scaled(input integer p,g);integer v;begin v=(p*g+128)/256;scaled=v>255?255:v;end endfunction
reg [47:0] expect0=0,expect1=0;reg d0=0,d1=0,h0=0,h1=0,v0=0,v1=0;
always @(posedge clk)begin
 if(rn)begin
  expect1=expect0;expect0={scaled(rgb[47:40],er),scaled(rgb[39:32],eg),scaled(rgb[31:24],eb),
                          scaled(rgb[23:16],er),scaled(rgb[15:8],eg),scaled(rgb[7:0],eb)};
  d1=d0;d0=de;h1=h0;h0=hs;v1=v0;v0=vs;
  #1;
  if({od,oh,ov}!=={d1,h1,v1})$fatal(1,"AWB two-stage sync");
  if(od)begin
   if(out!==expect1 || gr!=er || gg!=eg || gb!=eb)$fatal(1,"linear RGB / frame gain mismatch f=%0d actual=%h expected=%h gains=%0d/%0d/%0d expected=%0d/%0d/%0d",f,out,expect1,gr,gg,gb,er,eg,eb);
   checks+=2;
  end
 end
end
initial begin
 repeat(8)@(negedge clk);rn=1;
 for(f=0;f<20;f++)begin
  // Input statistics R80 G110 B120: rounded independent targets 331,240,220.
  if(f>0)begin er=smooth(er,331);eg=smooth(eg,240);eb=smooth(eb,220);end
  for(y=0;y<48;y++)for(x=0;x<48;x++)begin
   @(negedge clk);vs=y<2;hs=x<2;de=y>=8&&y<40&&x>=4&&x<36;
   rgb={24'h506e78,24'h506e78};
  end
 end
 @(negedge clk);de=0;vs=0;repeat(5)@(negedge clk);
 if(checks!=20*32*64 || gr<=256 || gg>=256 || gb>=256)$fatal(1,"three-channel AUTO did not update");
 $display("PASS AWB52 independent integer target/smoothing/linear RGB, all R/G/B change, 20 frames, frame-atomic gains, DE/HS/VS");$finish;
end
endmodule
