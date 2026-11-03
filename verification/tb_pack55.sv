`timescale 1ns/1ps
module tb_pack55;
parameter W=96,H=64,HT=64,VT=70,N=4;localparam L=4*HT+19;
reg clk=0;always #5 clk=~clk;reg rn=0,de=0,vs=0;reg [47:0] rgb=0;reg [15:0] mag=0,acc=0,bal=0,cln=0;reg [1:0] ann=0;reg exact=0;
wire rde,rvs;wire [15:0] rb,rc;wire reset,start,we,fault;wire [127:0] data;
canny_delay #(.WIDTH(34),.DEPTH(L)) rdelay(clk,rn,{bal,cln,de,vs},{rb,rc,rde,rvs});
pack55 #(.W(W),.H(H)) dut(clk,rn,de,vs,rgb,mag,acc,ann,exact,rde,rvs,rb,rc,reset,start,we,data,fault);
reg [63:0] inputs[0:N*W*H-1],refs[0:N*W*H/4-1];string ip,rp;integer f,y,x,j,i=0;integer max_occupancy=0,occupancy,k,word_phase=0;reg [383:0] collected=0;
always @(posedge clk)begin #1;if(rn)begin
if(fault)$fatal(1,"pairing fault occupancy=%0d",dut.wp-dut.rp);
occupancy=(dut.wp-dut.rp)&(2*dut.FIFO_DEPTH-1);
if(occupancy>max_occupancy)max_occupancy=occupancy;
if(we)begin
for(k=0;k<4;k++)begin
 if(data[127-k*32-:32]!=={refs[i][31:16],(|refs[i][39:32]),refs[i][14:0]})$fatal(1,"packed32 index %0d got=%h expected=%h",i,data[127-k*32-:32],{refs[i][31:16],(|refs[i][39:32]),refs[i][14:0]});i++;
end
end end end
initial begin
ip="verification/pack_input.hex";rp="verification/pack_expected.hex";
$readmemh(ip,inputs);$readmemh(rp,refs);repeat(8)@(negedge clk);rn=1;
for(f=0;f<N;f++)for(y=0;y<VT;y++)for(x=0;x<HT;x++)begin
@(negedge clk);vs=y<2;de=y>=4&&y<H+4&&x>=4&&x<W/2+4;exact=f%2;
j=f*W*H+(y-4)*W+(x-4)*2;
if(de)begin rgb={inputs[j+1][23:0],inputs[j][23:0]};mag={inputs[j+1][63:56],inputs[j][63:56]};acc={inputs[j+1][55:48],inputs[j][55:48]};bal={inputs[j+1][47:40],inputs[j][47:40]};cln={inputs[j+1][39:32],inputs[j][39:32]};ann={inputs[j+1][24],inputs[j][24]};end
else begin rgb=0;mag=0;acc=0;bal=0;cln=0;ann=0;end
end
@(negedge clk);de=0;vs=0;repeat(L+HT*3+100)@(negedge clk);
if(i!=N*W*H/4)$fatal(1,"count %0d",i);
if(dut.wp!=dut.rp)$fatal(1,"queue not drained");
$display("PASS PACK55_32BIT W=%0d H=%0d frames=%0d quarter_pixels=%0d max_queued=%0d independent NMS/accepted/BAL/CLEAN, annotations and frame overlap",W,H,N,i,max_occupancy);$finish;
end
endmodule
