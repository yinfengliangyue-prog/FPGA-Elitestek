`timescale 1ns/1ps
module boot_case #(parameter DIGITS=0)(output reg done=0);
reg clk=0;always #5 clk=~clk;reg rn=0;reg [3:0] key=15;
wire [2:0] app;wire run,aux;wire [7:0] hi,lo;wire dn;
keys55 #(.DIGIT_ENABLE(DIGITS),.BOOT_APP(DIGITS?3:4),.DEBOUNCE_CYCLES(3)) dut(
 .clk(clk),.rst_n(rn),.key_n(key),.shape_result_valid(1'b0),.shape_locked(1'b0),.recognition_run(run),
 .frame_page(2'd0),.frame_speed(2'd1),.frame_playing(1'b0),.frame_recording(1'b1),.frame_selected(1'b1),.frame_count(8'd0),.frame_a(8'd0),.frame_b(8'd0),.frame_delta(16'd0),
 .wb_qr(12'd320),.wb_qg(12'd158),.wb_qb(12'd329),.app_mode(app),.aux_visible(aux),.analysis_high(hi),.analysis_low(lo),.denoise_enable(dn));
task tap(input [3:0] m);begin key=~m;repeat(12)@(negedge clk);key=15;repeat(12)@(negedge clk);end endtask
initial begin
 repeat(5)@(negedge clk);rn=1;repeat(20)@(negedge clk);
 if(app!=(DIGITS?3:4)||run||!aux||hi!=6||lo!=3||!dn)$fatal(1,"boot page/OFF/search/defaults");
 tap(8);if(!run)$fatal(1,"boot SW3 start");tap(1);
 if(app!=(DIGITS?4:0)||run)$fatal(1,"boot SW0 preserves five-app cycle and disables recognition");
 $display("PASS BOOT56 digits=%0d exact production boot page, recognition OFF, search ON, H6 L3 DN ON, SW3 start, SW0 exit",DIGITS);done=1;
end
endmodule
module tb_boot56;
wire a,b;boot_case #(.DIGITS(0)) ca(a);boot_case #(.DIGITS(1)) cb(b);
initial begin wait(a&&b);$finish;end
initial begin #100000;$fatal(1,"boot timeout");end
endmodule
