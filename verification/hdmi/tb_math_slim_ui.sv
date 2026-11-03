`timescale 1ns/1ps
module tb_math_slim_ui;
 reg clk=0;always #5 clk=~clk;
 reg rst_n=0;reg [2:0] keys=7;
 wire inhibit,activity,help,on,expr,lock;
 wire [1:0] page;wire [2:0] key_context;
 integer locks=0,checks=0;
 math_osd_keys #(.DEBOUNCE_CYCLES(4)) key_dut(
  .clk(clk),.rst_n(rst_n),.key_n(keys),.inhibit_sw0(inhibit),.menu_page(page),
  .osd_activity_toggle(activity),.osd_help_toggle(help),.osd_context(key_context));
 expression_key_control #(.DEBOUNCE_CYCLES(4),.LONG_CYCLES(50)) mode_dut(
  .clk(clk),.rst_n(rst_n),.key_n(keys[0]),.inhibit(inhibit),
  .enabled(on),.expression_mode(expr),.lock_pulse(lock));
 always @(posedge clk)if(lock)locks=locks+1;
 task ticks(input integer n);begin repeat(n)@(negedge clk);end endtask
 task gesture(input [2:0] value,input integer n);begin keys=value;ticks(n);keys=7;ticks(16);end endtask
 reg de=0,valid=0,vs=0;
 reg enabled=0,expression=0,locked=0,activity_ui=0,help_ui=0;reg [2:0] context_ui=0;
 reg [1:0] page_ui=2;
 wire [47:0] painted;
 math_slim_osd #(.OSD_TIMEOUT_FRAMES(4)) osd(
  .clk(clk),.rst_n(rst_n),.enable(enabled),.expression_mode(expression),.expression_locked(locked),
  .menu_page(page_ui),.osd_activity_toggle(activity_ui),.osd_help_toggle(help_ui),.osd_context(context_ui),
  .rgb_in(48'h335577335577),.de(de),.valid(valid),.vs(vs),.rgb_out(painted));
 task sof;begin vs=1;ticks(2);vs=0;ticks(2);end endtask
 task visible(input integer row,input bit expected);begin
  if(osd.osd_row_visible(row)!==expected)$fatal(1,"row%0d visibility expected%0d",row,expected);
  checks=checks+1;
 end endtask
 integer f,yy,xx,fd,pixels;reg [23:0] expected0,expected1;
 function [23:0] ref_pixel(input integer x,y);
  integer row,ci,col,gr;reg [34:0] bits;reg [7:0] c;
  begin
   ref_pixel=24'h335577;
   if(x>=12&&x<588&&y>=20&&y<164)begin
    row=(y-20)/24;ci=(x-12)/12;col=((x-12)%12)/2;gr=((y-20)%24)/2;
    if(row<=1)begin
     c=osd.menu_character(row,ci);bits=osd.glyph(c);ref_pixel=24'h101010;
     if(gr<7&&col<5&&bits[34-gr*5-col])ref_pixel=24'hffffff;
    end
   end
  end
 endfunction
 initial begin
  keys=0;ticks(5);rst_n=1;ticks(20);keys=7;ticks(20);
  if(on||expr||help||page!=2||locks)$fatal(1,"held-at-start should not act");
  gesture(6,18);if(!on||expr)$fatal(1,"SW0 first short NUMBER");
  gesture(6,18);if(!on||!expr)$fatal(1,"SW0 second short EXPR");
  gesture(6,90);if(locks!=1||!expr)$fatal(1,"SW0 long EXPR lock");
  gesture(1,18);if(page!=3||!expr||locks!=1)$fatal(1,"1+2 page changed original mode");
  gesture(0,18);if(!help||!expr||locks!=1)$fatal(1,"0+1+2 help changed original mode");
  // Every staggered release order cancels the entire SW0 gesture.
  keys=0;ticks(18);keys=1;ticks(18);keys=7;ticks(18);
  if(help||!expr||locks!=1)$fatal(1,"staggered release help or original mode");
  keys=0;ticks(18);keys=6;ticks(18);keys=7;ticks(18);
  if(!help||!expr||locks!=1)$fatal(1,"SW0-last release caused mode/lock");
  // Another key joining a held SW0 also cancels its long action.
  keys=6;ticks(20);keys=2;ticks(100);keys=6;ticks(18);keys=7;ticks(18);
  if(!expr||locks!=1)$fatal(1,"joined key did not cancel SW0 lock");
  gesture(6,18);if(on||expr)$fatal(1,"standalone SW0 still cycles EXPR to OFF");
  $display("PASS MATH_SLIM_KEYS: startup held, SW0 OFF/NUMBER/EXPR and lock preserved; page/help combos, staggered release and joined-long cancellation");
  sof;visible(0,0);visible(1,1);visible(2,0);visible(3,0);
  enabled=1;expression=1;sof;visible(0,1);
  if(osd.menu_character(0,6)!="1"||osd.menu_character(0,15)!="I")$fatal(1,"truthful NUM1 INDP status");
  // Events between two frame starts are captured; never alter visible rows midframe.
  context_ui=5;activity_ui=~activity_ui;ticks(3);visible(2,0);sof;visible(2,1);
  help_ui=1;activity_ui=~activity_ui;ticks(3);visible(3,0);sof;visible(3,1);
  for(f=0;f<3;f=f+1)begin sof;visible(2,1);visible(3,1);end
  sof;visible(2,0);visible(3,0);visible(0,1);visible(1,1);
  // With the switch still in HELP mode, any later activity wakes help again.
  activity_ui=~activity_ui;context_ui=0;ticks(3);sof;visible(3,1);visible(2,0);
  help_ui=0;activity_ui=~activity_ui;ticks(3);sof;visible(3,0);
  $display("PASS MATH_SLIM_VISIBILITY: frame-atomic pending event, default compact, AI-off hidden, key_context/help timeout and wake, %0d assertions",checks);
  // Capture actual paired output and independently check geometry/lane order.
  fd=$fopen("menu_pixels.hex","w");pixels=0;
  sof;
  for(yy=0;yy<180;yy=yy+1)begin
   for(xx=0;xx<640;xx=xx+2)begin
    @(negedge clk);de=1;valid=1;#1;
    expected0=ref_pixel(xx,yy);expected1=ref_pixel(xx+1,yy);
    if(painted!=={expected1,expected0})$fatal(1,"OSD pixels at%0d,%0d got%h expected%h",xx,yy,painted,{expected1,expected0});
    $fwrite(fd,"%06x\n%06x\n",painted[23:0],painted[47:24]);pixels=pixels+2;
   end
   @(negedge clk);de=0;valid=0;ticks(2);
  end
  $fclose(fd);if(pixels!=115200)$fatal(1,"capture count");
  $display("PASS MATH_SLIM_PIXELS: %0d actual pixels, 2x glyphs x12/y20 pitch12/row24, RGB pair ordering",pixels);
  $finish;
 end
 initial begin #10000000;$fatal(1,"UI timeout");end
endmodule

