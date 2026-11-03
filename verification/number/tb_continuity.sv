`timescale 1ns/1ps
module tb_continuity;
 reg clk=0;always #5 clk=~clk;
 reg rst_n=0,de=0,vs=0;reg [47:0] rgb=0;reg [7:0] threshold=2;
 reg [15:0] din=0,sin=0;wire [15:0] display_edges,strong_edges;wire od,ov,os;
 reg [7:0] images[0:44799],input_d[0:44799],input_s[0:44799],expected_d[0:44799],expected_s[0:44799];
 integer k,x,y,ox=0,oy=0,frame=0,checks=0,idx;reg os_d=0,od_d=0;
 edge_continuity_2ppc #(.IMG_W(80),.IMG_H(80),.H_TOTAL_BEATS(48)) dut(
 .clk(clk),.rst_n(rst_n),.rgb_x2_in(rgb),.de_in(de),.valid_in(de),.hsync_in(1'b0),.vsync_in(vs),
 .display_in(din),
 .strong_in(sin),
 .edge_x2_out(display_edges),.strong_edge_x2_out(strong_edges),.rgb_x2_orig_out(),.de_out(od),.valid_out(ov),.hsync_out(),.vsync_out(os));
 always @(posedge clk)if(rst_n)begin
  os_d<=os;od_d<=od;
  if(os_d&&!os)begin frame=frame+1;ox=0;oy=0;end
  if(od&&ov)begin
   idx=(frame-1)*6400+oy*80+ox;
   if(frame<1||frame>7||^display_edges===1'bx||^strong_edges===1'bx)$fatal(1,"invalid output");
   if((display_edges[7:0]==255)!==(expected_d[idx]!=0)||(display_edges[15:8]==255)!==(expected_d[idx+1]!=0))$fatal(1,"display mismatch frame=%0d x=%0d y=%0d",frame,ox,oy);
   if((strong_edges[7:0]==255)!==(expected_s[idx]!=0)||(strong_edges[15:8]==255)!==(expected_s[idx+1]!=0))$fatal(1,"strong mismatch frame=%0d x=%0d y=%0d",frame,ox,oy);
   checks=checks+2;ox=ox+2;
  end else if(od_d&&!od)begin ox=0;oy=oy+1;end
 end
 initial begin
  $readmemh("verification/number/cont_display.mem",images);$readmemh("verification/number/cont_display.mem",input_d);$readmemh("verification/number/cont_strong.mem",input_s);$readmemh("verification/number/cont_expected_d.mem",expected_d);$readmemh("verification/number/cont_expected_s.mem",expected_s);
  if(^images[0]===1'bx||^expected_d[0]===1'bx||^expected_s[0]===1'bx)$fatal(1,"missing fixtures");
  repeat(5)@(negedge clk);rst_n=1;repeat(5)@(negedge clk);
  for(k=0;k<7;k=k+1)begin
   threshold=k==5?8:2;vs=1;repeat(3)@(negedge clk);vs=0;repeat(3)@(negedge clk);
   for(y=0;y<80;y=y+1)begin
    for(x=0;x<80;x=x+2)begin
     @(negedge clk);de=1;din={{8{input_d[k*6400+y*80+x+1]!=0}},{8{input_d[k*6400+y*80+x]!=0}}};sin={{8{input_s[k*6400+y*80+x+1]!=0}},{8{input_s[k*6400+y*80+x]!=0}}};rgb={{3{images[k*6400+y*80+x+1]}},{3{images[k*6400+y*80+x]}}};
     if(k==6&&y==30&&x==20)threshold=30;
    end
    @(negedge clk);de=0;repeat(7)@(negedge clk);
   end
  end
  repeat(100)@(negedge clk);
  if(checks!=44800)$fatal(1,"missing pixels %0d",checks);
  $display("PASS CONTINUITY: 44800 exact dual-mask pixels, isolated/2-pixel removal, line/diagonal preservation, sparse noise");$finish;
 end
 initial begin #1000000;$fatal(1,"timeout");end
endmodule
