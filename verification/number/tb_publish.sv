`timescale 1ns/1ps
// Deliberately isolate transaction glue; real CCL/MLP are tested separately.
module tb_publish;
 reg clk=0;always #5 clk=~clk;
 reg rst_n=0,en=1;wire [47:0] rgb;wire de,valid,hs,vs,on_frame,detected;
 number_video_pipeline dut(.clk(clk),.rst_n(rst_n),.enable(en),.expression_mode(1'b0),.lock_pulse(1'b0),.rgb_in(48'd0),.de_in(1'b0),.valid_in(1'b0),.hs_in(1'b0),.vs_in(1'b0),.threshold_in(8'd2),.rgb_out(rgb),.de_out(de),.valid_out(valid),.hs_out(hs),.vs_out(vs),.enabled_frame(on_frame),.detected_frame(detected),.ui_expression_locked());
 reg we=0,pb=0,start=0,done=0,blank=0,sel=1,evs=0;reg [9:0] addr=0;
 reg [3:0] digit=7;reg signed [31:0] margin=900;
 reg [7:0] x0=10,x1=30,y0=40,y1=80;
 integer i,checks=0;reg [783:0] expected;
 task frame;begin @(negedge clk);evs=1;repeat(3)@(negedge clk);evs=0;repeat(3)@(negedge clk);end endtask
 task upload;input [3:0] d;input integer bx;begin
  digit=d;x0=bx;x1=bx+20;y0=40;y1=80;sel=1;expected=0;
  for(i=0;i<784;i=i+1)begin @(negedge clk);we=1;addr=i;pb=(i%13==d);expected[i]=pb;end
  @(negedge clk);we=0;start=1;@(negedge clk);start=0;repeat(5)@(negedge clk);
 end endtask
 task finish;begin @(negedge clk);done=1;@(negedge clk);done=0;repeat(4)@(negedge clk);end endtask
 task check;input [3:0] d;input integer bx;begin
  frame;
  if(dut.result!==d||dut.box_x0!==bx||!dut.box_valid)$fatal(1,"publication mismatch d=%0d box=%0d expected=%0d,%0d",dut.result,dut.box_x0,d,bx);
  for(i=0;i<784;i=i+1)if((dut.front?dut.preview1[i]:dut.preview0[i])!==expected[i])$fatal(1,"preview transaction mismatch %0d",i);
  checks=checks+1;
 end endtask
 initial begin
  force dut.we=we;force dut.addr=addr;force dut.bit_in=pb;force dut.start=start;
  force dut.nn_done=done;force dut.number=digit;force dut.margin=margin;force dut.empty=blank;
  force dut.selection_valid=sel;force dut.sel_x0=x0;force dut.sel_x1=x1;force dut.sel_y0=y0;force dut.sel_y1=y1;
  force dut.edge_vs=evs;
  repeat(5)@(negedge clk);rst_n=1;frame;
  upload(7,10);finish;check(15,10);
  upload(7,10);finish;check(15,10);
  upload(7,10);finish;check(7,10);
  // Selection changes during processing: old box and preview stay together.
  upload(8,80);frame;
  if(dut.box_x0!=10||dut.result!=7)$fatal(1,"box advanced before inference publication");
  finish;check(15,80);
  upload(8,80);finish;check(15,80);
  upload(8,80);finish;check(8,80);
  // Same-position conflicting label cannot inherit the held old annotation.
  upload(1,80);finish;check(15,80);
  upload(8,80);finish;check(8,80);
  // Weak result also hides the held annotation.
  margin=299;upload(8,80);finish;check(15,80);margin=900;
  @(negedge clk);sel=0;blank=1;@(negedge clk);blank=0;repeat(4)@(negedge clk);frame;
  if(dut.box_valid||dut.result!=15)$fatal(1,"empty box/result not cleared");
  for(i=0;i<784;i=i+1)if((dut.front?dut.preview1[i]:dut.preview0[i])!==0)$fatal(1,"empty preview not cleared");
  en=0;frame;if(on_frame||detected||dut.box_valid)$fatal(1,"OFF did not clear display");
  $display("PASS PUBLISH33: %0d atomic box/preview/result transactions, spatial reset, conflicting/weak results hidden, blank/OFF",checks);$finish;
 end
 initial begin #1000000;$fatal(1,"timeout");end
endmodule
