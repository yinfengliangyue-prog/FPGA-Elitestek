`timescale 1ns/1ps
module tb_keys55;
reg clk=0;always #5 clk=~clk;reg rn=0;reg [3:0] key=15;
reg [1:0] page=0,speed=1;reg playing=0,recording=1,sel=1;reg [7:0] count=120,ia=1,ib=120;
wire [2:0] app,ma,mb;wire recognition_run;wire opened,editing,confirm,aux,lockreq,wb;wire [7:0] hi,lo;wire [4:0] cursor,item;
wire toggle;wire [3:0] command;reg seen=0;integer commands=0,previouses=0,nexts=0;
keys55 #(.DEBOUNCE_CYCLES(3),.HOLD_CYCLES(40),.REPEAT_CYCLES(10)) dut(
.clk(clk),.rst_n(rn),.key_n(key),.shape_result_valid(1'b0),.shape_locked(1'b0),.recognition_run(recognition_run),
.frame_page(page),.frame_speed(speed),.frame_playing(playing),.frame_recording(recording),.frame_selected(sel),.frame_count(count),.frame_a(ia),.frame_b(ib),.frame_delta(16'd1990),
.wb_qr(12'd320),.wb_qg(12'd158),.wb_qb(12'd329),.replay_command_toggle(toggle),.replay_command(command),.replay_style_a(),.replay_style_b(),
.mode_a(ma),.mode_b(mb),.app_mode(app),.settings_open(opened),.editing(editing),.confirm_reset(confirm),.menu_cursor(cursor),.selected_item(item),
.aux_visible(aux),.shape_lock_request(lockreq),.awb_lock_request(wb),.analysis_high(hi),.analysis_low(lo));
always @(posedge clk)if(rn&&toggle!=seen)begin
seen<=toggle;commands++;
case(command)
10:page<=0;11,8:begin page<=1;recording<=0;end 12:page<=2;
13:sel<=~sel;14:playing<=~playing;3:speed<=speed==2?0:speed+1;5:speed<=speed==0?2:speed-1;
2:begin previouses++;playing<=0;end 4:begin nexts++;playing<=0;end
9:begin count<=0;recording<=1;page<=0;end
endcase end
task ticks(input integer n);repeat(n)@(negedge clk);endtask
task press(input [3:0] mask,input integer n);begin key=~mask;ticks(n);key=15;ticks(12);end endtask
task tap(input integer k);press(4'(1<<k),12);endtask
task cursor_to(input integer n);begin while(cursor<n)tap(3);while(cursor>n)tap(2);end endtask
integer i,oldcmd,oldprev;
initial begin
ticks(5);rn=1;ticks(15);
if(app!=0||hi!=6||lo!=4||ma!=0)$fatal(1,"power defaults");
tap(1);if(item!=1)$fatal(1,"WB context first display item");tap(1);tap(2);tap(1);
if(item!=8||cursor!=0)$fatal(1,"Canny menu must start with H");tap(3);if(item!=9)$fatal(1,"Canny L second");
tap(0);tap(2);if(lo!=3)$fatal(1,"L decrement");tap(1);
tap(0);if(app!=1)$fatal(1,"FRAME app");tap(1);if(item!=8)$fatal(1,"live edge H first");cursor_to(3);if(item!=17)$fatal(1,"LIVE PAGE item");
tap(0);tap(3);if(page!=1||!editing||item!=17)$fatal(1,"PAGE edit focus");tap(0);cursor_to(0);
tap(0);tap(3);if(!playing)$fatal(1,"play toggle");tap(1);
oldprev=previouses;press(4,120);if(previouses<=oldprev+1)$fatal(1,"single-key frame repeat");oldprev=previouses;ticks(20);if(previouses!=oldprev)$fatal(1,"release duplicate");
tap(1);cursor_to(2);if(item!=19)$fatal(1,"speed priority");tap(0);tap(3);if(speed!=2)$fatal(1,"2X speed");tap(0);
cursor_to(3);tap(0);tap(3);if(page!=2||!editing||item!=17)$fatal(1,"COMPARE page focus");tap(0);
cursor_to(1);tap(0);if(sel)$fatal(1,"editing FRAME A must select A");tap(3);tap(0);
cursor_to(6);if(item!=22)$fatal(1,"NEW TAKE menu");tap(0);if(!confirm)$fatal(1,"NEW TAKE needs confirmation");tap(1);if(confirm||!opened)$fatal(1,"cancel new take");tap(0);tap(0);if(!recording||page!=0)$fatal(1,"new take execute");tap(1);
oldcmd=commands;
for(i=1;i<16;i++)if(i!=1&&i!=2&&i!=4&&i!=8)begin press(4'(i),70);if(commands!=oldcmd||app!=1||opened)$fatal(1,"chord acted %b",i);end
press(1,200);if(app!=2)$fatal(1,"SW0 repeat");tap(3);if(lockreq)$fatal(1,"shape false lock");
tap(0);tap(3);if(lockreq||app!=3||!recognition_run)$fatal(1,"EXPR real toggle");tap(3);if(recognition_run)$fatal(1,"EXPR stop");
$display("PASS KEYS55 contextual top H/L, menu reopening at first priority item, page-edit isolation, complete52 playback/speed/compare/steps/new-take menu, +/-1 long repeat, all chords cancelled, shape empty guard and real EXPR toggle");$finish;
end
initial begin #5000000;$fatal(1,"keys timeout");end
endmodule
