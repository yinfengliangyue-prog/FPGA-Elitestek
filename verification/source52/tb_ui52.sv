`timescale 1ns/1ps
// Actual 1080p raster with an explicitly synthetic, already-filled 120-frame
// fixture. Separate from the short-take DDR/HDMI end-to-end regression.
module tb_ui52;
reg clk=0;always #6.734 clk=~clk;reg rn=0,ack=0,seen=0;
wire ft,reset,pop,de,hs,vs,fault;wire [47:0] rgb;
reg [95:0] ui=0;reg [127:0] head;integer word_index=0,delay_count=0,page=0,frame=0;
replay_raster52 dut(clk,rn,1'b1,ack,ui,ft,reset,1'b0,head,pop,rgb,de,hs,vs,fault,8'd6,8'd3);
function automatic [31:0] sample_pixel(input integer i);
integer x,y,r,g,b,s,side;begin
 y=i/1920;x=i%960;side=(i%1920)>=960;
 r=60+x/8;g=80+y/5;b=150-x/12;
 s=((x>=200&&x<204)||(x>=600&&x<604)||(y>=130&&y<134)||(y>=400&&y<404))?220:0;
 if(x>=200&&x<604&&y>=130&&y<404)begin r=180;g=80+x/12;b=55+y/6;end
 sample_pixel={8'(s),s!=0,8'(r),8'(g),7'(b/2)};
end endfunction
always @* head={sample_pixel(word_index*4),sample_pixel(word_index*4+1),sample_pixel(word_index*4+2),sample_pixel(word_index*4+3)};
always @(negedge clk)if(rn)begin
 if(ft!=seen)begin
  seen=ft;delay_count=64;word_index=0;
  case(page)
   0:ui={29'd0,2'd0,1'b1,1'b0,1'b0,2'd1,8'd120,8'd0,8'd0,2'd0,2'd2,8'd6,8'd3,16'd0};
   1:ui={29'd0,2'd1,1'b1,1'b0,1'b1,2'd1,8'd120,8'd0,8'd42,2'd0,2'd1,8'd6,8'd3,16'd0};
   2:ui={29'd0,2'd2,1'b1,1'b0,1'b0,2'd1,8'd120,8'd12,8'd107,2'd0,2'd2,8'd6,8'd3,16'd1583};
  endcase
 end
 if(delay_count>0)begin delay_count--;if(delay_count==0)ack=~ack;end
 if(fault)$fatal(1,"UI fixture underflow");
end
// Show-ahead FIFO advances after the edge which consumes the second half.
always @(posedge clk)if(rn && pop)word_index<=word_index+1;
integer fd=0,pixels=0;reg old_vs=0;string name;
always @(posedge clk)begin #3;if(rn)begin
 if(vs&&!old_vs)begin
  if(fd)begin
   $fclose(fd);fd=0;if(pixels!=1920*1080)$fatal(1,"UI fixture geometry");
   page++;if(page==3)begin $display("PASS UI52 actual raster 1920x1080 LIVE/REPLAY/COMPARE synthetic 120-frame fixture");$finish;end
  end
  frame++;
  if(frame>=2)begin
   name=$sformatf("ui52_fixture_%0d.ppm",page);fd=$fopen(name,"wb");$fwrite(fd,"P6\n1920 1080\n255\n");pixels=0;
  end
 end
 if(de&&fd)begin $fwrite(fd,"%c%c%c%c%c%c",rgb[23:16],rgb[15:8],rgb[7:0],rgb[47:40],rgb[39:32],rgb[31:24]);pixels+=2;end
 old_vs=vs;
end end
initial begin repeat(10)@(negedge clk);rn=1;end
initial begin #1000000000;$fatal(1,"UI timeout");end
endmodule
