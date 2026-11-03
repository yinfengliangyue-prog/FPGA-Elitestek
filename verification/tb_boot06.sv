`timescale 1ns/1ps
module boot_case06 #(parameter BOOT=3)(output reg done=0);
reg clk=0;always #5 clk=~clk;reg rn=0;reg [3:0] key=15;
wire [2:0] app;wire run,aux;wire [7:0] hi,lo;wire dn;
keys55 #(.BOOT_APP(BOOT),.DEBOUNCE_CYCLES(3)) dut(
 .clk(clk),.rst_n(rn),.key_n(key),.shape_result_valid(1'b0),.shape_locked(1'b0),.recognition_run(run),
 .frame_page(2'd0),.frame_speed(2'd1),.frame_playing(1'b0),.frame_recording(1'b1),.frame_selected(1'b1),.frame_count(8'd0),.frame_a(8'd0),.frame_b(8'd0),.frame_delta(16'd0),
 .wb_qr(12'd320),.wb_qg(12'd158),.wb_qb(12'd329),.app_mode(app),.aux_visible(aux),.analysis_high(hi),.analysis_low(lo),.denoise_enable(dn));
task tap(input [3:0] m);begin key=~m;repeat(12)@(negedge clk);key=15;repeat(12)@(negedge clk);end endtask
initial begin
 repeat(5)@(negedge clk);rn=1;repeat(20)@(negedge clk);
 if(app!=BOOT||run||!aux||hi!=(BOOT==3?11:6)||lo!=(BOOT==3?5:4)||!dn)$fatal(1,"boot page/OFF/search/defaults");
 if(BOOT==3)begin tap(8);if(!run)$fatal(1,"boot SW3 start");end tap(1);
 if(app!=(BOOT==3?0:1)||run)$fatal(1,"boot SW0 preserves four-app cycle and disables recognition");
 $display("PASS BOOT06 boot=%0d exact production boot page, recognition OFF, search ON, EXPR H11 L5 or FULL/BAL H6 L4 DN ON, SW3 start, SW0 exit",BOOT);done=1;
end
endmodule
module tb_boot06;
wire a,b;boot_case06 #(.BOOT(3)) ca(a);boot_case06 #(.BOOT(0)) cb(b);
initial begin wait(a&&b);$finish;end
initial begin #100000;$fatal(1,"boot timeout");end
endmodule
