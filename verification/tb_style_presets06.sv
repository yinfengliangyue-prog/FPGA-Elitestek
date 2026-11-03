`timescale 1ns/1ps
module tb_style_presets06;
reg clk=0;always #5 clk=~clk;reg rn=0;reg [3:0] key=15;
reg [1:0] page=0;reg selected=1;
wire [2:0] app,ma,mb,sa,sb;wire opened,editing,confirm,dn,run;wire [7:0] hi,lo;wire [4:0] cursor,item;
keys55 #(.DEBOUNCE_CYCLES(3),.HOLD_CYCLES(40),.REPEAT_CYCLES(10)) dut(
.clk(clk),.rst_n(rn),.key_n(key),.shape_result_valid(1'b0),.shape_locked(1'b0),.recognition_run(run),
.frame_page(page),.frame_speed(2'd1),.frame_playing(1'b0),.frame_recording(1'b1),.frame_selected(selected),.frame_count(8'd120),.frame_a(8'd1),.frame_b(8'd120),.frame_delta(16'd0),
.wb_qr(12'd320),.wb_qg(12'd158),.wb_qb(12'd329),.app_mode(app),.settings_open(opened),.editing(editing),.confirm_reset(confirm),.menu_cursor(cursor),.selected_item(item),
.analysis_high(hi),.analysis_low(lo),.denoise_enable(dn),.mode_a(ma),.mode_b(mb),.replay_style_a(sa),.replay_style_b(sb),
.replay_command_toggle(),.replay_command(),.threshold_a(),.threshold_b(),.low_a(),.low_b(),.selected_b(),.swap_sides(),.same_frame(),.fullscreen(),.shape_enable(),.number_enable(),.edit_low(),
.live_b(),.capture_a(),.capture_b(),.live_a(),.live_group(),.capture_group(),.awb_lock_request(),.menu_page(),.ai_min_strength(),.ai_min_select(),.osd_activity_toggle(),.osd_help_toggle(),.osd_context(),.aux_visible(),.shape_lock_request(),.osd_detail(),.fps_show());
reg de=0,vs=0,hs=0;wire [7:0] active_h,active_l;integer pixels=0,checks=0;
canny_stream_2ppc #(.IMG_W(64),.IMG_H(64),.H_TOTAL_BEATS(48),.ORIGINAL_ENABLE(0)) actual_canny(
.clk(clk),.rst_n(rn),.rgb_x2_in(48'h4080a06090b0),.de_in(de),.valid_in(de),.hsync_in(hs),.vsync_in(vs),
.threshold_in(hi),.threshold_low_in(lo),.exposure_level_in(2'd0),.noise_in({dn,3'd0}),.active_high(active_h),.active_low(active_l),.active_exposure(),.active_noise(),.edge_x2_out(),.gray_x2_out(),.nms_x2_out(),.rgb_x2_orig_out(),.de_out(),.valid_out(),.hsync_out(),.vsync_out());
always @(posedge clk)if(rn)begin if(lo<1||lo>hi)$fatal(1,"L/H invariant");checks++;if(de)pixels+=2;end
task ticks(input integer n);repeat(n)@(negedge clk);endtask
task press(input [3:0] m,input integer n);begin key=~m;ticks(n);key=15;ticks(14);end endtask
task tap(input integer k);press(4'(1<<k),12);endtask
task seek(input [4:0] id);integer tries;begin
if(!opened)tap(1);if(editing)tap(0);while(cursor>0)tap(2);
tries=0;while(item!=id&&tries<20)begin tap(3);tries++;end
if(item!=id)$fatal(1,"menu item missing %0d",id);
end endtask
task edit(input [4:0] id);begin seek(id);tap(0);if(!editing)$fatal(1,"not editing");end endtask
task close;begin if(opened)tap(1);end endtask
task restore;begin seek(14);tap(0);if(!confirm)$fatal(1,"restore did not confirm");tap(0);if(confirm||!dn)$fatal(1,"restore DN/confirm");close;end endtask
task expect_threshold(input integer h,l);begin if(hi!=h||lo!=l)$fatal(1,"threshold mismatch app=%0d style=%0d/%0d expected=%0d/%0d got=%0d/%0d",app,ma,mb,h,l,hi,lo);end endtask
task check_canny(input integer h,l);integer x,y;begin
for(y=0;y<72;y++)for(x=0;x<48;x++)begin @(negedge clk);vs=y<2;hs=x<2;de=y>=4&&y<68&&x>=6&&x<38;end
@(negedge clk);de=0;vs=0;ticks(48*12);
if(active_h!=h||active_l!=l)$fatal(1,"preset does not reach production Canny active config %0d/%0d",active_h,active_l);
end endtask
integer oldh;
initial begin
ticks(5);rn=1;ticks(20);if(app!=0||ma!=0||!dn)$fatal(1,"boot");expect_threshold(6,4);
tap(2);if(ma!=2)$fatal(1,"ORIG -> BAL");expect_threshold(6,4);check_canny(6,4);
edit(8);tap(3);tap(0);edit(9);tap(2);close;expect_threshold(7,3);
tap(2);if(ma!=4)$fatal(1,"BAL -> CLEAN");expect_threshold(9,4);check_canny(9,4);
edit(8);tap(3);close;expect_threshold(10,4);edit(10);tap(3);close;if(dn)$fatal(1,"DN toggle");restore;expect_threshold(9,4);
tap(2);if(ma!=1)$fatal(1,"CLEAN -> RED");expect_threshold(8,4);check_canny(8,4);
edit(9);tap(3);close;expect_threshold(8,5);
tap(2);if(ma!=3)$fatal(1,"RED -> GREY");tap(2);if(ma!=0)$fatal(1,"GREY -> ORIG");tap(2);if(ma!=2)$fatal(1,"ORIG -> BAL second");expect_threshold(7,3);
restore;expect_threshold(6,4);
edit(8);oldh=hi;key=7;ticks(85);key=3;ticks(15);key=15;ticks(20);expect_threshold(oldh,4);close;
tap(2);tap(2);expect_threshold(8,5);restore;expect_threshold(8,4);
tap(2);tap(2);tap(2);if(ma!=2)$fatal(1,"BAL return");expect_threshold(6,4);
edit(8);press(4,220);expect_threshold(1,1);close;tap(2);tap(2);tap(2);tap(2);tap(2);expect_threshold(1,1);restore;expect_threshold(6,4);
tap(0);if(app!=1)$fatal(1,"FRAME");edit(3);tap(3);close;if(sb!=4)$fatal(1,"FRAME B order");expect_threshold(9,4);
page=1;ticks(8);edit(3);tap(3);close;if(sb!=2)$fatal(1,"history B order");expect_threshold(9,4);
tap(0);if(app!=2)$fatal(1,"SHAPE");expect_threshold(6,3);edit(8);tap(3);close;
tap(0);if(app!=3||run)$fatal(1,"EXPR");expect_threshold(11,5);edit(8);tap(3);close;expect_threshold(12,5);restore;expect_threshold(11,5);tap(0);tap(0);tap(0);if(app!=2)$fatal(1,"SHAPE return");expect_threshold(7,3);restore;expect_threshold(6,3);
rn=0;ticks(5);rn=1;ticks(20);expect_threshold(6,4);tap(2);tap(2);expect_threshold(9,4);
if(pixels<12000||checks<15000)$fatal(1,"insufficient real Canny/key coverage");
$display("PASS STYLE_PRESETS06 %0d clocks and %0d Canny pixels: ORIG/BAL/CLEAN/RED/GREY order; live active6/4,9/4,8/4; independent manual banks, restore and power reset; L<=H, long-repeat/chord rollback; FRAME LIVE versus immutable history; SHAPE6/3 and EXPR independent11/5 and CLEAN9/4, actual H/L edit and restore",checks,pixels);$finish;
end
initial begin #5000000;$fatal(1,"style presets timeout");end
endmodule
