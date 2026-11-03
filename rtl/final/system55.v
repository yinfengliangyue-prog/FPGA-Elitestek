
module system55 #(
 parameter UI_V2=1,W=1920,H=1080,HT=1066,VT=1122,HB=46,VB=22,HS=2,VS=2,
 parameter BASE=32'h00c00000,STRIDE=32'h001fb000,FIFO_DEPTH=512,FRAMES=120,MS_CYCLES=100000,
 parameter PANEL_SWAP_RB_ON_EDGE=1,WB_MIN_SAMPLES=256
)(
 input wire video_clk,video_rst_n,axi_clk,axi_rst_n,recognition_run,
 input wire [2:0] app_mode,input wire settings_open,editing,confirm_reset,input wire [4:0] menu_cursor,
 input wire aux_visible,shape_lock_request,osd_detail,fps_show,
 output wire shape_locked,shape_result_valid,
 input wire replay_command_toggle,input wire [3:0] replay_command,input wire [2:0] replay_style_a,replay_style_b,
 output wire [1:0] frame_page,frame_speed,output wire frame_playing,frame_recording,frame_selected,
 output wire [7:0] frame_count,frame_a,frame_b,output wire [15:0] frame_delta,
 output wire [11:0] wb_qr,wb_qg,wb_qb,
 input wire [47:0] rgb_in,
 input wire de_in,hs_in,vs_in,
 input wire [2:0] mode_a,mode_b,
 input wire [7:0] low_a,low_b,analysis_high,analysis_low,
 input wire shape_enable,number_enable,edit_low,fullscreen,denoise_enable,input wire [1:0] menu_page,
 input wire [9:0] fps_cam,fps_vid,input wire fps_valid,
 input wire [7:0] ai_min_strength,input wire ai_min_select,
 input wire osd_activity_toggle,osd_help_toggle,input wire [2:0] osd_context,
 input wire [7:0] threshold_a,threshold_b,
 input wire selected_b,swap_sides,live_b,capture_a,capture_b,same_frame,
 input wire live_a,live_group,capture_group,awb_lock_request,
 output wire [47:0] rgb_out,
 output wire de_out,hs_out,vs_out,
 output wire held_b,fault,
 output wire [31:0] awaddr,araddr,
 output wire [7:0] awlen,arlen,
 output wire awvalid,wvalid,wlast,bready,arvalid,rready,
 output wire [127:0] wdata,
 output wire [15:0] wstrb,
 input wire awready,wready,bvalid,arready,rvalid,rlast,
 input wire [1:0] bresp,rresp,
 input wire [127:0] rdata
);
 localparam WORDS=W*H/16; // quarter image pixels *32 bits /128
 wire [7:0] capture_high,capture_low;wire [3:0] capture_noise;
 reg [16:0] last_detect;
 wire detect_changed={capture_high,capture_low,capture_noise[3]}!=last_detect;
 always @(posedge video_clk)begin
 if(!video_rst_n)last_detect<={8'd6,8'd3,1'b1};
 else last_detect<={capture_high,capture_low,capture_noise[3]};end
 wire [47:0] orig;wire [15:0] edges,mag,accepted_gray;
 wire ed,ev,eh,es;
 canny_stream_2ppc #(.IMG_W(W),.IMG_H(H),.H_TOTAL_BEATS(HT),.ORIGINAL_ENABLE(0)) core(
 .clk(video_clk),.rst_n(video_rst_n),.rgb_x2_in(rgb_in),.de_in(de_in),.valid_in(de_in),.hsync_in(hs_in),.vsync_in(vs_in),
 .threshold_in(analysis_high),.threshold_low_in(analysis_low),.exposure_level_in(2'd0),.noise_in({denoise_enable,3'd0}),
 .active_high(capture_high),.active_low(capture_low),.active_exposure(),.active_noise(capture_noise),.edge_x2_out(edges),.gray_x2_out(accepted_gray),.nms_x2_out(mag),
 .rgb_x2_orig_out(orig),.de_out(ed),.valid_out(ev),.hsync_out(eh),.vsync_out(es));
 wire pack_reset,pack_start,pack_en,write_full,commit;
 wire [127:0] pack_data;
 wire [47:0] wb_rgb;wire [15:0] wb_mag,wb_accepted,wb_full_edges;wire wd,wh,wv,wb_locked,wb_rejected;
 // White-balance operates on the untouched RGB888 input, independently of Canny.
 wire [47:0] wb_full;wire wfd,wfh,wfv;
 final_wb55 #(.W(W),.H(H),.HT(HT),.MIN_SAMPLES(WB_MIN_SAMPLES)) whitebalance(
 .clk(video_clk),.rst_n(video_rst_n),.lock_request(awb_lock_request),.rgb_in({rgb_in[31:24],rgb_in[39:32],rgb_in[47:40],rgb_in[7:0],rgb_in[15:8],rgb_in[23:16]}),
 .de_in(de_in),.hs_in(hs_in),.vs_in(vs_in),.rgb_out(wb_full),.de_out(wfd),.hs_out(wfh),.vs_out(wfv),.locked(wb_locked),.rejected(wb_rejected),.gain_r(wb_qr),.gain_g(wb_qg),.gain_b(wb_qb));
 localparam CORE_DELAY=1+(HT+4)+1+(HT+5)+1+(HT+4)+2*(HT+5)+(HT+5);
 localparam COLOR_DELAY=CORE_DELAY-HT-8;
 function [13:0] pack554(input [23:0] p);pack554={p[23:19],p[15:11],p[7:4]};endfunction
 function [23:0] unpack554(input [13:0] p);unpack554={p[13:9],p[13:11],p[8:4],p[8:6],p[3:0],p[3:0]};endfunction
 wire [13:0] wb_delayed;
 canny_delay #(.WIDTH(14),.DEPTH(COLOR_DELAY)) color_alignment(video_clk,video_rst_n,pack554(wb_full[23:0]),wb_delayed);
 assign wb_rgb={2{unpack554(wb_delayed)}};
 assign wb_mag=mag;assign {wd,wh,wv}={ed,eh,es};
 wire [15:0] wb_edges;
 reg [7:0] min_frame;reg es_old;
 always @(posedge video_clk)begin
 if(!video_rst_n)begin min_frame<=0;es_old<=0;end
 else begin es_old<=es;if(es&&!es_old)min_frame<=ai_min_strength;end end
 wire [15:0] ai_edges={(edges[15:8]!=0&&accepted_gray[15:8]>=min_frame)?8'hff:8'h00,
                        (edges[7:0]!=0&&accepted_gray[7:0]>=min_frame)?8'hff:8'h00};
 assign wb_edges=ai_edges;assign wb_full_edges=edges;assign wb_accepted=accepted_gray;
 wire [2:0] capture_tag;
 wire [47:0] annotated;wire [1:0] annotations;wire rd,rh,rs;wire [15:0] rm,ra;
 // V2 always replays the captured original-resolution result. H/L are GLOBAL
 // acquisition controls, not a thumbnail reclassification/old-frame preview.
 wire defaults_tag=UI_V2?1'b1:capture_high==6&&capture_low==3;
 final_recognition #(.UI_V2(UI_V2),.W(W),.H(H),.HT(HT)) recognition(
 .clk(video_clk),.rst_n(video_rst_n&&(!UI_V2||!detect_changed)),.shape_enable(shape_enable),.number_enable(number_enable),
 .aux_visible(aux_visible),.shape_lock_request(shape_lock_request),.shape_locked(shape_locked),.shape_result_valid(shape_result_valid),.capture_tag(capture_tag),
 .rgb_in(wb_rgb),.edges(wb_full_edges),.number_edges(wb_edges),.mag(wb_mag),.accepted(wb_accepted),
 .de(wd),.hs(wh),.vs(wv),.rgb_out(annotated),.overlay_mask(annotations),.mag_out(rm),.accepted_out(ra),.de_out(rd),.hs_out(rh),.vs_out(rs));
 wire [15:0] balanced,clean;wire render_de,render_hs,render_vs,pairing_fault;
 edge_balanced_render_2ppc #(.W(W),.H(H),.HT(HT),.CFG_ENABLE(0)) render49(
 .clk(video_clk),.rst_n(video_rst_n),.strength(ra),.de(rd),.hs(rh),.vs(rs),.cfg(19'd0),
 .gray(balanced),.clean(clean),.bw(),.ode(render_de),.ohs(render_hs),.ovs(render_vs),.ocfg());
 pack55 #(.W(W),.H(H)) packer(
 .clk(video_clk),.rst_n(video_rst_n),.de(rd),.vs(rs),.rgb(annotated),.mag(rm),.accepted(ra),
 .annotation(annotations),.exact_defaults(defaults_tag),
 .render_de(render_de),.render_vs(render_vs),.balanced(balanced),.clean(clean),
 .fifo_reset(pack_reset),.frame_start(pack_start),.write_en(pack_en),.write_data(pack_data),.pairing_fault(pairing_fault));
 wire [31:0] write_addr,addr_a,addr_b;
 wire pool_ready,reader_busy,writer_busy,writer_begin,writer_fault,allow_start;
 wire [7:0] write_bank,bank_a,bank_b;wire [2:0] tag_a,tag_b;
 wire [95:0] ui_data;wire review;
 wire frame_locked,axi_locked;
 wire [1:0] axi_page,axi_speed;wire axi_play,axi_rec,axi_sel;
 wire [7:0] axi_count,axi_a,axi_b;wire [15:0] axi_delta;
 // One bundled mailbox for all menu/readback metadata. Source keeps the bus
 // stable until the destination acknowledges; no independently sampled counters.
 wire [47:0] status_now={axi_locked,axi_page,axi_speed,axi_play,axi_rec,axi_sel,axi_count,axi_a,axi_b,axi_delta};
 reg [47:0] status_mail,status_video;reg status_req,status_ack;
 (* async_reg="true" *)reg [1:0] status_ack_sync,status_req_sync;
 assign {frame_locked,frame_page,frame_speed,frame_playing,frame_recording,frame_selected,frame_count,frame_a,frame_b,frame_delta}=status_video;
 always @(posedge axi_clk)begin
 if(!axi_rst_n)begin status_mail<=0;status_req<=0;status_ack_sync<=0;end
 else begin status_ack_sync<={status_ack_sync[0],status_ack};
 if(status_req==status_ack_sync[1]&&status_mail!=status_now)begin status_mail<=status_now;status_req<=~status_req;end end end
 always @(posedge video_clk)begin
 if(!video_rst_n)begin status_video<=0;status_req_sync<=0;status_ack<=0;end
 else begin status_req_sync<={status_req_sync[0],status_req};
 if(status_req_sync[1]!=status_ack)begin status_video<=status_mail;status_ack<=status_req_sync[1];end end end
 wire frame_toggle,read_fifo_reset,frame_tick,display_valid;
 wire [2:0] displayed_app,displayed_ma,displayed_mb;
 // Fetch addresses and raster layout take the same video-frame snapshot.
 reg [2:0] requested_app;
 always @(posedge video_clk)begin
 if(!video_rst_n)requested_app<=0;
 else if(frame_tick)requested_app<=app_mode;
 end
 (* async_reg="true" *)reg [1:0] ft_sync;
 reg ft_seen,pack_old;reg [2:0] pack_tag,writer_tag;
 wire boundary=ft_sync[1]!=ft_seen;wire accepted,ack;
 always @(posedge video_clk)begin
 if(!video_rst_n)begin pack_old<=0;pack_tag<=0;end
 else begin pack_old<=pack_start;if(pack_start&&!pack_old)pack_tag<=capture_tag;end end
 always @(posedge axi_clk)begin
 if(!axi_rst_n)begin ft_sync<=0;ft_seen<=0;writer_tag<=0;end
 else begin ft_sync<={ft_sync[0],frame_toggle};if(boundary)ft_seen<=ft_sync[1];if(writer_begin)writer_tag<=pack_tag;end end
 control55 #(.FRAMES(FRAMES),.BASE(BASE),.STRIDE(STRIDE),.MS_CYCLES(MS_CYCLES)) control(
 .clk(axi_clk),.rst_n(axi_rst_n),.command_toggle(replay_command_toggle),.command(replay_command),
 .app_mode(requested_app),.full_live(live_a),.full_capture(capture_a),.capture_tag(writer_tag),.tag_a(tag_a),.tag_b(tag_b),
 .page_out(axi_page),.speed_out(axi_speed),.playing_out(axi_play),.count_out(axi_count),.index_a_out(axi_a),.index_b_out(axi_b),.delta_out(axi_delta),
 .boundary(boundary),.reader_busy(reader_busy),.writer_busy(writer_busy),.writer_begin(writer_begin),.commit(commit),
 .write_addr(write_addr),.allow_start(allow_start),.addr_a(addr_a),.addr_b(addr_b),.ui_data(ui_data),.ready(pool_ready),.fetch_start(accepted),.acknowledge(ack),
 .recording_out(axi_rec),.selected_out(axi_sel),.frame_locked_out(axi_locked),.display_bank_a(bank_a),.display_bank_b(bank_b),.write_bank_out(write_bank),.review_out(review));
 replay_writer52 #(.WR_FIFO_DEPTH(FIFO_DEPTH)) writer(
 .axi_clk(axi_clk),.rst_n(axi_rst_n),.wr_start(pack_start),.allow_start(allow_start),.busy(writer_busy),.begin_frame(writer_begin),.fault(writer_fault),
 .start_addr(write_addr),.total_burst_len(25'(WORDS)),.bank_sw_ack(1'b0),.bank_sw(commit),.test_cnt(),
 .wr_fifo_rst_p(pack_reset),.wr_fifo_wrclk(video_clk),.wr_fifo_wren(pack_en),.wr_fifo_wrfull(write_full),.wr_fifo_wrdata(pack_data),
 .awid(),.awaddr(awaddr),.awlen(awlen),.awsize(),.awburst(),.awlock(),.awvalid(awvalid),.awcobuf(),.awapcmd(),.awallstrb(),.awqos(),.awcache(),.awprot(),.awready(awready),
 .wdata(wdata),.wstrb(wstrb),.wlast(wlast),.wvalid(wvalid),.wready(wready),.bid(6'd0),.bvalid(bvalid),.bresp(bresp),.bready(bready),.addr_width_test(),.test_BURST_LEN());
 wire empty,pop,reader_fault,underflow;wire [127:0] head;
 reader55 #(.W(W),.H(H),.FIFO_DEPTH(FIFO_DEPTH)) reader(
 .clk(axi_clk),.rst_n(axi_rst_n),.start(accepted),.abort(boundary&&reader_busy),.swap_sides(1'b0),.fullscreen(1'b0),.selected_b(1'b0),
 .addr_a(addr_a),.addr_b(addr_b),.busy(reader_busy),.video_clk(video_clk),.fifo_reset(read_fifo_reset),.pop(pop),.empty(empty),.head(head),.fault(reader_fault),
 .araddr(araddr),.arlen(arlen),.arvalid(arvalid),.arready(arready),.rdata(rdata),.rresp(rresp),.rvalid(rvalid),.rlast(rlast),.rready(rready));
 (* async_reg="true" *)reg [1:0] ack_sync,ready_sync,error_sync;
 always @(posedge video_clk)begin
 if(!video_rst_n)begin ack_sync<=0;ready_sync<=0;error_sync<=0;end
 else begin ack_sync<={ack_sync[0],ack};ready_sync<={ready_sync[0],pool_ready};error_sync<={error_sync[0],reader_fault|writer_fault};end end
 wire [255:0] rec_text;wire [159:0] rec_boxes;wire [2:0] rec_count;wire rec_holding,rec_ready;
 wire rec_active=recognition_run&&(app_mode==3);
 localparam REC_ROI=(W>=768&&H>=768)?768:((W<H?W:H)/4*4);
 number_video_pipeline #(.IMG_W(W),.IMG_H(H),.ROI_SIZE(REC_ROI),.ROI_X(((W-REC_ROI)/8)*4),.ROI_Y(((H-REC_ROI)/8)*4),.H_TOTAL_BEATS(HT),.PANEL_SWAP_RB_ON_EDGE(0),.SLIM_OSD(0),.EXTERNAL_EDGES(1)) math34(
 .clk(video_clk),.rst_n(video_rst_n&&rec_active&&!detect_changed),.enable(rec_active),.expression_mode(1'b1),.lock_pulse(1'b0),
 .rgb_in(wb_rgb),.de_in(ed),.valid_in(ev),.hs_in(eh),.vs_in(es),.threshold_in(8'd0),.external_edge_bits(edges),
 .rgb_out(),.de_out(),.valid_out(),.hs_out(),.vs_out(),.enabled_frame(),.detected_frame(),.ui_expression_locked(),
 .ui_digit(),.ui_preview(),.ui_box(),.ui_expr_text(rec_text),.ui_expr_boxes(rec_boxes),
 .ui_expr_count(rec_count),.ui_expr_holding(rec_holding),.ui_expr_ready(rec_ready));
 wire [47:0] raster_rgb;wire raster_de,raster_hs,raster_vs;
 raster55 #(.W(W),.H(H),.HT(HT),.VT(VT),.HB(HB),.VB(VB),.HS(HS),.VS(VS)) display(
 .clk(video_clk),.rst_n(video_rst_n),.ready(ready_sync[1]),.ack_toggle(ack_sync[1]),.app_mode(app_mode),.mode_a(mode_a),.mode_b(mode_b),
 .frame_page(ui_data[66:65]),.frame_count(ui_data[59:52]),.tag_a(tag_a),.tag_b(tag_b),.aux_visible(aux_visible),.shape_locked(shape_locked),
 .frame_toggle(frame_toggle),.fifo_reset(read_fifo_reset),.empty(empty),.head(head),.pop(pop),.rgb(raster_rgb),.de(raster_de),.hs(raster_hs),.vs(raster_vs),.underflow(underflow),
 .frame_tick(frame_tick),.display_valid(display_valid),.frame_app(displayed_app),.frame_ma(displayed_ma),.frame_mb(displayed_mb));
 ui55 #(.W(W),.H(H)) ui(
 .recognition_run(rec_active),
 .rec_text(rec_text),.rec_boxes(rec_boxes),.rec_count(rec_count),.rec_holding(rec_holding),.rec_ready(rec_ready),
 .clk(video_clk),.rst_n(video_rst_n),.rgb_in(raster_rgb),.de_in(raster_de),.hs_in(raster_hs),.vs_in(raster_vs),
 .app_mode(displayed_app),.mode_a(displayed_ma),.mode_b(displayed_mb),.selected_b(displayed_app==0?1'b0:frame_selected),.same_frame(1'b0),
 .live_a(live_a),.live_b(1'b1),.live_group(1'b1),.wb_locked(wb_locked),.shape_locked(shape_locked),
 .effective_high(capture_high),.effective_low(capture_low),.denoise_active(capture_noise[3]),
 .settings_open(settings_open),.editing(editing),.confirm_reset(confirm_reset),.menu_cursor(menu_cursor),.aux_visible(aux_visible),.osd_detail(osd_detail),.fps_show(fps_show),
 .fps_cam(fps_cam),.fps_vid(fps_vid),.fps_valid(fps_valid),.activity(osd_activity_toggle),.context_code(osd_context),.image_valid(display_valid),
 .frame_locked(frame_locked),.frame_page(frame_page),.frame_speed(frame_speed),.frame_playing(frame_playing),.frame_recording(frame_recording),.frame_selected(frame_selected),
 .frame_count(frame_count),.frame_a(frame_a),.frame_b(frame_b),.frame_delta(frame_delta),.wb_qr(wb_qr),.wb_qg(wb_qg),.wb_qb(wb_qb),
 .rgb_out(rgb_out),.de_out(de_out),.hs_out(hs_out),.vs_out(vs_out));
 assign held_b=!live_a;assign fault=underflow|error_sync[1]|pairing_fault;
 // synthesis translate_off
 initial if(WORDS*16>STRIDE) $fatal(1,"Processed frame exceeds reserved slot");
 // synthesis translate_on
endmodule
