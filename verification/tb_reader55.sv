`timescale 1ns/1ps
module tb_reader55;
 reg clk=0,vc=0;always #5 clk=~clk;always #7 vc=~vc;
 reg rst=0,start=0,abort=0,fr=0,pop_on=0,ready_on=1;
 wire busy,empty;wire [127:0] head;wire [31:0] ar;wire [7:0] len;wire av,rr,fault;
 reg [127:0] data=0;reg rv=0,rl=0;integer left=0;bit tx=0;
 reader55 #(.W(64),.H(64),.FIFO_DEPTH(32),.BURST(15)) dut(
 .clk(clk),.rst_n(rst),.start(start),.abort(abort),.swap_sides(1'b0),.fullscreen(1'b0),.selected_b(1'b0),.addr_a(0),.addr_b(8192),.busy(busy),
 .video_clk(vc),.fifo_reset(fr),.pop(pop_on&&!empty),.empty(empty),.head(head),.fault(fault),.araddr(ar),.arlen(len),.arvalid(av),.arready(ready_on&&!tx),.rdata(data),.rresp(2'd0),.rvalid(rv),.rlast(rl),.rready(rr));
 integer pairs=0,words=0,completed_bursts=0;reg [31:0] held_ar;reg [7:0] held_len;
 always @(negedge clk)begin
  if(!rst)begin rv=0;rl=0;end
  else begin
   if(!rv&&tx)begin rv=1;rl=left==1;data={4{32'h12345678}};end

  end
 end
 always @(posedge clk)if(rst)begin
  if(av&&ready_on&&!tx)begin tx=1;left=int'(len)+1;end
  if(rv&&rr)begin left--;words++;rv<=0;if(rl)begin tx=0;completed_bursts++;end end


 end
 always @(posedge vc)if(rst&&pop_on&&!empty)pairs++;
 task launch;begin @(negedge clk);start=1;@(negedge clk);start=0;end endtask
 task cancel;begin @(negedge clk);abort=1;@(negedge clk);abort=0;end endtask
 integer i;
 initial begin
 repeat(8)@(negedge clk);rst=1;repeat(12)@(negedge clk);launch;
 repeat(1000)@(negedge clk);
 if(!busy)$fatal(1,"fixture did not stall both readers without pops");
 cancel;repeat(50)@(negedge clk);
 if(busy)$fatal(1,"cancel failed to release reader, or baseline hang not reproduced");
 $display("PASS READER55_STOPPED_CONSUMER cancellation releases stalled FIFO");
 // Offered AR must remain stable through cancellation until READY accepts it.
 @(negedge vc);fr=1;repeat(6)@(negedge vc);fr=0;
 ready_on=0;launch;wait(av);held_ar=ar;held_len=len;cancel;
 repeat(30)begin @(negedge clk);if(!av||ar!==held_ar||len!==held_len)$fatal(1,"cancel broke AXI ARVALID stall");end
 ready_on=1;$display("TRACE offered cancel state=%0d",dut.state);wait(tx);$display("TRACE AR accepted");wait(!busy);$display("TRACE cancel drained");if(left!=0)$fatal(1,"cancel did not drain final RLAST");
 // Accept a fresh frame, reset only its video queue, consume all pixels.
 @(negedge vc);fr=1;repeat(6)@(negedge vc);fr=0;pop_on=1;pairs=0;words=0;
 launch;$display("TRACE recovery launched");wait(!busy);$display("TRACE recovery finished");repeat(80)@(negedge vc);
 if(pairs!=512||words!=512||!empty||fault)$fatal(1,"recovery count pairs=%0d words=%0d empty=%b fault=%b",pairs,words,empty,fault);
 $display("PASS READER55_ABORT AXI address stall held, accepted burst drained through RLAST, next complete frame 512 AXI32 words recovered (2048 thumbnail pixels)");$finish;
 end
 initial begin #3000000;$fatal(1,"timeout state=%0d cancel=%b tx=%b left=%0d pairs=%0d words=%0d used=%0d empty=%b rv=%b rr=%b",dut.state,dut.cancel_pending,tx,left,pairs,words,dut.usedw,empty,rv,rr);end
endmodule
