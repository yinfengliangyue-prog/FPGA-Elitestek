`timescale 1ns/1ps
module tb_tasks55;
 reg [2:0] app=1;reg aux=1,obj_live=1;integer saved_a=0,saved_b=0,saved_g=0;
 integer task_pixels[0:3];integer off_pixels=0;
 localparam W=64,H=64,HT=48,VT=72;
 reg ac=0,vc=0,cc=0;always #5 ac=~ac;always #7 vc=~vc;always #5 cc=~cc;
 reg rst=0,cde=0,cvs=0;reg [31:0] cdata=0;
 wire rd,rh,rs;wire [15:0] raw;wire [47:0] rgb;wire de,hs,vs;
 wire [31:0] a_aw,a_ar,p_aw,p_ar,aw,ar;wire [7:0] a_wlen,a_rlen,p_wlen,p_rlen,wl,rl;
 wire a_av,a_wv,a_last,a_br,a_rv,a_rl,a_rr,a_ard,p_av,p_wv,p_last,p_br,p_rv,p_rl,p_rr,p_ard;
 wire [127:0] a_wdata,a_rdata,p_wdata,p_rdata,wd;wire [15:0] a_st,p_st,ws;
 wire [1:0] awr,wrr,bv,arr,rvv,rll;wire [3:0] bresp,rresp;wire [255:0] rrdata;
 wire av,wv,last,br,ard,rr;reg awready=0,wready=0,bvalid=0,arready=0,rvalid=0,rlast=0;reg [127:0] rdata=0;
 frame_buffer #(.I_VID_WIDTH(32),.O_VID_WIDTH(16),.AXI_DATA_WIDTH(128),.AXI_ADDR_WIDTH(32),.WR_FIFO_DEPTH(512),.RD_FIFO_DEPTH(512),.START_ADDR(0),.BURST_LEN(127),.MAX_VID_WIDTH(W/2),.MAX_VID_HIGHT(H)) camera(
 .axi_clk(ac),.rst_n(rst),.freeze_req(1'b0),.i_clk(cc),.i_vs(cvs),.i_de(cde),.vin(cdata),.o_clk(vc),.o_hs(rh),.o_vs(rs),.o_de(rd),.vout(raw),
 .H_FRONT_PORCH(13'd8),.H_SYNC(13'd2),.H_VALID(13'd32),.H_BACK_PORCH(13'd6),.V_FRONT_PORCH(13'd4),.V_SYNC(13'd2),.V_VALID(13'd64),.V_BACK_PORCH(13'd2),
 .awaddr(a_aw),.awlen(a_wlen),.awvalid(a_av),.awready(awr[0]),.wdata(a_wdata),.wstrb(a_st),.wvalid(a_wv),.wlast(a_last),.wready(wrr[0]),.bid(6'd0),.bvalid(bv[0]),.bready(a_br),
 .araddr(a_ar),.arlen(a_rlen),.arvalid(a_ard),.arready(arr[0]),.rid(6'd0),.rdata(a_rdata),.rvalid(a_rv),.rlast(a_rl),.rready(a_rr),.rresp(2'd0));
 debayer_top_2to1 frontend(.in_pclk(vc),.in_rstn(rst),.raw_vs_i(rs),.raw_hs_i(rh),.raw_de_i(rd),.raw_valid_i(rd),.raw_datax4_i(raw),.rgb_vs_o(vs),.rgb_hs_o(hs),.rgb_de_o(de),.rgb_valid_o(),.rgb_datax2_o(rgb));
 wire [47:0] out;wire od,oh,ov,fault;
 system55 #(.FRAMES(8),.W(W),.H(H),.HT(HT),.VT(VT),.HB(8),.VB(4),.HS(2),.VS(2),.BASE(32'h10000),.STRIDE(8192),.FIFO_DEPTH(512),.PANEL_SWAP_RB_ON_EDGE(0)) sys(
 .replay_command_toggle(1'b0),.replay_command(4'd0),.replay_style_a(3'd0),.replay_style_b(3'd0),
 .frame_page(),.frame_speed(),.frame_playing(),.frame_recording(),.frame_selected(),.frame_count(),.frame_a(),.frame_b(),.frame_delta(),.wb_qr(),.wb_qg(),.wb_qb(),
 .app_mode(app),.settings_open(1'b0),.editing(1'b0),.confirm_reset(1'b0),.menu_cursor(5'd0),
 .aux_visible(aux),.shape_lock_request(1'b0),.osd_detail(1'b0),.fps_show(1'b0),.shape_locked(),.shape_result_valid(),
 .video_clk(vc),.recognition_run(1'b0),.video_rst_n(rst),.axi_clk(ac),.axi_rst_n(rst),.rgb_in(rgb),.de_in(de),.hs_in(hs),.vs_in(vs),.mode_a(3'd0),.mode_b(3'd0),.low_a(8'd3),.low_b(8'd3),.analysis_high(8'd6),.analysis_low(8'd3),
 .shape_enable(app==2),.number_enable(1'b0),.edit_low(1'b0),.fullscreen(app!=1),.denoise_enable(1'b1),.menu_page(2'd0),.fps_cam(10'd60),.fps_vid(10'd60),.fps_valid(1'b1),.ai_min_strength(8'd0),.ai_min_select(1'b0),
 .osd_activity_toggle(1'b0),.osd_help_toggle(1'b0),.osd_context(3'd0),.threshold_a(8'd6),.threshold_b(8'd6),.selected_b(1'b0),.swap_sides(1'b1),.live_b(obj_live),.capture_a(1'b0),.capture_b(1'b0),.same_frame(1'b0),.live_a(obj_live),.live_group(1'b1),.capture_group(1'b0),.awb_lock_request(1'b0),
 .rgb_out(out),.de_out(od),.hs_out(oh),.vs_out(ov),.fault(fault),
 .awaddr(p_aw),.awlen(p_wlen),.awvalid(p_av),.awready(awr[1]),.wdata(p_wdata),.wstrb(p_st),.wvalid(p_wv),.wlast(p_last),.wready(wrr[1]),.bvalid(bv[1]),.bresp(2'd0),.bready(p_br),
 .araddr(p_ar),.arlen(p_rlen),.arvalid(p_ard),.arready(arr[1]),.rdata(p_rdata),.rvalid(p_rv),.rlast(p_rl),.rready(p_rr),.rresp(2'd0));
 assign {p_rdata,a_rdata}=rrdata;assign {p_rv,a_rv}=rvv;assign {p_rl,a_rl}=rll;
 axi_pair23 arb(.clk(ac),.rst_n(rst),.c_awaddr({p_aw,a_aw}),.c_awlen({p_wlen,a_wlen}),.c_awvalid({p_av,a_av}),.c_awready(awr),.c_wdata({p_wdata,a_wdata}),.c_wstrb({p_st,a_st}),.c_wvalid({p_wv,a_wv}),.c_wlast({p_last,a_last}),.c_wready(wrr),.c_bvalid(bv),.c_bresp(bresp),.c_bready({p_br,a_br}),.c_araddr({p_ar,a_ar}),.c_arlen({p_rlen,a_rlen}),.c_arvalid({p_ard,a_ard}),.c_arready(arr),.c_rdata(rrdata),.c_rresp(rresp),.c_rvalid(rvv),.c_rlast(rll),.c_rready({p_rr,a_rr}),
 .awaddr(aw),.awlen(wl),.awvalid(av),.awready(awready),.wdata(wd),.wstrb(ws),.wvalid(wv),.wlast(last),.wready(wready),.bvalid(bvalid),.bresp(2'd0),.bready(br),.araddr(ar),.arlen(rl),.arvalid(ard),.arready(arready),.rdata(rdata),.rresp(2'd0),.rvalid(rvalid),.rlast(rlast),.rready(rr));
 reg [127:0] mem[0:12287];bit writing=0,reading=0;integer wa=0,ra=0,wn=0,rn=0,wi=0,ri=0,bd=0;
 integer output_frame=0,raw_pixels=0,rgb_pixels=0,raw_commits=0,processed_commits=0,before_pixels=0,recovered_pixels=0,aborts=0;
 // Hold an entire requested frame: at 64x64 the FIFO can prefetch all rows
 // before line 20, so a late pause would not exercise underflow or cancellation.
 wire pause_reads=output_frame==18;
 always @(negedge ac)begin
  awready=!writing&&!bd&&!bvalid&&$urandom_range(0,4)!=0;wready=$urandom_range(0,4)!=0;arready=!reading&&$urandom_range(0,4)!=0;
  if(bd>0)begin bd--;if(bd==0)bvalid=1;end
  if(!rvalid&&reading&&!pause_reads&&$urandom_range(0,4)!=0)begin rvalid=1;rdata=mem[ra+ri];rlast=ri==rn-1;end
 end
 always @(posedge ac)if(rst)begin
  if(av&&awready)begin writing=1;wa=aw/16;wn=int'(wl)+1;wi=0;if(aw[11:0]+16*wn>4096)$fatal(1,"AW4K");end
  if(wv&&wready)begin if(!writing||last!==(wi==wn-1))$fatal(1,"W protocol");mem[wa+wi]=wd;wi++;if(last)begin writing=0;bd=8;end end
  if(bvalid&&br)bvalid<=0;
  if(ard&&arready)begin reading=1;ra=ar/16;rn=int'(rl)+1;ri=0;if(ar[11:0]+16*rn>4096)$fatal(1,"AR4K");end
  if(rvalid&&rr)begin rvalid<=0;ri++;if(rlast)reading=0;end
  if(camera.u_ddr_buffer.wr_sw)raw_commits++;
  if(sys.commit)processed_commits++;
  if(sys.boundary&&sys.reader_busy)aborts++;
 end
 always @(posedge vc)if(rst)begin
  if(sys.display.h==0&&sys.display.v==0)begin
   output_frame++;
   case(output_frame)
    7:obj_live=0;
    8:app=2;
    13:aux=0;
    16:begin
     if(sys.control.count!=8)$fatal(1,"automatic take did not fill across task switches: %0d",sys.control.count);
     saved_a=sys.control.count;app=3;
    end
    22:app=3;
    26:begin
     if(sys.control.count!=saved_a)$fatal(1,"task changes corrupted immutable take count");
     app=0;
    end
   endcase
  end
  if(od&&sys.display.display_valid&&out!=0&&output_frame>5)begin task_pixels[sys.displayed_app]+=2;if(sys.displayed_app==2&&!aux)off_pixels+=2;end
  if(app==2&&sys.displayed_app==2&&!aux&&output_frame>=15&&sys.recognition.detector.enable!==1)$fatal(1,"aux hide stopped detector");
  if(rd&&raw!=0)raw_pixels+=2;if(de&&rgb!=0)rgb_pixels+=2;
  if(od&&out!=0&&sys.display.image_area)begin if(output_frame>8&&output_frame<18)before_pixels+=2;if(output_frame>21)recovered_pixels+=2;end
 end
 integer f,y,x,j;
 initial begin
 for(j=0;j<12288;j++)mem[j]=0;for(j=0;j<4;j++)task_pixels[j]=0;
 repeat(20)@(negedge cc);rst=1;
 for(f=0;f<36;f++)for(y=0;y<72;y++)for(x=0;x<67;x++)begin
 @(negedge cc);cvs=y<2;cde=y>=4&&y<68&&x>=8&&x<24;
 cdata={8'(90+(x+y+f)%80),8'(110+(3*x+y)%80),8'(80+(x+2*y)%80),8'(100+(x+y)%80)};
 end
 @(negedge cc);cde=0;cvs=0;repeat(HT*VT*2)@(negedge vc);
 if(raw_commits<20||processed_commits<15||raw_pixels<10000||rgb_pixels<10000||before_pixels<1000||recovered_pixels<1000||aborts==0||!sys.underflow)$fatal(1,"capture/recovery failed rawcommit=%0d processed=%0d rawpx=%0d rgbpx=%0d before=%0d after=%0d aborts=%0d underflow=%b",raw_commits,processed_commits,raw_pixels,rgb_pixels,before_pixels,recovered_pixels,aborts,sys.underflow);
 for(j=0;j<4;j++)if(task_pixels[j]<1000)$fatal(1,"task %0d stays black: %0d compatible live pixels",j,task_pixels[j]);
 if(off_pixels<1000)$fatal(1,"shape aux transition stays black");
 if(sys.writer_fault||sys.pairing_fault||sys.reader_fault)$fatal(1,"capture chain transport fault");
 $display("PASS TASKS55_RAW_AND_RECOVERY camera RAW32 -> real raw DDR frame_buffer -> Debayer -> WB53/Canny49 -> 32bit DDR snapshots -> display: raw_commits=%0d processed=%0d before=%0d recovered=%0d aborts=%0d; FULL/FRAME/SHAPE/EXPR nonzero images; task switches preserve immutable take; aux hide keeps detector active; read starvation recovered",raw_commits,processed_commits,before_pixels,recovered_pixels,aborts);$finish;
 end
 initial begin #6000000;$fatal(1,"timeout rawcommits=%0d processed=%0d",raw_commits,processed_commits);end
endmodule
