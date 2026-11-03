`timescale 1ns/1ps
module tb_pairlock06;
reg clk=0;always #5 clk=~clk;reg rn=0,ct=0,boundary=0,rb=0,wb=0,start=0,commit=0,full_live=1;
reg [3:0] cmd=0;reg [2:0] app=1;wire allow,locked,ready;wire [7:0] wa,ba,bb;
control55 #(.FRAMES(8),.BASE(0),.STRIDE(4096),.MS_CYCLES(10)) dut(
 .clk(clk),.rst_n(rn),.command_toggle(ct),.command(cmd),.app_mode(app),.full_live(full_live),.full_capture(1'b0),.capture_tag(3'd0),
 .tag_a(),.tag_b(),.page_out(),.speed_out(),.playing_out(),.count_out(),.index_a_out(),.index_b_out(),.delta_out(),
 .boundary(boundary),.reader_busy(rb),.writer_busy(wb),.writer_begin(start),.commit(commit),.write_addr(),.allow_start(allow),.addr_a(),.addr_b(),.ui_data(),.ready(ready),.fetch_start(),.acknowledge(),
 .recording_out(),.selected_out(),.frame_locked_out(locked),.display_bank_a(ba),.display_bank_b(bb),.write_bank_out(wa),.review_out());
task tick(input integer n);repeat(n)@(negedge clk);endtask
task command(input [3:0] v);begin cmd=v;ct=~ct;tick(6);end endtask
task begin_write;begin if(!allow)$fatal(1,"writer unexpectedly blocked");start=1;wb=1;tick(1);start=0;end endtask
task finish_write;begin tick(3);wb=0;commit=1;tick(1);commit=0;tick(3);end endtask
task write_frame;begin begin_write;finish_write;end endtask
task fetch;begin boundary=1;tick(1);boundary=0;tick(2);end endtask
integer k,holdbank,oldcount,writes=0;
initial begin
tick(5);rn=1;tick(6);command(15);if(!locked||dut.pair_valid)$fatal(1,"empty lock must wait for committed frame");
begin_write;tick(4);if(dut.pair_valid||ready)$fatal(1,"inflight frame exposed");finish_write;tick(2);holdbank=dut.pair_bank;fetch;
if(!dut.pair_valid||ba!=0||bb!=0)$fatal(1,"first committed snapshot not paired");
for(k=1;k<8;k++)begin write_frame;fetch;if(ba!=holdbank||bb!=holdbank)$fatal(1,"recording changed paired lock");end
if(dut.count!=8||dut.recording)$fatal(1,"pair lock stopped recording");
for(k=0;k<20;k++)begin write_frame;fetch;if(wa==holdbank||ba!=holdbank||bb!=holdbank)$fatal(1,"pinned frame overwritten");end
command(15);if(locked||dut.pair_valid)$fatal(1,"unlock retains pin");write_frame;fetch;if(ba==holdbank||ba!=bb)$fatal(1,"unlock failed");
// Retained FULL hold plus LIVE pair hold may temporarily occupy all three
// live slots; dropping the pair lock must always restore forward progress.
app=0;full_live=0;tick(6);fetch;fetch;holdbank=dut.held_bank;
app=1;tick(6);write_frame;command(15);tick(2);fetch;
for(k=0;k<10;k++)if(allow)begin write_frame;writes++;fetch;end
if(allow)$fatal(1,"three live-slot pins were not protected");command(15);tick(3);if(!allow)$fatal(1,"pair unlock did not release allocator");write_frame;
command(15);command(11);tick(3);if(locked||dut.pair_valid)$fatal(1,"history page retains live pin");
command(10);command(15);app=3;tick(6);if(locked||dut.pair_valid)$fatal(1,"task exit retains pair pin");
app=1;tick(6);command(15);command(9);tick(5);if(locked||dut.pair_valid||dut.count!=0||!dut.recording)$fatal(1,"NEW TAKE did not clear pair lock");
command(15);rn=0;tick(3);if(locked||dut.pair_valid)$fatal(1,"reset retains pin");
$display("PASS PAIRLOCK06 empty/inflight publish fence, same committed bank A/B, uninterrupted8-frame take, triple-live pin protection, combined FULL/pair holds safely stall then resume, page/app/new-take/reset release");$finish;
end
initial begin #1000000;$fatal(1,"pair lock timeout");end
endmodule
