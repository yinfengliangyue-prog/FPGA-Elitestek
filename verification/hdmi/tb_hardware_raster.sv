`timescale 1ns/1ps
module tb_hardware_raster;
 reg vc=0,pc=0,rst=0;
 always #6.734 vc=~vc;always #3.367 pc=~pc;
 wire [47:0] pair;wire pd,ph,pv;wire [23:0] rgb;wire de,hs,vs,fault;
 data_tx #(.VID_WIDTH(48)) raster(
 .clk(vc),.rst_n(rst),.frame_en(rst),.fifo_wr_data(48'd0),.fifo_wr_en(1'b0),
 .fifo_wr_almost_full(),.fifo_rd_period(),.fifo_rd_underflow(),
 .H_FRONT_PORCH(13'd44),.H_SYNC(13'd22),.H_VALID(13'd960),.H_BACK_PORCH(13'd74),
 .V_FRONT_PORCH(13'd4),.V_SYNC(13'd5),.V_VALID(13'd1080),.V_BACK_PORCH(13'd36),
 .vout(pair),.o_hs(ph),.o_vs(pv),.o_de(pd));
 hdmi_gearbox40 gear(vc,pc,rst,pair,pd,ph,pv,rgb,de,hs,vs,fault);
 integer cycle=0,last_h=-1,last_v=-1,hwidth=0,vwidth=0,line_width=0;
 integer hchecks=0,vchecks=0,lines=0,active=0,frames=0;
 reg old_h=0,old_v=0,old_d=0;
 always @(posedge pc)begin
  #0.1;
  if(rst)begin
   cycle++;
   if(fault)$fatal(1,"gear fault");
   if(hs && !old_h)begin
    if(last_h>=0 && frames>1)begin if(cycle-last_h!=2200)$fatal(1,"horizontal total %0d",cycle-last_h);hchecks++;end
    last_h=cycle;hwidth=0;
   end
   if(hs)hwidth++;
   if(!hs && old_h && hchecks>0 && hwidth!=44)$fatal(1,"HS width %0d",hwidth);
   if(vs && !old_v)begin
    if(last_v>=0 && frames>=2)begin
     if(cycle-last_v!=2475000)$fatal(1,"frame total %0d",cycle-last_v);
     if(lines!=1080 || active!=2073600)$fatal(1,"active raster lines=%0d pixels=%0d",lines,active);
     vchecks++;
    end
    last_v=cycle;vwidth=0;lines=0;active=0;frames++;
   end
   if(vs)vwidth++;
   if(!vs && old_v && frames>1 && vwidth!=11000)$fatal(1,"VS width %0d",vwidth);
   if(de)begin line_width++;active++;end
   if(!de && old_d)begin
    if(line_width!=1920)$fatal(1,"DE width %0d",line_width);
    lines++;line_width=0;
   end
   old_h=hs;old_v=vs;old_d=de;
   if(vchecks==2)begin
    $display("PASS HARDWARE_RASTER 2200x1125 total, 1920x1080 active, HS44 VS5 lines, positive polarity, two complete HDMI frames measured after gearbox");$finish;
   end
  end
 end
 initial begin #1;rst=0;repeat(8)@(negedge vc);rst=1;end
 initial begin #60000000;$fatal(1,"raster timeout");end
endmodule

