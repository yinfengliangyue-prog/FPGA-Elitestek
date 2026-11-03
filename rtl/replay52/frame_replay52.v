module frame_replay52 #(
 parameter W=1920,H=1080,HT=1100,VT=1125,HB=96,VB=41,HS=22,VS=5,
 parameter FRAMES=120,BASE=32'h00c00000,STRIDE=32'h001fb000,FIFO_DEPTH=1024,MS_CYCLES=100000
)(
 input wire video_clk,video_rst_n,axi_clk,axi_rst_n,
 input wire [47:0] rgb_in,input wire de_in,hs_in,vs_in,
 input wire command_toggle,input wire [3:0] command,
 // Video-domain frame-stable configuration; connect shared manual controls on integration.
 input wire [7:0] analysis_high,analysis_low,
 output wire recording_out,selected_out,review_active,
 output wire [47:0] rgb_out,output wire de_out,hs_out,vs_out,held_b,fault,
 output wire [31:0] awaddr,araddr,output wire [7:0] awlen,arlen,
 output wire awvalid,wvalid,wlast,bready,arvalid,rready,
 output wire [127:0] wdata,output wire [15:0] wstrb,
 input wire awready,wready,bvalid,arready,rvalid,rlast,
 input wire [1:0] bresp,rresp,input wire [127:0] rdata
);
 localparam WORDS=W*H/16;
 wire [15:0] accepted_strength,edges;wire ed,ev,eh,es;
 // Detection is fed by untouched 42 RGB, independently of white balance.
 canny_stream_2ppc #(.IMG_W(W),.IMG_H(H),.H_TOTAL_BEATS(HT),.ORIGINAL_ENABLE(0)) core(
  .clk(video_clk),.rst_n(video_rst_n),.rgb_x2_in(rgb_in),.de_in(de_in),.valid_in(de_in),
  .hsync_in(hs_in),.vsync_in(vs_in),.threshold_in(analysis_high),.threshold_low_in(analysis_low),
  .exposure_level_in(2'd0),.noise_in(4'b1000),.edge_x2_out(edges),.gray_x2_out(accepted_strength),
  .rgb_x2_orig_out(),.de_out(ed),.valid_out(ev),.hsync_out(eh),.vsync_out(es),.nms_x2_out(),
  .active_high(),.active_low(),.active_exposure(),.active_noise());
 wire [47:0] wb;wire wd,wh,wv;
 replay_awb52 whitebalance(video_clk,video_rst_n,rgb_in,de_in,hs_in,vs_in,wb,wd,wh,wv,,,);
 wire [15:0] balanced;wire bd,bh,bv;wire [1:0] red;
 edge_balanced_render_2ppc #(.W(W),.H(H),.HT(HT),.CFG_ENABLE(0)) render49(
  video_clk,video_rst_n,accepted_strength,ed,eh,es,19'd0,balanced,,,bd,bh,bv,);
 canny_delay #(.WIDTH(2),.DEPTH(4*HT+19)) red_alignment(
  video_clk,video_rst_n,{|edges[15:8],|edges[7:0]},red);
 wire pack_reset,pack_start,pack_en,write_full,commit,writer_busy,writer_begin,writer_fault,pairing_fault;
 wire [127:0] pack_data;
 replay_pack52 #(.W(W),.H(H)) packer(video_clk,video_rst_n,wb,wd,wv,balanced,red,bd,bv,
  pack_reset,pack_start,pack_en,pack_data,pairing_fault);
 wire [31:0] write_addr,addr_a,addr_b;wire allow_start,reader_busy,pool_ready,accepted,ack;
 wire [95:0] ui_data;
 wire review_axi;(* async_reg="true" *)reg [1:0] review_sync;
 always @(posedge video_clk)begin
  if(!video_rst_n)review_sync<=0;else review_sync<={review_sync[0],review_axi};
 end
 assign review_active=review_sync[1];
 wire [7:0] display_bank_a,display_bank_b,write_bank;
 wire frame_toggle,read_fifo_reset,empty,pop,reader_fault,underflow;
 wire [127:0] head;
 (* async_reg="true" *)reg [1:0] request_sync;
 reg request_seen;
 wire boundary=request_sync[1]!=request_seen;
 always @(posedge axi_clk)begin
  if(!axi_rst_n)begin request_sync<=0;request_seen<=0;end
  else begin request_sync<={request_sync[0],frame_toggle};if(boundary)request_seen<=request_sync[1];end
 end
 replay_control52 #(.FRAMES(FRAMES),.BASE(BASE),.STRIDE(STRIDE),.MS_CYCLES(MS_CYCLES)) control(
  .clk(axi_clk),.rst_n(axi_rst_n),.command_toggle(command_toggle),.command(command),
  .boundary(boundary),.reader_busy(reader_busy),.writer_busy(writer_busy),.writer_begin(writer_begin),.commit(commit),
  .write_addr(write_addr),.allow_start(allow_start),.addr_a(addr_a),.addr_b(addr_b),.ui_data(ui_data),
  .ready(pool_ready),.fetch_start(accepted),.acknowledge(ack),.recording_out(recording_out),.selected_out(selected_out),
  .display_bank_a(display_bank_a),.display_bank_b(display_bank_b),.write_bank_out(write_bank),.review_out(review_axi));
 replay_writer52 #(.AXI_DATA_WIDTH(128),.AXI_ADDR_WIDTH(32),.WR_FIFO_DEPTH(FIFO_DEPTH),.BURST_LEN(127)) writer(
  .axi_clk(axi_clk),.rst_n(axi_rst_n),.wr_start(pack_start),.allow_start(allow_start),
  .busy(writer_busy),.begin_frame(writer_begin),.fault(writer_fault),.start_addr(write_addr),
  .total_burst_len(25'(WORDS)),.bank_sw_ack(1'b0),.bank_sw(commit),.test_cnt(),
  .wr_fifo_rst_p(pack_reset),.wr_fifo_wrclk(video_clk),.wr_fifo_wren(pack_en),
  .wr_fifo_wrfull(write_full),.wr_fifo_wrdata(pack_data),
  .awid(),.awaddr(awaddr),.awlen(awlen),.awsize(),.awburst(),.awlock(),.awvalid(awvalid),
  .awcobuf(),.awapcmd(),.awallstrb(),.awqos(),.awcache(),.awprot(),.awready(awready),
  .wdata(wdata),.wstrb(wstrb),.wlast(wlast),.wvalid(wvalid),.wready(wready),
  .bid(6'd0),.bvalid(bvalid),.bresp(bresp),.bready(bready),.addr_width_test(),.test_BURST_LEN());
 compare_reader23 #(.W(W),.H(H),.FIFO_DEPTH(FIFO_DEPTH)) reader(
  .clk(axi_clk),.rst_n(axi_rst_n),.start(accepted),.swap_sides(1'b0),.addr_a(addr_a),.addr_b(addr_b),.busy(reader_busy),
  .video_clk(video_clk),.fifo_reset(read_fifo_reset),.pop(pop),.empty(empty),.head(head),.fault(reader_fault),
  .araddr(araddr),.arlen(arlen),.arvalid(arvalid),.arready(arready),
  .rdata(rdata),.rresp(rresp),.rvalid(rvalid),.rlast(rlast),.rready(rready));
 (* async_reg="true" *)reg [1:0] ack_sync,ready_sync,error_sync;
 always @(posedge video_clk)begin
  if(!video_rst_n)begin ack_sync<=0;ready_sync<=0;error_sync<=0;end
  else begin ack_sync<={ack_sync[0],ack};ready_sync<={ready_sync[0],pool_ready};error_sync<={error_sync[0],reader_fault|writer_fault};end
 end
 replay_raster52 #(.W(W),.H(H),.HT(HT),.VT(VT),.HB(HB),.VB(VB),.HS(HS),.VS(VS)) display(
  .clk(video_clk),.rst_n(video_rst_n),.ready(ready_sync[1]),.ack_toggle(ack_sync[1]),.ui_data(ui_data),
  .frame_toggle(frame_toggle),.fifo_reset(read_fifo_reset),.empty(empty),.head(head),.pop(pop),
  .rgb(rgb_out),.de(de_out),.hs(hs_out),.vs(vs_out),.underflow(underflow),.analysis_high(analysis_high),.analysis_low(analysis_low));
 assign held_b=!recording_out;assign fault=underflow|error_sync[1]|pairing_fault;
 // synthesis translate_off
 initial if(WORDS*16>STRIDE)$fatal(1,"Frame larger than reserved stride");
 // synthesis translate_on
endmodule
