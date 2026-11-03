`timescale 1ns/1ps
module tb_writer52;
reg ac=0,vc=0;always #5 ac=~ac;always #6.734 vc=~vc;
reg rst=0,start=0,enable=1,frst=1,en=0;reg [127:0] data=0;
wire busy,begin_frame,fault,commit,full;wire [31:0] awaddr;wire [7:0] awlen;
wire awvalid,wvalid,wlast,bready;wire [127:0] wdata;wire [15:0] strb;
reg awready=0,wready=0,bvalid=0;reg [1:0] bresp=0;
replay_writer52 #(.WR_FIFO_DEPTH(512)) dut(
 .axi_clk(ac),.rst_n(rst),.wr_start(start),.allow_start(enable),.busy(busy),.begin_frame(begin_frame),.fault(fault),
 .start_addr(32'h1ff0),.total_burst_len(25'd300),.bank_sw_ack(1'b0),.bank_sw(commit),.test_cnt(),
 .wr_fifo_rst_p(frst),.wr_fifo_wrclk(vc),.wr_fifo_wren(en),.wr_fifo_wrfull(full),.wr_fifo_wrdata(data),
 .awid(),.awaddr(awaddr),.awlen(awlen),.awsize(),.awburst(),.awlock(),.awvalid(awvalid),
 .awcobuf(),.awapcmd(),.awallstrb(),.awqos(),.awcache(),.awprot(),.awready(awready),
 .wdata(wdata),.wstrb(strb),.wlast(wlast),.wvalid(wvalid),.wready(wready),
 .bid(6'd0),.bvalid(bvalid),.bresp(bresp),.bready(bready),.addr_width_test(),.test_BURST_LEN());
integer frame_id=0,transactions=0,words=0,left=0,bdelay=0,commits=0;bit active=0,inject=0;
always @(negedge ac)begin
 awready=!active&&!bvalid&&!bdelay&&$urandom_range(0,3)!=0;wready=$urandom_range(0,2)!=0;
 if(bdelay)begin bdelay--;if(!bdelay)begin bvalid=1;bresp=inject?2:0;inject=0;end end
end
always @(posedge ac)if(rst)begin
 if(awvalid&&awready)begin
  if(awaddr[11:0]+16*(int'(awlen)+1)>4096)$fatal(1,"4k boundary");
  active=1;left=int'(awlen)+1;transactions++;
 end
 if(wvalid&&wready)begin
  if(!active || wlast!=(left==1) || strb!=16'hffff)$fatal(1,"write protocol");
  if(wdata!=={4{32'(frame_id*1000+words)}})$fatal(1,"FIFO data sequence");
  words++;left--;
  if(wlast)begin active=0;bdelay=12;inject=frame_id==2;end
 end
 if(bvalid&&bready)bvalid<=0;
 if(commit)begin
  if(frame_id==2 || words!=300 || active || bdelay || bvalid)$fatal(1,"error or early publish");
  commits++;
 end
end
task source(input integer f);integer i;begin
 frame_id=f;words=0;frst=1;start=0;en=0;repeat(8)@(negedge vc);
 frst=0;start=1;repeat(12)@(negedge vc);
 for(i=0;i<300;i++)begin data={4{32'(f*1000+i)}};en=1;@(negedge vc);start=0;end
 en=0;repeat(1200)@(negedge vc);
 if(busy)$fatal(1,"writer stuck");
end endtask
initial begin
 repeat(10)@(negedge vc);rst=1;
 source(1);if(commits!=1 || fault)$fatal(1,"good write");
 source(2);if(commits!=1 || !fault)$fatal(1,"bad B response published");
 source(3);if(commits!=2)$fatal(1,"writer did not recover");
 enable=0;source(4);if(commits!=2)$fatal(1,"disallowed capture published");
 enable=1;source(5);if(commits!=3)$fatal(1,"capture after skipped frame");
 $display("PASS WRITER52 random AW/W waits, 4k splits, final B publish, SLVERR suppression, recovery, skipped capture");$finish;
end
initial begin #1000000;$fatal(1,"timeout");end
endmodule
