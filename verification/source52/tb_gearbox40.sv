`timescale 1ns/1ps
module gearbox_case40 #(parameter real PHASE=0)(input pair_clk,arst_n,output reg done);
 reg pixel_clk=0;
 initial begin #(PHASE);forever #5 pixel_clk=~pixel_clk;end
 reg [47:0] rgb_pair=0;reg de_pair=0,hs_pair=0,vs_pair=0;
 wire [23:0] rgb;wire de,hs,vs,fault;
 hdmi_gearbox40 dut(pair_clk,pixel_clk,arst_n,rgb_pair,de_pair,hs_pair,vs_pair,rgb,de,hs,vs,fault);
 reg [26:0] expected[0:80000];integer tail=0,head=0,i=0,checks=0;
 reg active_before;
 always @(negedge pair_clk)begin
  if(!arst_n)begin i=0;rgb_pair=0;de_pair=0;hs_pair=0;vs_pair=0;end
  else begin
   rgb_pair={24'(i*2+1),24'(i*2)};de_pair=(i%1100)>=96 && (i%1100)<1056;
   hs_pair=(i%1100)<22;vs_pair=(i/1100)%1125<5;i=i+1;
  end
 end
 always @(posedge pair_clk)begin
  if(!arst_n)tail=0;
  else if(dut.pair_reset[1])begin
   expected[tail]={rgb_pair[23:0],de_pair,hs_pair,vs_pair};
   expected[tail+1]={rgb_pair[47:24],de_pair,hs_pair,vs_pair};tail=tail+2;
  end
 end
 always @(posedge pixel_clk)begin
  if(!arst_n)begin head=0;checks=0;done=0;end
  else begin
   active_before=dut.pixel_reset[1] && dut.started;
   #1;
   if(fault)$fatal(1,"GEARBOX40 unexpected fault phase=%0f",PHASE);
   if(active_before)begin
    if(head>=tail || {rgb,de,hs,vs}!==expected[head])
     $fatal(1,"GEARBOX40 phase=%0f index=%0d got=%h expected=%h",PHASE,head,{rgb,de,hs,vs},expected[head]);
    head=head+1;checks=checks+1;
    if(checks>18000)done=1;
   end
  end
 end
endmodule
module tb_gearbox40;
 reg pair_clk=0;always #10 pair_clk=~pair_clk;
 reg arst_n=0;wire [2:0] done;integer epoch;
 gearbox_case40 #(.PHASE(0)) a(pair_clk,arst_n,done[0]);
 gearbox_case40 #(.PHASE(1.3)) b(pair_clk,arst_n,done[1]);
 gearbox_case40 #(.PHASE(3.7)) c(pair_clk,arst_n,done[2]);
 initial begin
  for(epoch=0;epoch<5;epoch=epoch+1)begin
   arst_n=0;#(73+epoch*3);arst_n=1;
   wait(&done);#(11+epoch*7);
  end
  $display("PASS GEARBOX40 three clock phases, five resets, RGB lane order, all blank/active DE/HS/VS, no loss or duplication");$finish;
 end
 initial begin #2000000;$fatal(1,"GEARBOX40 timeout");end
endmodule
