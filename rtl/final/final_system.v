
module final_system #(
 parameter UI_V2=0,W=1920,H=1080,HT=1066,VT=1122,HB=46,VB=22,HS=2,VS=2,
 parameter BASE=32'h02000000,STRIDE=32'h00400000,FIFO_DEPTH=512,
 parameter PANEL_SWAP_RB_ON_EDGE=1,WB_MIN_SAMPLES=256
)(
 input wire video_clk,video_rst_n,axi_clk,axi_rst_n,
 input wire [2:0] app_mode,input wire settings_open,editing,confirm_reset,input wire [3:0] menu_cursor,
 input wire aux_visible,shape_lock_request,osd_detail,fps_show,
 output wire shape_locked,shape_result_valid,
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
 localparam WORDS=3*W*H/32; // quarter image pixels *48 bits /128
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
 final_wb24 #(.W(W),.H(H),.HT(HT),.MIN_SAMPLES(WB_MIN_SAMPLES)) whitebalance(
 .clk(video_clk),.rst_n(video_rst_n),.lock_request(awb_lock_request),.rgb_in(rgb_in),
 .de_in(de_in),.hs_in(hs_in),.vs_in(vs_in),.rgb_out(wb_full),.de_out(wfd),.hs_out(wfh),.vs_out(wfv),.locked(wb_locked),.rejected(wb_rejected),.gain_r(),.gain_g(),.gain_b());
 localparam CORE_DELAY=1+(HT+4)+1+(HT+5)+1+(HT+4)+2*(HT+5)+(HT+5);
 localparam COLOR_DELAY=CORE_DELAY-HT-8;
 function [13:0] pack554(input [23:0] p);pack554={p[23:19],p[15:11],p[7:4]};endfunction
 function [23:0] unpack554(input [13:0] p);unpack554={p[13:9],p[13:11],p[8:4],p[8:6],p[3:0],p[3:0]};endfunction
 wire [27:0] wb_delayed;
 canny_delay #(.WIDTH(28),.DEPTH(COLOR_DELAY)) color_alignment(video_clk,video_rst_n,{pack554(wb_full[47:24]),pack554(wb_full[23:0])},wb_delayed);
 assign wb_rgb={unpack554(wb_delayed[27:14]),unpack554(wb_delayed[13:0])};
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
 final_pack #(.W(W),.H(H)) packer(
 .clk(video_clk),.rst_n(video_rst_n),.de(rd),.vs(rs),.rgb(annotated),.mag(rm),.accepted(ra),
 .annotation(annotations),.exact_defaults(defaults_tag),
 .render_de(render_de),.render_vs(render_vs),.balanced(balanced),.clean(clean),
 .fifo_reset(pack_reset),.frame_start(pack_start),.write_en(pack_en),.write_data(pack_data),.pairing_fault(pairing_fault));
 wire [2:0] group_bank;wire [31:0] group_generation;
 wire held_a_pool,held_group_pool;
 wire [2:0] wb,ba,bb;
 wire [31:0] ga,gb;
 wire pool_ready,pool_held,reader_busy;
 wire frame_toggle,swap_frame,live_frame,cap_a_frame,cap_b_frame,read_fifo_reset;
 wire same_frame_latched,source_b_frame,fullscreen_frame;
 wire [31:0] write_addr,addr_a,addr_b,addr_group,addr_view;
 wire [2:0] bank_view;wire display_valid,frame_tick;
 reg [2:0] ui_app;reg ui_open,ui_edit,ui_confirm,ui_aux,ui_detail,ui_fps;reg [3:0] ui_cursor;
 reg [2:0] ui_ma,ui_mb;reg ui_sel,ui_same,ui_la,ui_lb,ui_lg,ui_shlock;
 always @(posedge video_clk)begin
 if(!video_rst_n)begin ui_app<=0;ui_open<=0;ui_edit<=0;ui_confirm<=0;ui_aux<=1;ui_detail<=0;ui_fps<=0;ui_cursor<=0;
 ui_ma<=0;ui_mb<=2;ui_sel<=0;ui_same<=0;ui_la<=1;ui_lb<=1;ui_lg<=1;ui_shlock<=0;end
 else if(frame_tick)begin ui_app<=app_mode;ui_open<=settings_open;ui_edit<=editing;ui_confirm<=confirm_reset;ui_aux<=aux_visible;ui_detail<=osd_detail;ui_fps<=fps_show;ui_cursor<=menu_cursor;
 ui_ma<=mode_a;ui_mb<=mode_b;ui_sel<=selected_b;ui_same<=same_frame;ui_la<=live_a;ui_lb<=live_b;ui_lg<=live_group;ui_shlock<=shape_locked;end end
 wire recog_view=UI_V2&&ui_app>=2;
 // Frame metadata crosses with the writer-start toggle and is held until commit.
 reg [2:0] packed_tag;reg pack_start_d;(* async_reg="true" *)reg [1:0] ps_sync;
 reg ps_seen;reg [2:0] writer_tag;reg [2:0] bank_tags[0:5];integer tag_i;
 always @(posedge video_clk)begin if(!video_rst_n)begin packed_tag<=0;pack_start_d<=0;end
 else begin pack_start_d<=pack_start;if(pack_start&&!pack_start_d)packed_tag<=capture_tag;end end
 always @(posedge axi_clk)begin
 if(!axi_rst_n)begin ps_sync<=0;ps_seen<=0;writer_tag<=0;for(tag_i=0;tag_i<6;tag_i=tag_i+1)bank_tags[tag_i]<=0;end
 else begin ps_sync<={ps_sync[0],pack_start};if(ps_sync[1]!=ps_seen)begin ps_seen<=ps_sync[1];if(ps_sync[1])writer_tag<=packed_tag;end
 if(commit)bank_tags[wb]<=writer_tag;end end
 wire [2:0] view_tag=bank_tags[bank_view];
 wire video_clean=same_frame_latched?(bank_tags[group_bank][2]==0):
  fullscreen_frame?(source_b_frame?bank_tags[bb][2]==0:bank_tags[ba][2]==0):(bank_tags[ba][2]==0&&bank_tags[bb][2]==0);
 wire image_compatible=!UI_V2||(recog_view?(view_tag[2]==(ui_app==2)&&(ui_app!=2||(view_tag[1]==ui_aux&&view_tag[0]==ui_shlock))):video_clean);
 wire [47:0] raster_rgb;wire raster_de,raster_hs,raster_vs;
 // Bundled configuration is held for the complete display transaction, like swap_frame.
 // Both reader bases select the SAME protected object slot after pool boundary updates.
 wire [31:0] source_addr=addr_group;
 wire [31:0] read_addr_a=recog_view?addr_view:same_frame_latched ? source_addr : addr_a;
 wire [31:0] read_addr_b=recog_view?addr_view:same_frame_latched ? source_addr : addr_b;
 (* async_reg="true" *) reg [1:0] ft_sync,ca_sync,cb_sync,live_sync,la_sync,lg_sync,cg_sync;
 wire live_a_frame,live_group_frame,cap_group_frame;
 reg frame_seen,ack;
 reg write_error;
 wire boundary=ft_sync[1]!=frame_seen;
 wire accepted=boundary && !reader_busy && pool_ready;
 always @(posedge axi_clk or negedge axi_rst_n) begin
   if(!axi_rst_n) begin
     ft_sync<=0;ca_sync<=0;cb_sync<=0;live_sync<=3;la_sync<=3;lg_sync<=3;cg_sync<=0;
     frame_seen<=0;ack<=0;write_error<=0;
   end else begin
     ft_sync<={ft_sync[0],frame_toggle};ca_sync<={ca_sync[0],cap_a_frame};
     cb_sync<={cb_sync[0],cap_b_frame};live_sync<={live_sync[0],live_frame};
     la_sync<={la_sync[0],live_a_frame};lg_sync<={lg_sync[0],live_group_frame};
     cg_sync<={cg_sync[0],cap_group_frame};
     if(boundary) frame_seen<=ft_sync[1];
     if(accepted) ack<=~ack;
     if(bvalid && bready && bresp!=0) write_error<=1;
   end
 end
 compare_pool23 #(.BASE(BASE),.STRIDE(STRIDE),.SLOT_COUNT(UI_V2?6:5),.LIVE_VIEW_ENABLE(UI_V2)) pool(
   .clk(axi_clk),.rst_n(axi_rst_n),.commit(commit),.display_boundary(accepted),
   .capture_a(ca_sync[1]),.capture_b(cb_sync[1]),.live_b(live_sync[1]),
   .live_view(recog_view),.addr_view(addr_view),.bank_view(bank_view),
   .live_a(la_sync[1]),.live_group(lg_sync[1]),.capture_group(cg_sync[1]),.sync_mode(same_frame_latched),
   .addr_group(addr_group),.held_a(held_a_pool),.held_group(held_group_pool),
   .bank_group(group_bank),.generation_group(group_generation),
   .write_addr(write_addr),.addr_a(addr_a),.addr_b(addr_b),.ready(pool_ready),.held_b(pool_held),
   .write_bank(wb),.bank_a(ba),.bank_b(bb),.generation_a(ga),.generation_b(gb));
 compare_writer23 #(.AXI_DATA_WIDTH(128),.AXI_ADDR_WIDTH(32),.WR_FIFO_DEPTH(FIFO_DEPTH),.BURST_LEN(127)) writer(
   .axi_clk(axi_clk),.rst_n(axi_rst_n),.wr_start(pack_start),.start_addr(write_addr),
   .total_burst_len(25'(WORDS)),.bank_sw_ack(1'b0),.bank_sw(commit),.test_cnt(),
   .wr_fifo_rst_p(pack_reset),.wr_fifo_wrclk(video_clk),.wr_fifo_wren(pack_en),
   .wr_fifo_wrfull(write_full),.wr_fifo_wrdata(pack_data),
   .awid(),.awaddr(awaddr),.awlen(awlen),.awsize(),.awburst(),.awlock(),.awvalid(awvalid),
   .awcobuf(),.awapcmd(),.awallstrb(),.awqos(),.awcache(),.awprot(),.awready(awready),
   .wdata(wdata),.wstrb(wstrb),.wlast(wlast),.wvalid(wvalid),.wready(wready),
   .bid(6'd0),.bvalid(bvalid),.bresp(bresp),.bready(bready),.addr_width_test(),.test_BURST_LEN());
 wire empty,pop,reader_fault;
 wire [127:0] head;
 final_reader #(.W(W),.H(H),.FIFO_DEPTH(FIFO_DEPTH)) reader(
   .clk(axi_clk),.rst_n(axi_rst_n),.start(accepted),.abort(boundary&&reader_busy),.swap_sides(1'b0),
   .addr_a(read_addr_a),.addr_b(read_addr_b),.busy(reader_busy),.fullscreen(fullscreen_frame),.selected_b(source_b_frame),
   .video_clk(video_clk),.fifo_reset(read_fifo_reset),.pop(pop),.empty(empty),.head(head),.fault(reader_fault),
   .araddr(araddr),.arlen(arlen),.arvalid(arvalid),.arready(arready),
   .rdata(rdata),.rresp(rresp),.rvalid(rvalid),.rlast(rlast),.rready(rready));
 (* async_reg="true" *) reg [1:0] ack_sync,ready_sync,held_sync,error_sync,ha_sync,hg_sync;
 reg write_overflow;
 wire underflow;
 always @(posedge video_clk) begin
   if(!video_rst_n) begin
     ack_sync<=0;ready_sync<=0;held_sync<=0;error_sync<=0;write_overflow<=0;ha_sync<=0;hg_sync<=0;
   end else begin
     ack_sync<={ack_sync[0],ack};ready_sync<={ready_sync[0],pool_ready};
     held_sync<={held_sync[0],pool_held};
     ha_sync<={ha_sync[0],held_a_pool};hg_sync<={hg_sync[0],held_group_pool};error_sync<={error_sync[0],reader_fault || write_error};
     if(pack_en && write_full) write_overflow<=1;
   end
 end
 assign held_b=same_frame ? hg_sync[1] : (selected_b ? held_sync[1] : ha_sync[1]);assign fault=underflow || write_overflow || error_sync[1] || pairing_fault;
 final_raster #(.UI_V2(UI_V2),.W(W),.H(H),.HT(HT),.VT(VT),.HB(HB),.VB(VB),.HS(HS),.VS(VS),
   .PANEL_SWAP_RB_ON_EDGE(PANEL_SWAP_RB_ON_EDGE)) display(
   .clk(video_clk),.rst_n(video_rst_n),.ready(ready_sync[1]),.ack_toggle(ack_sync[1]),
   .image_compatible(image_compatible),.display_valid(display_valid),.frame_tick(frame_tick),
   .osd_activity_toggle(osd_activity_toggle),.osd_help_toggle(osd_help_toggle),.osd_context(osd_context),
   .mode_a(mode_a),.mode_b(mode_b),.threshold_a(threshold_a),.threshold_b(threshold_b),
   .low_a(low_a),.low_b(low_b),.analysis_high(analysis_high),.analysis_low(analysis_low),
   .shape_enable(shape_enable),.number_enable(number_enable),.edit_low(edit_low),.menu_page(menu_page),
   .ai_min_strength(ai_min_strength),.ai_min_select(ai_min_select),.fps_cam(fps_cam),.fps_vid(fps_vid),.fps_valid(fps_valid),.denoise_enable(denoise_enable),
   .fullscreen(fullscreen),.fullscreen_frame(fullscreen_frame),
   .live_a(live_a),.live_group(live_group),.capture_group(capture_group),
   .live_a_frame(live_a_frame),.live_group_frame(live_group_frame),.cap_group_frame(cap_group_frame),
   .wb_locked(wb_locked),.same_frame(same_frame),.selected_b(selected_b),.swap_sides(1'b0),.live_b(live_b),.capture_a(capture_a),.capture_b(capture_b),
   .same_frame_latched(same_frame_latched),.source_b_frame(source_b_frame),
   .frame_toggle(frame_toggle),.swap_frame(swap_frame),.live_frame(live_frame),
   .cap_a_frame(cap_a_frame),.cap_b_frame(cap_b_frame),.fifo_reset(read_fifo_reset),
   .empty(empty),.head(head),.pop(pop),.rgb(raster_rgb),.de(raster_de),.hs(raster_hs),.vs(raster_vs),.underflow(underflow));
 generate if(UI_V2)begin:menu_v2
 final_ui_overlay #(.W(W),.H(H)) ui(
 .clk(video_clk),.rst_n(video_rst_n),.rgb_in(raster_rgb),.de_in(raster_de),.hs_in(raster_hs),.vs_in(raster_vs),
 .app_mode(ui_app),.mode_a(ui_ma),.mode_b(ui_mb),.selected_b(ui_sel),.same_frame(ui_same),
 .live_a(ui_la),.live_b(ui_lb),.live_group(ui_lg),.wb_locked(wb_locked),.shape_locked(ui_shlock),
 .effective_high(capture_high),.effective_low(capture_low),.denoise_active(capture_noise[3]),
 .settings_open(ui_open),.editing(ui_edit),.confirm_reset(ui_confirm),.menu_cursor(ui_cursor),
 .aux_visible(ui_aux),.osd_detail(ui_detail),.fps_show(ui_fps),.fps_cam(fps_cam),.fps_vid(fps_vid),.fps_valid(fps_valid),
 .activity(osd_activity_toggle),.context_code(osd_context),.image_valid(display_valid&&image_compatible),
 .rgb_out(rgb_out),.de_out(de_out),.hs_out(hs_out),.vs_out(vs_out));
 end else begin:legacy_regression
 assign rgb_out=raster_rgb;assign de_out=raster_de;assign hs_out=raster_hs;assign vs_out=raster_vs;
 end endgenerate
 // synthesis translate_off
 initial if(WORDS*16>STRIDE) $fatal(1,"Processed frame exceeds reserved slot");
 // synthesis translate_on
endmodule
