
`timescale 1ns/1ps
module tb_system55;
`ifdef FULL_HD
localparam W=1920,H=1080,HT=1100,VT=1125,HB=96,VB=41,STRIDE=2076672;
`else
localparam W=64,H=64,HT=48,VT=72,HB=6,VB=4,STRIDE=4096;
`endif
`ifdef FULL_HD
localparam HSW=22,VSW=5;
`else
localparam HSW=2,VSW=2;
`endif
localparam WORDS=W*H/16;
`ifdef FULL_HD
localparam MS=100000;
`else
localparam MS=100;
`endif
localparam REF_FRAMES=
`ifdef FULL_HD
16;
`else
230;
`endif
reg [31:0] reference_payload[0:REF_FRAMES*W*H/4-1];
initial
`ifdef FULL_HD
$readmemh("verification/reference55_hd.hex",reference_payload);
`else
$readmemh("verification/reference55_small.hex",reference_payload);
`endif
reg command_toggle=0;reg [3:0] command=0;
reg vc=0,ac=0;always #6.734 vc=~vc;always #5 ac=~ac;
reg rst=0,ide=0,ihs=0,ivs=0;
reg [47:0] irgb=0;
reg [1:0] ma=0,mb=2;
reg [7:0] ta=2,tb=2;
reg sel=1,swap=0,live=1,ca=0,cb=0,same=0;
wire [47:0] rgb;wire de,hs,vs,held,fault;
wire [31:0] awaddr,araddr;wire [7:0] awlen,arlen;
wire awvalid,wvalid,wlast,bready,arvalid,rready;
wire [127:0] wdata;wire [15:0] wstrb;
reg awready=0,wready=0,bvalid=0,arready=0,rvalid=0,rlast=0;
reg [127:0] rdata=0;

wire [31:0] p_awaddr,p_araddr;wire [7:0] p_awlen,p_arlen;
wire p_awvalid,p_awready,p_wvalid,p_wlast,p_wready,p_bvalid,p_bready,p_arvalid,p_arready,p_rvalid,p_rlast,p_rready;
wire [127:0] p_wdata,p_rdata;wire [15:0] p_wstrb;wire [1:0] p_bresp,p_rresp;
wire [1:0] cr_aw,cr_w,cr_b,cr_ar,cr_r,cr_rl;wire [3:0] cr_br,cr_rr;wire [255:0] cr_rd;
reg [1:0] bg_wstate=0,bg_rstate=0;
integer bg_wgap=700,bg_rgap=700,bg_windex=0,bg_rindex=0,bg_writes=0,bg_reads=0;
wire [127:0] bg_data={4{32'(32'h10000000/16+bg_windex)}};
axi_pair23 arbiter(
.clk(ac),.rst_n(rst),
.c_awaddr({p_awaddr,32'h10000000}),.c_awlen({p_awlen,8'd63}),
.c_awvalid({p_awvalid,bg_wstate==1}),.c_awready(cr_aw),
.c_wdata({p_wdata,bg_data}),.c_wstrb({p_wstrb,16'hffff}),
.c_wvalid({p_wvalid,bg_wstate==2}),.c_wlast({p_wlast,bg_windex==63}),.c_wready(cr_w),
.c_bvalid(cr_b),.c_bresp(cr_br),.c_bready({p_bready,bg_wstate==3}),
.c_araddr({p_araddr,32'h10000000}),.c_arlen({p_arlen,8'd63}),
.c_arvalid({p_arvalid,bg_rstate==1}),.c_arready(cr_ar),
.c_rdata(cr_rd),.c_rresp(cr_rr),.c_rvalid(cr_r),.c_rlast(cr_rl),
.c_rready({p_rready,bg_rstate==2}),
.awaddr(awaddr),.awlen(awlen),.awvalid(awvalid),.awready(awready),
.wdata(wdata),.wstrb(wstrb),.wvalid(wvalid),.wlast(wlast),.wready(wready),
.bvalid(bvalid),.bresp(2'd0),.bready(bready),
.araddr(araddr),.arlen(arlen),.arvalid(arvalid),.arready(arready),
.rdata(rdata),.rresp(2'd0),.rvalid(rvalid),.rlast(rlast),.rready(rready));
assign p_awready=cr_aw[1];assign p_wready=cr_w[1];assign p_bvalid=cr_b[1];assign p_bresp=cr_br[3:2];
assign p_arready=cr_ar[1];assign p_rdata=cr_rd[255:128];assign p_rresp=cr_rr[3:2];
assign p_rvalid=cr_r[1];assign p_rlast=cr_rl[1];
always @(posedge ac) begin
 if(!rst) begin
   bg_wstate<=0;bg_rstate<=0;bg_wgap<=700;bg_rgap<=700;bg_windex<=0;bg_rindex<=0;
 end else begin
   case(bg_wstate)
     0: if(bg_wgap==0) begin bg_wstate<=1;bg_windex<=0;end else bg_wgap<=bg_wgap-1;
     1: if(cr_aw[0]) bg_wstate<=2;
     2: if(cr_w[0]) begin
       if(bg_windex==63) bg_wstate<=3;
       else bg_windex<=bg_windex+1;
     end
     3: if(cr_b[0]) begin bg_writes++;bg_wstate<=0;bg_wgap<=700;end
   endcase
   case(bg_rstate)
     0: if(bg_rgap==0) begin bg_rstate<=1;bg_rindex<=0;end else bg_rgap<=bg_rgap-1;
     1: if(cr_ar[0]) bg_rstate<=2;
     2: if(cr_r[0]) begin
       if(cr_rd[127:0] !== {4{32'(32'h10000000/16+bg_rindex)}} || cr_rl[0]!=(bg_rindex==63))
         $fatal(1,"background read response routed/corrupted incorrectly");
       if(cr_rl[0]) begin bg_reads++;bg_rstate<=0;bg_rgap<=700;end
       else bg_rindex<=bg_rindex+1;
     end
   endcase
 end
end
system55 #(.W(W),.H(H),.HT(HT),.VT(VT),.HB(HB),.VB(VB),.HS(HSW),.VS(VSW),.BASE(0),.STRIDE(STRIDE),.FIFO_DEPTH(512),.MS_CYCLES(MS),.WB_MIN_SAMPLES(32'hffffffff)) dut(
.video_clk(vc),.video_rst_n(rst),.recognition_run(1'b0),.axi_clk(ac),.axi_rst_n(rst),
.rgb_in(irgb),.de_in(ide),.hs_in(ihs),.vs_in(ivs),
.replay_command_toggle(command_toggle),.replay_command(command),
 .app_mode(3'd1),.settings_open(1'b0),.editing(1'b0),.confirm_reset(1'b0),.menu_cursor(5'd0),.aux_visible(1'b1),.shape_lock_request(1'b0),.osd_detail(1'b0),.fps_show(1'b0),
 .mode_a({1'b0,dut.control.mode_a}),.mode_b({1'b0,dut.control.mode_b}),.replay_style_a(3'd0),.replay_style_b(3'd2),
 .shape_enable(1'b0),.number_enable(1'b0),.edit_low(1'b0),.fullscreen(1'b0),.denoise_enable(1'b1),.menu_page(2'd0),
 .fps_cam(10'd30),.fps_vid(10'd60),.fps_valid(1'b1),.ai_min_strength(8'd0),.ai_min_select(1'b0),.osd_activity_toggle(1'b0),.osd_help_toggle(1'b0),.osd_context(3'd0),
 .threshold_a(8'd6),.threshold_b(8'd6),.low_a(8'd3),.low_b(8'd3),.selected_b(1'b1),.swap_sides(1'b0),.live_b(1'b1),.capture_a(1'b0),.capture_b(1'b0),.same_frame(1'b0),.live_a(1'b1),.live_group(1'b1),.capture_group(1'b0),.awb_lock_request(1'b1),.analysis_high(8'd6),.analysis_low(8'd3),.frame_recording(),.frame_selected(),.frame_page(),.frame_speed(),.frame_playing(),.frame_count(),.frame_a(),.frame_b(),.frame_delta(),.wb_qr(),.wb_qg(),.wb_qb(),.shape_locked(),.shape_result_valid(),
.rgb_out(rgb),.de_out(de),.hs_out(hs),.vs_out(vs),.held_b(held),.fault(fault),
.awaddr(p_awaddr),.awlen(p_awlen),.awvalid(p_awvalid),.awready(p_awready),
.wdata(p_wdata),.wstrb(p_wstrb),.wvalid(p_wvalid),.wlast(p_wlast),.wready(p_wready),
.bvalid(p_bvalid),.bresp(p_bresp),.bready(p_bready),
.araddr(p_araddr),.arlen(p_arlen),.arvalid(p_arvalid),.arready(p_arready),
.rdata(p_rdata),.rresp(p_rresp),.rvalid(p_rvalid),.rlast(p_rlast),.rready(p_rready));

reg pc=0;always #3.367 pc=~pc;
wire [23:0] hrgb;wire hde,hhs,hvs,hfault;
hdmi_gearbox40 gear(vc,pc,rst,rgb,de,hs,vs,hrgb,hde,hhs,hvs,hfault);
reg [26:0] expected_stream[0:255];integer stream_tail=0,stream_head=0;
integer hdmi_active=0,hdmi_cycles=0,hdmi_lines=0,hdmi_frames=0;
reg stream_running,old_hde=0,old_hvs=0;integer line_active=0;
always @(posedge vc)begin
 if(!rst)stream_tail=0;
 else if(gear.pair_reset[1])begin
  if(stream_tail-stream_head>250)$fatal(1,"HDMI scoreboard overflow");
  expected_stream[stream_tail%256]={rgb[23:0],de,hs,vs};
  expected_stream[(stream_tail+1)%256]={rgb[47:24],de,hs,vs};stream_tail+=2;
 end
end
always @(posedge pc)begin
 if(!rst)begin stream_head=0;hdmi_active=0;hdmi_cycles=0;old_hde=0;old_hvs=0;line_active=0;end
 else begin
  stream_running=gear.pixel_reset[1] && gear.started;
  #0.1;
  if(hfault)$fatal(1,"HDMI conversion fault");
  if(stream_running)begin
   if(stream_head>=stream_tail || {hrgb,hde,hhs,hvs}!==expected_stream[stream_head%256])
    $fatal(1,"HDMI RGB/sync mismatch pixel %0d",stream_head);
   stream_head++;hdmi_cycles++;
   if(hde)begin hdmi_active++;line_active++;end
   if(old_hde && !hde)begin
    if(line_active!=W)$fatal(1,"HDMI line count %0d",line_active);
    line_active=0;hdmi_lines++;
   end
   if(hvs && !old_hvs)hdmi_frames++;
   old_hde=hde;old_hvs=hvs;
  end
 end
end
final $display("HDMI42_SCOREBOARD pixels=%0d active=%0d lines=%0d frames=%0d",hdmi_cycles,hdmi_active,hdmi_lines,hdmi_frames);
function automatic [23:0] pixel(input integer x,y,f);
integer b;
begin
 // All sampled AWB pairs are neutral; other pairs have G=0 and are rejected.
 // Production AUTO estimator therefore publishes unity, without bypassing it.
 b=(y*7+x)%128;
 if(((x/2)%4==0)&&(y%4==0))pixel={3{8'(f)}};
 else pixel={8'(f),8'd0,8'(b)};
end endfunction
function automatic [31:0] payload(input integer x,y,f);
 payload=reference_payload[(f-1)*(W*H/4)+(y/2)*(W/2)+(x/2)];
endfunction
function automatic [23:0] render_ref(input integer x,y,f,m,t);
reg [31:0] p;reg [23:0] color;
begin
 p=payload(x,y,f);color={p[13:9],p[13:11],p[8:4],p[8:6],p[3:0],p[3:0]};
 if(m==0)render_ref=color;
 else if(m==1)render_ref=p[15]?24'hff0000:color;
 else render_ref={3{p[31:24]}};
end endfunction

reg [127:0] mem[int unsigned];
integer stored_f[0:122],stored_count[0:122];
integer wa=0,wl=0,wi=0,ra=0,rl=0,ri=0,bd=0;
integer commits=0,responses=0,reads=0,pixel_checks=0,payload_checks=0;
integer f;integer ref_a=0,ref_b=0,bank,offset,j,idx,x,y,frame_id;
bit write_active=0,read_active=0,frame_valid=0;
reg [31:0] pword,held_awaddr,held_araddr;reg [7:0] held_awlen,held_arlen;
reg aw_stalled=0,ar_stalled=0;
always @(negedge ac) begin
 awready=$urandom_range(0,3)!=0 && !write_active && bd==0 && !bvalid;
 wready=$urandom_range(0,3)!=0;
 arready=$urandom_range(0,3)!=0 && !read_active;
 if(bd>0)begin bd--;if(bd==0)bvalid=1;end
 if(!rvalid)begin
  rvalid=read_active && $urandom_range(0,3)!=0;
  if(rvalid)begin rdata=ra>=32'h10000000/16?{4{32'(ra+ri)}}:mem[ra+ri];rlast=ri==rl-1;end
 end
end
always @(posedge ac)if(rst)begin
 if(aw_stalled && (!awvalid || awaddr!=held_awaddr || awlen!=held_awlen))$fatal(1,"unstable AW stall");
 if(ar_stalled && (!arvalid || araddr!=held_araddr || arlen!=held_arlen))$fatal(1,"unstable AR stall");
 aw_stalled=awvalid&&!awready;ar_stalled=arvalid&&!arready;
 held_awaddr=awaddr;held_awlen=awlen;held_araddr=araddr;held_arlen=arlen;
 if(awvalid && awready)begin
  if(awaddr[11:0]+16*(int'(awlen)+1)>4096)$fatal(1,"AW crosses 4k");
  if(awaddr<32'h10000000)begin
   bank=awaddr/STRIDE;offset=(awaddr%STRIDE)/16;
   if(bank>122 || offset+int'(awlen)+1>WORDS)$fatal(1,"AW outside slot");
   if(dut.reader_busy && (bank==dut.bank_a || bank==dut.bank_b))$fatal(1,"overwrite current reader");
   if(offset==0)begin stored_count[bank]=0;stored_f[bank]=0;end
  end
  wa=awaddr/16;wl=int'(awlen)+1;wi=0;write_active=1;
 end
 if(wvalid && wready)begin
  if(!write_active || wlast!=(wi==wl-1) || wstrb!=16'hffff)$fatal(1,"W protocol");
  if(wa<32'h10000000/16)begin
   bank=(wa+wi)/(STRIDE/16);offset=(wa+wi)%(STRIDE/16);
   for(j=0;j<4;j++)begin
    pword=wdata[127-j*32-:32];frame_id=stored_f[bank]==0?f:stored_f[bank];
    if(stored_f[bank]==0)stored_f[bank]=frame_id;
    if(frame_id!=stored_f[bank] || frame_id==0)$fatal(1,"mixed stored frame");
    idx=offset*4+j;x=2*(idx%(W/2));y=2*(idx/(W/2));
    if(pword!==payload(x,y,frame_id))$fatal(1,"stored f=%0d xy=%0d,%0d expected=%h actual=%h",frame_id,x,y,payload(x,y,frame_id),pword);
    payload_checks++;
   end
   mem[wa+wi]=wdata;stored_count[bank]++;
  end else if(wdata!=={4{32'(wa+wi)}})$fatal(1,"background write data");
  wi++;if(wlast)begin write_active=0;bd=$urandom_range(2,20);end
 end
 if(bvalid && bready)begin bvalid<=0;responses++;end
 if(arvalid && arready)begin
  if(araddr[11:0]+16*(int'(arlen)+1)>4096)$fatal(1,"AR crosses 4k");
  ra=araddr/16;rl=int'(arlen)+1;ri=0;read_active=1;reads++;
 end
 if(rvalid && rready)begin rvalid<=0;ri++;if(rlast)read_active=0;end
 if(dut.commit)begin
  bank=int'(dut.control.inflight_bank);
  if(stored_count[bank]!=WORDS || ((write_active || bd || bvalid) && wa<32'h10000000/16))$fatal(1,"early commit");
  commits++;
 end
 if(dut.accepted)begin
  ref_a=stored_f[dut.control.chosen_a];ref_b=stored_f[dut.control.chosen_b];
  if(ref_a==0 || ref_b==0)$fatal(1,"read unpublished frame");
  frame_valid=1;
 end
end
always @(posedge vc)if(rst&&dut.display.frame_tick)frame_valid=0;
integer frames=0,outx=0,outy=0,line_pixels=0,frame_pixels=0,frame_lines=0;
integer sx,sy,of,om,ot;bit vs_d=0,de_d=0;reg [47:0] expected_rgb;
integer preview=0;string preview_path;
always @(posedge vc)begin
 #3;
 if(rst)begin
  if(vs && !vs_d)begin
   if(frames>0 && (frame_pixels!=W*H || frame_lines!=H))$fatal(1,"raster frame geometry");
   if(preview)begin $fclose(preview);preview=0;end
   frames++;
`ifdef FULL_HD
   if(frames==2 || frames==4 || frames==6)begin
    preview_path=$sformatf("preview52_frame_%0d.ppm",frames);preview=$fopen(preview_path,"wb");
    $fwrite(preview,"P6\n%0d %0d\n255\n",W,H);
   end
`endif
   outx=0;outy=0;frame_pixels=0;frame_lines=0;
  end
  if(de)begin
   if(preview)$fwrite(preview,"%c%c%c%c%c%c",rgb[23:16],rgb[15:8],rgb[7:0],rgb[47:40],rgb[39:32],rgb[31:24]);
   if($isunknown(rgb))$fatal(1,"unknown display data");
   if(outy>=H/4 && outy<3*H/4)begin
    if(frame_valid)begin
     of=outx>=W/2?ref_b:ref_a;om=outx>=W/2?dut.display.frame_mb:dut.display.frame_ma;ot=outx>=W/2?8'd6:8'd6;
     sx=(outx%(W/2))*2;sy=(outy-H/4)*2;
     expected_rgb={render_ref(sx+2,sy,of,om,ot),render_ref(sx,sy,of,om,ot)};
    end else expected_rgb=0;
    if(W>=1280&&((outx>=W/2)==dut.ui.sel)&&((outx%(W/2)<2)||(outx%(W/2)>=W/2-2)))expected_rgb={2{24'hffff00}};
    if(rgb!==expected_rgb)$fatal(1,"display f=%0d xy=%0d,%0d refs=%0d/%0d expected=%h actual=%h",frames,outx,outy,ref_a,ref_b,expected_rgb,rgb);
    pixel_checks+=2;
   end
   outx+=2;line_pixels+=2;frame_pixels+=2;
  end
  if(!de && de_d)begin
   if(line_pixels!=W)$fatal(1,"line length");outx=0;outy++;line_pixels=0;frame_lines++;
  end
  if(fault)$fatal(1,"buffer fault frame=%0d underflow=%b writer=%b",frames,dut.underflow,dut.writer_fault);
  vs_d=vs;de_d=de;
 end
end
task source_frame(input integer f);
integer row,k,xx,yy;
begin
 for(row=0;row<VT;row++)for(k=0;k<HT;k++)begin
  @(negedge vc);yy=row-VB;xx=2*(k-HB);
  ihs=k<HSW;ivs=row<VSW;ide=yy>=0 && yy<H && k>=HB && k<HB+W/2;
  irgb=ide?{pixel(xx+1,yy,f),pixel(xx,yy,f)}:0;
 end
end endtask
task cmd(input [3:0] mask);begin
 @(negedge vc);command=mask;command_toggle=~command_toggle;repeat(12)@(negedge vc);
end endtask
integer k,old_first,locked_bank,locked_source;
initial begin
 for(j=0;j<123;j++)begin stored_f[j]=0;stored_count[j]=0;end
 repeat(20)@(negedge vc);rst=1;
 fork
  begin for(f=1;f<230;f++)source_frame(f);end
  begin
`ifdef FULL_HD
   wait(dut.control.count>=2);cmd(1);wait(frames==4);cmd(8);
   wait(frames==5);cmd(1);wait(frames==6);cmd(8);cmd(4);cmd(6);
   wait(frames==8);
`else
   wait(dut.control.count>=8);cmd(15);wait(dut.control.pair_valid);
   locked_bank=dut.control.pair_bank;locked_source=stored_f[locked_bank];
   wait(dut.control.count>=24);repeat(2*HT*VT)@(negedge vc);
   if(!dut.frame_locked||dut.bank_a!=locked_bank||dut.bank_b!=locked_bank||stored_f[locked_bank]!=locked_source)$fatal(1,"LIVE pair lock or history recording failed");
   // Re-render independent styles from the same pinned snapshot.
   cmd(6);repeat(2*HT*VT)@(negedge vc);cmd(6);repeat(2*HT*VT)@(negedge vc);cmd(6);
   if(dut.bank_a!=locked_bank||dut.bank_b!=locked_bank)$fatal(1,"style change released paired snapshot");
   cmd(15);wait(!dut.frame_locked);
   wait(dut.control.count==120);old_first=stored_f[0];
   repeat(3*HT*VT)@(negedge vc);cmd(15);wait(dut.control.pair_valid);
   locked_bank=dut.control.pair_bank;locked_source=stored_f[locked_bank];
   repeat(6*HT*VT)@(negedge vc);
   if(dut.bank_a!=locked_bank||dut.bank_b!=locked_bank||stored_f[locked_bank]!=locked_source||dut.control.count!=120)$fatal(1,"live-slot pin overwritten or immutable take corrupted");
   cmd(15);wait(!dut.frame_locked);repeat(3*HT*VT)@(negedge vc);
   // Slot numbers intentionally rotate and can equal the former held slot.
   // The displayed source frame IDs, rather than addresses, prove freshness.
   if(ref_a==locked_source&&ref_b==locked_source)$fatal(1,"unlock did not resume live stream");
   repeat(4*HT*VT)@(negedge vc);
   if(dut.control.recording || stored_f[0]!=old_first)$fatal(1,"full take not immutable");
   cmd(1);cmd(8);repeat(5*HT*VT)@(negedge vc);
   if(dut.control.play_index==0 || !dut.control.playing)$fatal(1,"replay did not progress");
   cmd(4);if(dut.control.playing)$fatal(1,"step must pause");
   cmd(1);repeat(HT*VT)@(negedge vc);
   if(dut.control.index_a!=0 || dut.control.index_b!=119)$fatal(1,"comparison defaults");
   cmd(8);repeat(10)cmd(4);cmd(6);cmd(6);
   if(dut.control.index_a!=10 || dut.control.index_b!=119 || dut.control.mode_a!=1)$fatal(1,"independent compare selection");
   repeat(3*HT*VT)@(negedge vc);cmd(9);
   wait(dut.control.count==0);wait(dut.control.count>=12);cmd(8);
   repeat(3*HT*VT)@(negedge vc);
   if(dut.control.count>=120 || dut.control.recording || stored_f[0]==old_first)$fatal(1,"new take / early stop");
   cmd(1);repeat(3*HT*VT)@(negedge vc);
`endif
   if(pixel_checks==0 || payload_checks==0 || bg_reads==0 || bg_writes==0)$fatal(1,"no meaningful checks");
   $display("PASS SYSTEM55_FULL_REPLAY52 paired freeze/unfreeze in recording and live-slot rotation, immutable pin and returned actual UI status; integrated commits=%0d count=%0d payload=%0d image_pixels=%0d bg_reads=%0d bg_writes=%0d",commits,dut.control.count,payload_checks,pixel_checks,bg_reads,bg_writes);
   $finish;
  end
 join
end
initial begin #2000000000;$fatal(1,"timeout");end
endmodule
