`timescale 1ns/1ps
module tb_menuhold06;
reg clk=0;always #5 clk=~clk;reg rn=0;reg [3:0] key=15;reg [1:0] page=0;
wire [2:0] app,ma;wire opened,edit,confirm,run,dn,toggle;wire [4:0] cursor,item;wire [3:0] command;wire [7:0] hi,lo;
keys55 #(.DEBOUNCE_CYCLES(3),.HOLD_CYCLES(40),.REPEAT_CYCLES(10)) dut(
 .clk(clk),.rst_n(rn),.key_n(key),.shape_result_valid(1'b0),.shape_locked(1'b0),.recognition_run(run),
 .frame_page(page),.frame_speed(2'd1),.frame_playing(1'b0),.frame_recording(1'b1),.frame_selected(1'b1),.frame_count(8'd80),.frame_a(8'd1),.frame_b(8'd80),.frame_delta(16'd0),.wb_qr(12'd320),.wb_qg(12'd158),.wb_qb(12'd329),
 .app_mode(app),.mode_a(ma),.settings_open(opened),.editing(edit),.confirm_reset(confirm),.menu_cursor(cursor),.selected_item(item),.analysis_high(hi),.analysis_low(lo),.denoise_enable(dn),.replay_command_toggle(toggle),.replay_command(command));
reg seen=0;integer commands=0,locks=0;
always @(posedge clk)if(rn&&toggle!=seen)begin seen<=toggle;commands++;if(command==15)locks++;end
task ticks(input integer n);repeat(n)@(negedge clk);endtask
task press(input [3:0] mask,input integer n);begin key=~mask;ticks(n);key=15;ticks(14);end endtask
task tap(input integer k);press(4'(1<<k),12);endtask
task seek(input integer id);integer j;begin while(cursor>0)tap(2);j=0;while(item!=id&&j<20)begin tap(3);j++;end if(item!=id)$fatal(1,"missing item %0d",id);end endtask
integer oldcursor,oldcmd,oldh,oldl,oldlocks,j;
task navigation;begin
if(!opened)tap(1);if(edit||confirm)$fatal(1,"navigation state");oldh=hi;oldl=lo;oldcmd=commands;
press(8,95);if(cursor<4)$fatal(1,"held DOWN did not repeat");oldcursor=cursor;ticks(30);if(cursor!=oldcursor)$fatal(1,"release generated an extra navigation");
press(8,300);oldcursor=cursor;press(8,85);if(cursor!=oldcursor||edit||confirm)$fatal(1,"bottom clamp or accidental action");
press(4,300);if(cursor!=0)$fatal(1,"top clamp");
if(hi!=oldh||lo!=oldl||commands!=oldcmd||run)$fatal(1,"navigation mutated a setting or command");
tap(3);tap(3);oldcursor=cursor;key=7;ticks(95);if(cursor<=oldcursor)$fatal(1,"no repeat before chord");key=3;ticks(16);key=7;ticks(16);key=15;ticks(20);if(cursor!=oldcursor||commands!=oldcmd)$fatal(1,"chord did not rollback navigation");tap(1);
end endtask
initial begin
ticks(5);rn=1;ticks(20);navigation;
tap(0);if(app!=1)$fatal(1,"FRAME");tap(1);seek(22);tap(3);if(item!=28)$fatal(1,"LOCK row not immediately after NEW TAKE");
oldlocks=locks;press(1,150);if(locks!=oldlocks+1||edit||confirm)$fatal(1,"LOCK action repeats or enters edit");
seek(22);tap(0);if(!confirm)$fatal(1,"confirm");oldcursor=cursor;oldcmd=commands;press(8,160);press(4,160);if(!confirm||cursor!=oldcursor||commands!=oldcmd)$fatal(1,"confirmation repeated");tap(1);tap(1);
navigation;page=1;ticks(8);navigation;page=2;ticks(8);navigation;page=0;ticks(8);
tap(0);if(app!=2)$fatal(1,"SHAPE");navigation;tap(0);if(app!=3)$fatal(1,"EXPR");navigation;
if(hi!=10||lo!=5||!dn||run)$fatal(1,"EXPR/Canny defaults changed");
$display("PASS MENUHOLD06 all FULL/LIVE/REPLAY/COMPARE/SHAPE/EXPR menus: held up/down repeat, clamped ends, no release duplicate, no accidental execution/settings change, late chord rollback; LOCK A+B below NEW TAKE single direct action; confirmation does not repeat");$finish;
end
initial begin #3000000;$fatal(1,"menu hold timeout");end
endmodule
