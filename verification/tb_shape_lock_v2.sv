`timescale 1ns/1ps
module tb_shape_lock_v2;
reg clk=0;always #5 clk=~clk;reg rn=0,en=1,vs=0,request=0,ready=0;
reg [2:0] types=0;wire ack,locked,det;wire [2:0] visible;
shape_color_overlay #(.IMG_W(64),.IMG_H(64),.PANEL_SWAP_RB_ON_EDGE(0)) map(
.clk(clk),.rst_n(rn),.enable(en),.rgb_in(48'd0),.edge_bits(16'd0),.de(1'b0),.valid(1'b0),.hs(1'b0),.vs(vs),
.color_start(1'b0),.color_write(1'b0),.color_x(8'd0),.color_y(8'd0),.color_class(2'd0),.query_x(8'd0),.query_y(8'd0),.neighbor_class(),
.result_ack(ack),.pending_types(types),.rgb_out(),.de_out(),.valid_out(),.hs_out(),.vs_out());
final_shape_overlay #(.LOCK_SUPPORT(1),.IMG_W(64),.IMG_H(64)) dut(
.clk(clk),.rst_n(rn),.enable(en),.lock_request(request),.locked(locked),.rgb_in(48'h123456789abc),.de(1'b0),.valid(1'b0),.vs(vs),
.result_ready(ready),.pending_types(types),.result_ack(ack),.rgb_out(),.enabled_frame(),.detected_frame(det),.visible_types(visible));
integer publications=0;always @(posedge clk)if(rn&&ack)publications++;
task frame;begin @(negedge clk);vs=1;repeat(3)@(negedge clk);vs=0;repeat(3)@(negedge clk);end endtask
initial begin
repeat(4)@(negedge clk);rn=1;frame;
request=1;frame;if(locked)$fatal(1,"empty shape locked");request=0;
types=3;ready=1;frame;if(visible!=3||!det||publications!=1)$fatal(1,"publish result");
request=1;types=4;frame;if(!locked||visible!=3||publications!=1||map.published_types!=visible||map.front_bank!=1)$fatal(1,"text/map ack not atomic when lock");
repeat(5)frame;if(visible!=3||publications!=1||map.front_bank!=1||map.published_types!=visible)$fatal(1,"locked publication changed");
request=0;frame;if(locked||visible!=4||publications!=2||map.front_bank!=0||map.published_types!=visible)$fatal(1,"unlock doesn't resume");
en=0;frame;if(det||visible||locked)$fatal(1,"leave shape retains result");
ready=0;en=1;frame;if(det||visible)$fatal(1,"reentry stale result");
$display("PASS MENU_V2_SHAPE_LOCK real result/types and shared map ack held atomically; empty guard; unlock; task exit/reentry clears result");$finish;
end
endmodule
