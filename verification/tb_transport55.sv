`timescale 1ns/1ps
module tb_transport55;
localparam W=1920,H=1080,HT=1100,VT=1125,HB=96,VB=41,HS=22,VS=5,FRAMES=4;
localparam A=32'h01000000,B=32'h02000000;
reg vc=0,pc=0,ac=0;always #6.734 vc=~vc;always #3.367 pc=~pc;always #5 ac=~ac;
reg rst=0;reg [2:0] app=1,ma=0,mb=2;reg selected=0;
wire [2:0] fa,fma,fmb;wire [47:0] pre,rgb;wire pd,ph,pv,de,hs,vs,ft,fs,pop,empty,uf,busy,rf;
wire [127:0] head;wire [31:0] araddr;wire [7:0] arlen;wire arvalid,rready;
reg arready=0,rvalid=0,rlast=0;reg [127:0] rdata=0;
reg [1:0] ft_sync=0,ack_sync=0;reg ft_seen=0,start=0,ack=0;
reg frame_selected=0;wire [31:0] addr_left=fa==1?A:frame_selected?B:A,addr_right=fa==1?B:frame_selected?B:A;
wire [23:0] hdmi_rgb;wire hdmi_de,hdmi_hs,hdmi_vs,gear_fault;
raster55 #(.W(W),.H(H),.HT(HT),.VT(VT),.HB(HB),.VB(VB),.HS(HS),.VS(VS)) display(
.clk(vc),.rst_n(rst),.ready(1'b1),.ack_toggle(ack_sync[1]),.app_mode(app),.mode_a(ma),.mode_b(mb),.frame_page(2'd2),.frame_count(8'd120),.tag_a(3'd0),.tag_b(3'd0),.aux_visible(1'b1),.shape_locked(1'b0),
.frame_toggle(ft),.fifo_reset(fs),.empty(empty),.head(head),.pop(pop),.rgb(pre),.de(pd),.hs(ph),.vs(pv),.underflow(uf),.frame_tick(),.display_valid(),.frame_app(fa),.frame_ma(fma),.frame_mb(fmb));
ui55 #(.W(W),.H(H),.HINT_FRAMES(0)) ui(
.frame_locked(1'b0),
.recognition_run(1'b0),.rec_text(256'd0),.rec_boxes(160'd0),.rec_count(3'd0),.rec_holding(1'b0),.rec_ready(1'b0),
.clk(vc),.rst_n(rst),.rgb_in(pre),.de_in(pd),.hs_in(ph),.vs_in(pv),.app_mode(3'd0),.mode_a(3'd0),.mode_b(3'd0),.selected_b(1'b0),.same_frame(1'b0),.live_a(1'b1),.live_b(1'b1),.live_group(1'b1),.wb_locked(1'b0),.shape_locked(1'b0),
.effective_high(8'd6),.effective_low(8'd3),.denoise_active(1'b1),.settings_open(1'b0),.editing(1'b0),.confirm_reset(1'b0),.menu_cursor(5'd0),.aux_visible(1'b1),.osd_detail(1'b0),.fps_show(1'b0),.fps_cam(10'd30),.fps_vid(10'd60),.fps_valid(1'b1),.activity(1'b0),.context_code(3'd0),.image_valid(1'b1),
.frame_page(2'd0),.frame_speed(2'd1),.frame_playing(1'b0),.frame_recording(1'b0),.frame_selected(1'b0),.frame_count(8'd120),.frame_a(8'd1),.frame_b(8'd120),.frame_delta(16'd1990),.wb_qr(12'd320),.wb_qg(12'd158),.wb_qb(12'd329),.rgb_out(rgb),.de_out(de),.hs_out(hs),.vs_out(vs));
reader55 #(.W(W),.H(H),.FIFO_DEPTH(512),.BURST(127)) reader(
.clk(ac),.rst_n(rst),.start(start),.abort(1'b0),.swap_sides(1'b0),.fullscreen(1'b0),.selected_b(1'b0),.addr_a(addr_left),.addr_b(addr_right),.busy(busy),.video_clk(vc),.fifo_reset(fs),.pop(pop),.empty(empty),.head(head),.fault(rf),
.araddr(araddr),.arlen(arlen),.arvalid(arvalid),.arready(arready),.rdata(rdata),.rresp(2'd0),.rvalid(rvalid),.rlast(rlast),.rready(rready));
hdmi_gearbox40 gearbox(.pair_clk(vc),.pixel_clk(pc),.arst_n(rst),.rgb_pair(rgb),.de_pair(de),.hs_pair(hs),.vs_pair(vs),.rgb(hdmi_rgb),.de(hdmi_de),.hs(hdmi_hs),.vs(hdmi_vs),.fault(gear_fault));
integer started=0;
always @(posedge ac)begin
 if(!rst)begin ft_sync<=0;ft_seen<=0;start<=0;ack<=0;end
 else begin ft_sync<={ft_sync[0],ft};start<=0;
 if(ft_sync[1]!=ft_seen)begin
 if(busy)$fatal(1,"reader missed frame boundary");ft_seen<=ft_sync[1];
 if(started<FRAMES)begin start<=1;ack<=~ack;started++;end
 end end end
always @(posedge vc)if(!rst)ack_sync<=0;else ack_sync<={ack_sync[0],ack};
function automatic [31:0] payload(input integer bank,col,row);
reg [4:0] rr,gg;reg [3:0] bb;reg [7:0] bal,clean;begin
rr=(col+bank*7)%32;gg=(row+bank*5)%32;bb=(col+row+bank*3)%16;
bal=(col*3+row+bank)%256;clean=(col+row*9+bank)%256;
payload={bal,clean,1'b1,1'b1,rr,gg,bb};end endfunction
function automatic [127:0] memory_word(input integer address);
integer bank,offset,pi;begin
bank=address>=B;offset=address-(bank?B:A);pi=offset/4;
memory_word={payload(bank,pi%(W/2),pi/(W/2)),payload(bank,(pi+1)%(W/2),(pi+1)/(W/2)),payload(bank,(pi+2)%(W/2),(pi+2)/(W/2)),payload(bank,(pi+3)%(W/2),(pi+3)/(W/2))};end endfunction
function automatic [23:0] color(input [31:0] p);color={p[13:9],p[13:11],p[8:4],p[8:6],p[3:0],p[3:0]};endfunction
bit reading=0;integer address=0,words=0,idx=0,bursts=0,returned=0,stalls=0;reg [31:0] held_ar;reg [7:0] held_len;bit was_stalled=0;
integer rng=32'h55a12bcd;
always @(negedge ac)begin
rng=(rng<<1)^((rng<0)?32'h04c11db7:0);arready=rst&&!reading&&(rng[2:0]!=0);
if(!rvalid&&reading&&rng[7:3]!=0)begin rdata=memory_word(address+idx*16);rlast=idx==words-1;rvalid=1;end end
always @(posedge ac)if(rst)begin
if(was_stalled&&(!arvalid||araddr!==held_ar||arlen!==held_len))$fatal(1,"AR changed under stall");
was_stalled=arvalid&&!arready;held_ar=araddr;held_len=arlen;if(was_stalled)stalls++;
if(arvalid&&arready)begin
if(reading||araddr[3:0]||arlen>127||araddr[11:0]+((int'(arlen)+1)*16)>4096)$fatal(1,"AXI burst/4K");
reading=1;address=araddr;words=int'(arlen)+1;idx=0;bursts++;end
if(rvalid&&rready)begin
if(!reading||rlast!==(idx==words-1))$fatal(1,"R framing");idx++;returned++;rvalid<=0;if(rlast)begin reading=0;rlast<=0;end end end
integer frame=-1,head_checks=0,pixels=0,cycles=0,sx,sy,bank,basecol;
reg [50:0] expected[0:2],now_pair;reg [47:0] ergb;
reg [2:0] old_app,old_ma,old_mb;
always @(posedge vc)if(rst)begin
if(display.frame_tick)begin frame++;frame_selected=selected;old_app=app;old_ma=ma;old_mb=mb;end
else if({fa,fma,fmb}!=={old_app,old_ma,old_mb})$fatal(1,"mode changed mid-frame");
ergb=display.active?{2{24'h101010}}:48'd0;
if(display.image_area)begin
ergb=0;
if(display.frame_ok)begin
if(empty)$fatal(1,"underflow f=%0d xy=%0d,%0d",frame,display.xbeat,display.y);
if(fa==1)begin bank=display.right;sx=(display.xbeat%(W/4))*2;sy=display.y-H/4;end
else begin bank=frame_selected;sx=display.xbeat;sy=display.y/2;end
basecol=(sx/4)*4;
if(head!=={payload(bank,basecol,sy),payload(bank,basecol+1,sy),payload(bank,basecol+2,sy),payload(bank,basecol+3,sy)})$fatal(1,"head32 order f=%0d xy=%0d,%0d",frame,sx,sy);
ergb=fa==1?{color(payload(bank,sx+1,sy)),color(payload(bank,sx,sy))}:{2{color(payload(bank,sx,sy))}};
head_checks++;
end end
now_pair={ergb,display.active,display.h<HS,display.v<VS};
expected[2]=expected[1];expected[1]=expected[0];expected[0]=now_pair;
#2;
if(cycles>=2)begin
if({rgb,de,hs,vs}!==expected[2])$fatal(1,"raster/UI phase f=%0d cyc=%0d actual=%h expected=%h",frame,cycles,{rgb,de,hs,vs},expected[2]);if(de)pixels+=2;end
cycles++;
end
always @(negedge vc)if(rst&&display.h==300&&display.v==500)case(frame)
0:begin app=1;selected=1;ma=4;mb=2;end
1:begin app=0;selected=0;ma=2;mb=4;end
2:begin app=0;selected=1;ma=4;mb=2;end
endcase
reg [26:0] gp[0:255];integer gw=0,gr=0,gear_pixels=0,gear_active=0;
always @(posedge vc)if(rst&&gearbox.pair_reset[1]&&!gearbox.full)begin
gp[gw%256]<={rgb[23:0],de,hs,vs};gp[(gw+1)%256]<={rgb[47:24],de,hs,vs};gw+=2;if(gw-gr>250)$fatal(1,"gear queue overflow");end
reg started_old,upper_old,empty_old;
always @(posedge pc)begin started_old=gearbox.started;upper_old=gearbox.upper;empty_old=gearbox.empty;#1;
if(rst&&started_old&&(upper_old||!empty_old))begin
if(gr>=gw||{hdmi_rgb,hdmi_de,hdmi_hs,hdmi_vs}!==gp[gr%256])$fatal(1,"gear lane/control pixel %0d",gr);
gr++;gear_pixels++;if(hdmi_de)gear_active++;end end
initial begin
repeat(8)@(negedge vc);rst=1;wait(frame==FRAMES);repeat(HT*4)@(negedge vc);
if(uf||rf||gear_fault||head_checks!=3*W*H/2||pixels!=W*H*FRAMES||gear_active!=W*H*FRAMES||returned!=FRAMES*W*H/8)$fatal(1,"coverage heads=%0d px=%0d hdmi=%0d words=%0d fault=%b%b%b",head_checks,pixels,gear_active,returned,uf,rf,gear_fault);
$display("PASS TRANSPORT55_HD 4x1920x1080 frames, fixed A/B and full A/full B, %0d exact head checks, %0d active pixels, %0d HDMI pixel/control cycles, %0d AXI bursts/%0d words/%0d AR stalls; synthetic annotation colors bypass algorithm; real reader32/raster55/UI2stage/gearbox",head_checks,pixels,gear_pixels,bursts,returned,stalls);$finish;end
initial begin #100000000;$fatal(1,"transport timeout");end
endmodule
