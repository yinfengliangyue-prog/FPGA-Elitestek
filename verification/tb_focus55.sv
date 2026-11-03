`timescale 1ns/1ps
module tb_focus55;
reg clk=0;always #5 clk=~clk;reg rn=0;reg [3:0] key=15;
reg [1:0] page=0,speed=1;reg playing=0,recording=1,sel=1;
wire [2:0] app,ma,mb;wire opened,editing,confirm,aux,lockreq,wb,shape_en;
wire [7:0] high_value,low_value;
wire [4:0] cursor,item;wire toggle;wire [3:0] command;reg seen=0;
integer checks=0;reg guarded=0;reg [4:0] expected_item;
keys55 #(.DEBOUNCE_CYCLES(3),.HOLD_CYCLES(40),.REPEAT_CYCLES(10)) dut(
.clk(clk),.rst_n(rn),.key_n(key),.shape_result_valid(1'b0),.shape_locked(1'b0),
.frame_page(page),.frame_speed(speed),.frame_playing(playing),.frame_recording(recording),.frame_selected(sel),
.frame_count(8'd120),.frame_a(8'd1),.frame_b(8'd120),.frame_delta(16'd1990),.wb_qr(12'd320),.wb_qg(12'd158),.wb_qb(12'd329),
.replay_command_toggle(toggle),.replay_command(command),.mode_a(ma),.mode_b(mb),.app_mode(app),.settings_open(opened),.editing(editing),.confirm_reset(confirm),.menu_cursor(cursor),.selected_item(item),
.aux_visible(aux),.shape_lock_request(lockreq),.awb_lock_request(wb),.shape_enable(shape_en),.analysis_high(high_value),.analysis_low(low_value));
always @(posedge clk)if(rn&&toggle!=seen)begin
seen<=toggle;
case(command)
10:page<=0;11,8:begin page<=1;recording<=0;end 12:page<=2;
13:sel<=~sel;14:playing<=~playing;3:speed<=speed==2?0:speed+1;5:speed<=speed==0?2:speed-1;
endcase end
// Check every clock, including the cycle BEFORE cursor state catches up.
always @(posedge clk)if(rn&&guarded)begin
 if(!opened||!editing||item!==expected_item)$fatal(1,"FOCUS_LOST app=%0d page=%0d item=%0d expected=%0d cursor=%0d editing=%b",app,page,item,expected_item,cursor,editing);
 checks++;
end
task ticks(input integer n);repeat(n)@(negedge clk);endtask
task tap(input integer k);begin key=~(4'b1<<k);ticks(12);key=15;ticks(12);end endtask
task edit_item(input [4:0] target);integer tries;begin
 guarded=0;if(editing)tap(0);while(cursor>0)tap(2);
 tries=0;while(item!=target&&tries<20)begin tap(3);tries++;end
 if(item!=target)$fatal(1,"setting missing %0d",target);
 tap(0);if(!editing)$fatal(1,"setting did not enter edit %0d",target);
 expected_item=target;guarded=1;
end endtask
task done;begin guarded=0;tap(0);if(editing)$fatal(1,"SW0 did not finish edit");end endtask
function integer ordered(input integer i);begin case(i%5)0:ordered=0;1:ordered=2;2:ordered=4;3:ordered=1;default:ordered=3;endcase end endfunction
integer j;reg old_aux;
initial begin
ticks(5);rn=1;ticks(15);
if(!$test$plusargs("FRAME_ONLY"))begin
tap(1);edit_item(1);
for(j=0;j<10;j++)begin tap(3);if(ma!=ordered(j+1))$fatal(1,"FULL next style");end
for(j=0;j<10;j++)begin tap(2);if(ma!=ordered(4-j%5))$fatal(1,"FULL previous style");end
done;tap(1);tap(2);tap(1);if(item!=8||cursor!=0)$fatal(1,"reopen Canny must still put H first");tap(1);
end
tap(0);if(app!=1)$fatal(1,"FRAME entry");tap(1);if(item!=8)$fatal(1,"FRAME edge H priority");edit_item(3);
for(j=0;j<10;j++)begin tap(3);if(mb!=ordered(j+2))$fatal(1,"B next style");end
for(j=0;j<10;j++)begin tap(2);if(mb!=ordered((5-j%5)%5))$fatal(1,"B previous style");end
tap(2);if(mb!=0)$fatal(1,"set B WB");done;
edit_item(2);
for(j=0;j<10;j++)begin tap(3);if(ma!=ordered(j+1))$fatal(1,"A next style");end
for(j=0;j<10;j++)begin tap(2);if(ma!=ordered(4-j%5))$fatal(1,"A previous style");end
done;edit_item(17);
for(j=0;j<12;j++)begin tap(3);if(page!=(j+1)%3)$fatal(1,"PAGE next");end
for(j=0;j<12;j++)begin tap(2);if(page!=(2-j%3))$fatal(1,"PAGE previous");end
guarded=0;tap(1);if(opened||editing)$fatal(1,"SW1 must close directly while editing PAGE");
tap(1);if(item!=17||cursor!=0)$fatal(1,"reopen WB LIVE must start with PAGE");tap(1);
tap(2);if(page!=1||recording)$fatal(1,"FRAME shortcut changed");
tap(0);if(app!=2||!shape_en)$fatal(1,"SHAPE entry");tap(1);if(item!=8)$fatal(1,"SHAPE H priority");
edit_item(7);repeat(6)tap(3);done;edit_item(15);repeat(6)tap(3);done;tap(1);
old_aux=aux;tap(2);if(aux==old_aux||ma!=0||mb!=0||!shape_en)$fatal(1,"SHAPE shortcut or algorithm enable changed");
tap(3);if(lockreq)$fatal(1,"empty SHAPE locked");
if(checks<2000)$fatal(1,"insufficient focus coverage");
if(high_value!=6||low_value!=3)$fatal(1,"style/PAGE edits accidentally changed GLOBAL H/L");
$display("PASS FOCUS55 %0d every-clock focus checks; bidirectional 5-style loops FULL/A/B, 3-page loops, no transient wrong setting, editing retained, SW0 done/SW1 direct close, reopen priority, SHAPE default H6/L3 preserved, SHAPE WB/aux and original shortcuts unchanged",checks);$finish;
end
initial begin #5000000;$fatal(1,"focus timeout");end
endmodule
