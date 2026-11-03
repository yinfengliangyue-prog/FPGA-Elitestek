`timescale 1ns/1ps
module keys_case06(output reg done=0);
reg clk=0;always #5 clk=~clk;reg rn=0;reg [3:0] key=15;
wire [2:0] app,ma;wire opened,editing,run,aux,wb,dn;wire [7:0] hi,lo;wire [4:0] cursor,item;
keys55 #(.DEBOUNCE_CYCLES(3),.HOLD_CYCLES(40),.REPEAT_CYCLES(10)) dut(
 .clk(clk),.rst_n(rn),.key_n(key),.shape_result_valid(1'b0),.shape_locked(1'b0),.recognition_run(run),
 .frame_page(2'd0),.frame_speed(2'd1),.frame_playing(1'b0),.frame_recording(1'b1),.frame_selected(1'b1),.frame_count(8'd120),.frame_a(8'd1),.frame_b(8'd120),.frame_delta(16'd0),
 .wb_qr(12'd320),.wb_qg(12'd158),.wb_qb(12'd329),.app_mode(app),.settings_open(opened),.editing(editing),.menu_cursor(cursor),.selected_item(item),
 .aux_visible(aux),.awb_lock_request(wb),.analysis_high(hi),.analysis_low(lo),.denoise_enable(dn),.mode_a(ma));
task ticks(input integer n);repeat(n)@(negedge clk);endtask
task press(input [3:0] mask,input integer n);begin key=~mask;ticks(n);key=15;ticks(12);end endtask
task tap(input integer k);press(4'(1<<k),12);endtask
integer i;
initial begin
 ticks(5);rn=1;ticks(15);if(run||hi!=6||lo!=4||!dn||app!=0||opened)$fatal(1,"startup defaults");
 tap(2);tap(1);if(item!=8)$fatal(1,"H menu");tap(0);tap(3);if(hi!=7)$fatal(1,"H adjustment inactive");tap(0);tap(3);tap(0);tap(2);if(lo!=3)$fatal(1,"L adjustment inactive");tap(0);tap(3);tap(0);tap(2);if(dn)$fatal(1,"DN adjustment inactive");tap(1);
 tap(0);tap(0);tap(0);if(app!=3||run||!aux)$fatal(1,"four-app EXPR entry OFF/search");
 press(8,200);if(!run)$fatal(1,"EXPR SW3 capability or repeated toggle");
 for(i=1;i<16;i++)if(i!=1&&i!=2&&i!=4&&i!=8)begin press(4'(i),60);if(!run||app!=3||opened)$fatal(1,"chord changed recognition");end
 tap(2);if(aux||!run)$fatal(1,"AUX changes recognition state");tap(2);tap(3);if(run)$fatal(1,"EXPR stop");
 tap(1);repeat(4)tap(3);if(item!=16)$fatal(1,"EXPR RESULT order");tap(0);if(!run)$fatal(1,"EXPR RESULT start");tap(1);
 tap(0);if(app!=0||run||hi!=7||lo!=3||dn)$fatal(1,"page exit/default control persistence");
 $display("PASS KEYS06 real SW3 ON/OFF, startup/entry OFF, search preserved, no hold double-toggle, RESULT direct action, all chords cancelled, AUX independent, H/L/DN live controls");done=1;
end
endmodule
module tb_keys06;
wire done;keys_case06 dut(done);
initial begin wait(done);$finish;end
initial begin #5000000;$fatal(1,"keys timeout");end
endmodule
