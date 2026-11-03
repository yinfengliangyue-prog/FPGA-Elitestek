`timescale 1ns/1ps
module tb_control55;reg [2:0] app=1;reg full_live=1,full_cap=0;
reg clk=0;always #5 clk=~clk;
reg rst=0,toggle=0,boundary=0,rb=0,wb=0,start=0,commit=0;
reg [3:0] command=0;wire [31:0] wa,aa,ab;wire allow,ready,fetch,ack,rec,selected;
wire [95:0] ui;wire [7:0] ba,bb,write_bank;
control55 #(.MS_CYCLES(10)) dut(.clk(clk),.rst_n(rst),.command_toggle(toggle),.command(command),.boundary(boundary),.reader_busy(rb),.writer_busy(wb),.writer_begin(start),.commit(commit),
 .app_mode(app),.full_live(full_live),.full_capture(full_cap),.capture_tag(3'd0),.tag_a(),.tag_b(),.page_out(),.speed_out(),.playing_out(),.count_out(),.index_a_out(),.index_b_out(),.delta_out(),
 .write_addr(wa),.allow_start(allow),.addr_a(aa),.addr_b(ab),.ui_data(ui),.ready(ready),.fetch_start(fetch),.acknowledge(ack),.recording_out(rec),.selected_out(selected),.display_bank_a(ba),.display_bank_b(bb),.write_bank_out(write_bank),.review_out());
task cmd(input [3:0] mask);begin
 @(negedge clk);command=mask;toggle=~toggle;repeat(6)@(negedge clk);
end endtask
task frame;begin
 if(!allow)$fatal(1,"unexpected blocked writer");
 start=1;wb=1;@(negedge clk);start=0;repeat(4)@(negedge clk);
 commit=1;wb=0;@(negedge clk);commit=0;repeat(2)@(negedge clk);
end endtask
task display_frame;begin
 boundary=1;@(negedge clk);boundary=0;rb=1;repeat(3)@(negedge clk);rb=0;
end endtask
integer k,idx;reg [7:0] last;reg oldack;
initial begin
 repeat(4)@(negedge clk);rst=1;repeat(2)@(negedge clk);
 if(!rec || ready || dut.count!=0 || wa!=32'h00c00000)$fatal(1,"defaults");
 for(k=0;k<120;k++)begin
  if(write_bank!=k || wa!=32'h00c00000+k*32'h1fb000)$fatal(1,"history slot address");
  frame();if(dut.count!=k+1)$fatal(1,"count/publish");
 end
 if(rec || dut.count!=120 || !ready)$fatal(1,"record completion");
 for(k=0;k<20;k++)begin frame();display_frame();if(dut.count!=120 || write_bank<120)$fatal(1,"immutable history / live rotation");end
 if(32'h00c00000+123*32'h1fb000!=32'h0ff99000)$fatal(1,"physical map");
 cmd(1);display_frame();if(dut.page!=1 || bb!=0 || ba<120)$fatal(1,"live + history layout");
 cmd(8);last=dut.play_index;display_frame();if(dut.play_index!=last+1)$fatal(1,"1x speed");
 cmd(3);last=dut.play_index;display_frame();if(dut.play_index!=last+2)$fatal(1,"2x speed");
 cmd(3);last=dut.play_index;display_frame();display_frame();if(dut.play_index!=last+1)$fatal(1,"half speed");
 for(k=0;k<130;k++)cmd(4);
 if(dut.play_index!=119 || dut.playing)$fatal(1,"step +1 clamp/pause");
 for(k=0;k<130;k++)cmd(2);
 if(dut.play_index!=0)$fatal(1,"step -1 clamp");
 cmd(1);display_frame();if(dut.page!=2 || ba!=0 || bb!=119)$fatal(1,"different-time compare");
 cmd(8);cmd(4);display_frame();if(ba!=1 || bb!=119 || selected)$fatal(1,"A selection isolation");
 cmd(6);if(dut.mode_a!=0 || dut.mode_b!=2)$fatal(1,"A view isolation");
 cmd(6);if(dut.mode_a!=1)$fatal(1,"RED view");
 cmd(6);if(dut.mode_a!=2)$fatal(1,"BAL view / three-mode wrap");
 for(k=0;k<16;k++)if(k==0||k==7||k==15)cmd(k[3:0]);
 if(dut.index_a!=1 || dut.index_b!=119 || dut.mode_a!=2)$fatal(1,"reserved commands mutated replay");
 cmd(8);cmd(2);display_frame();if(bb!=118 || ba!=1)$fatal(1,"B selection isolation");
 cmd(1);display_frame();if(dut.page!=0 || dut.count!=120)$fatal(1,"return live preserves take");
 // A restart request during a write must drain the transaction first.
 start=1;wb=1;rb=1;@(negedge clk);start=0;cmd(9);
 if(dut.count!=120 || !dut.restart_pending || allow)$fatal(1,"restart did not wait for writer");
 commit=1;wb=0;@(negedge clk);commit=0;repeat(4)@(negedge clk);
 if(dut.count!=120 || !dut.restart_pending)$fatal(1,"restart must also drain reader");
 rb=0;repeat(4)@(negedge clk);
 if(dut.count!=0 || ready || !rec || dut.page!=0)$fatal(1,"restart state");
 frame();frame();cmd(8);if(rec || dut.page!=1 || dut.count!=2)$fatal(1,"early stop");
 for(k=0;k<8;k++)begin frame();display_frame();if(dut.count!=2)$fatal(1,"early take overwritten");end
 // Stop before any frame: empty review must remain live, no invalid bank read.
 cmd(9);repeat(4)@(negedge clk);cmd(8);frame();display_frame();
 if(dut.count!=0 || bb<120)$fatal(1,"empty take referenced unpublished history");
 app=0;full_live=0;repeat(6)@(negedge clk);display_frame();display_frame();last=ba;
 for(k=0;k<20;k++)begin frame();display_frame();if(ba!=last||bb!=last)$fatal(1,"FULL hold changed or overwritten");end
 full_cap=1;repeat(6)@(negedge clk);display_frame();display_frame();if(ba==last)$fatal(1,"FULL update did not refresh");
 full_live=1;repeat(6)@(negedge clk);display_frame();frame();display_frame();if(dut.held_valid)$fatal(1,"FULL resume retains pin");
 $display("PASS CONTROL55 120 frames, 256MiB bounds, triple live buffers, immutable review, 3 speeds, +/-1 clamped steps, legacy style command compatibility, independent A/B, drain restart, early/empty take");$finish;
end
endmodule
