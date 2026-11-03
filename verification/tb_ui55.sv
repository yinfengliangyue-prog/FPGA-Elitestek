`timescale 1ns/1ps
module tb_ui55;reg [1:0] page=0;
reg clk=0;always #5 clk=~clk;reg rn=0,ide=0,ivs=0,ihs=0;
reg [47:0] irgb=48'h406080406080;reg [2:0] app=0,ma=0,mb=2;reg opened=0,edit=0,confirm=0,aux=1;
reg pair_lock=0;reg showfps=0;reg [9:0] camera_fps=7,video_fps=91;reg fps_good=0;reg [4:0] cursor=0;reg la=1,lb=1,activity=0;reg [2:0] context_code=0;wire [47:0] rgb;wire de,hs,vs;
ui55 #(.HINT_FRAMES(300)) dut(
.frame_locked(pair_lock),
.recognition_run(1'b0),.rec_text(256'd0),.rec_boxes(160'd0),.rec_count(3'd0),.rec_holding(1'b0),.rec_ready(1'b0),
.frame_page(page),.frame_speed(2'd1),.frame_playing(1'b0),.frame_recording(1'b0),.frame_selected(1'b0),.frame_count(8'd120),.frame_a(8'd1),.frame_b(8'd120),.frame_delta(16'd1990),.wb_qr(12'd320),.wb_qg(12'd158),.wb_qb(12'd329),
.clk(clk),.rst_n(rn),.rgb_in(irgb),.de_in(ide),.hs_in(ihs),.vs_in(ivs),.app_mode(app),.mode_a(ma),.mode_b(mb),.selected_b(1'b0),.same_frame(1'b0),
.live_a(la),.live_b(lb),.live_group(1'b1),.wb_locked(1'b0),.shape_locked(1'b0),.effective_high(8'd6),.effective_low(8'd3),.denoise_active(1'b1),
.settings_open(opened),.editing(edit),.confirm_reset(confirm),.menu_cursor(cursor),.aux_visible(aux),.osd_detail(1'b0),.fps_show(showfps),.fps_cam(camera_fps),.fps_vid(video_fps),.fps_valid(fps_good),
.activity(activity),.context_code(context_code),.image_valid(1'b1),.rgb_out(rgb),.de_out(de),.hs_out(hs),.vs_out(vs));
reg [11:0] fx=0,fy=0;reg [34:0] bits;reg [23:0] p;integer fd,x,y,i;
task frame;begin ide=0;@(negedge clk);ivs=1;repeat(3)@(negedge clk);ivs=0;repeat(3)@(negedge clk);end endtask
task point(input integer xx,yy);begin fx=xx;fy=yy;ide=1;#1;end endtask
task preview(input string name);
begin
fd=$fopen({"verification/",name,".ppm"},"wb");$fwrite(fd,"P6\n1920 1080\n255\n");
for(y=0;y<1080;y++)for(x=0;x<1920;x+=2)begin
fx=x;fy=y;ide=1;#1;bits=dut.glyph(dut.ch);
p=dut.ink_region&&bits[34-(dut.gr*5+dut.col)]?dut.ink_color:dut.base[23:0];
$fwrite(fd,"%c%c%c%c%c%c",p[23:16],p[15:8],p[7:0],p[23:16],p[15:8],p[7:0]);end
$fclose(fd);ide=0;
end endtask
initial begin
repeat(4)@(negedge clk);rn=1;frame;
force dut.x=fx;force dut.y=fy;force dut.oldde=1;
point(800,500);if(dut.base!==irgb||dut.ink_region)$fatal(1,"FULL default image covered");
preview("full_clean");
opened=1;frame;point(1500,200);if(dut.base!=={2{24'h20242a}})$fatal(1,"settings card missing");
preview("full_settings");
for(i=0;i<8;i++)frame;if(!dut.opened)$fatal(1,"menu timed out");
ma=2;cursor=0;edit=1;frame;
if(dut.item_text(8)!="GLOBAL H          006           ")$fatal(1,"effective threshold value %s",dut.item_text(8));
preview("threshold_edit");
app=3;opened=0;edit=0;cursor=0;frame;
if(dut.menu_count(3,1,0)!=13||dut.menu_item(3,0,1,0)!=8||dut.menu_item(3,1,1,0)!=9||dut.menu_item(3,2,1,0)!=10||dut.menu_item(3,3,1,0)!=15||dut.menu_item(3,4,1,0)!=16||dut.menu_item(3,12,1,0)!=14)$fatal(1,"EXPR Canny contextual H/L/DN/AUX/RESULT/restore menu");
point(576,156);if(dut.base!=={2{24'hffffff}})$fatal(1,"EXPR production ROI");
point(32,128);if(dut.base!==irgb||dut.ink_region)$fatal(1,"removed digit preview remains");
point(32,80);if(dut.txt!=="EXPR ?                          ")$fatal(1,"EXPR fabricated result");
if(dut.app_title(3)!="EXPR 4/4                        ")$fatal(1,"four-app title");
opened=1;cursor=1;frame;
if(dut.item_text(16)!="RESULT            OFF           ")$fatal(1,"expression OFF binding");
opened=0;aux=0;frame;point(576,156);if(dut.base!==irgb)$fatal(1,"aux off retains ROI");
point(32,80);if(dut.txt!=="EXPR ?                          ")$fatal(1,"aux hides expression answer");
aux=1;frame;preview("expression_off");
app=1;opened=1;page=2;cursor=13;frame;if(dut.scroll!=8)$fatal(1,"6-row menu scroll");
point(32,936);if(dut.txt!="A001 B120 N120 DT01990MS        ")$fatal(1,"frame/time labels shifted: %s",dut.txt);
preview("compare_settings");
page=0;frame;point(32,936);if(dut.txt!="LIVE DONE 120/120               ")$fatal(1,"record status label shifted: %s",dut.txt);page=2;frame;
// LIVE pin is visible and remains independent of recording progress.
page=0;pair_lock=1;frame;point(32,968);if(dut.txt!=="LIVE A+B LOCKED                 ")$fatal(1,"LIVE pair hold status");
if(dut.item_text(28)!="LOCK A+B          ON            "||dut.menu_item(1,8,1,0)!=28||dut.menu_count(1,1,0)!=17||dut.menu_item(1,5,0,0)!=28||dut.menu_count(1,0,0)!=14)$fatal(1,"LOCK A+B row/count/value");
opened=1;cursor=8;ma=2;mb=4;frame;preview("frame_pair_locked_settings");
pair_lock=0;page=2;frame;
// Explicit close removes the card and help on the next display frame.
opened=0;frame;point(1500,200);if(dut.base!==irgb)$fatal(1,"close leaves card/help");
// The FPS setting shows the fixed display rate, independent of measurements.
showfps=1;frame;point(1512,1040);
if(dut.txt!=="DISPLAY FPS 60                  ")$fatal(1,"fixed display FPS missing when input invalid");
camera_fps=240;video_fps=1;fps_good=1;frame;point(1512,1040);
if(dut.txt!=="DISPLAY FPS 60                  ")$fatal(1,"FPS is still affected by measurement inputs");
preview("display_fps60");showfps=0;frame;point(1512,1040);if(dut.text_region)$fatal(1,"FPS OFF retains text");
// Check actual two-stage output against the combinational overlay, RGB and controls.
point(800,500);@(negedge clk);irgb=48'h112233445566;ihs=1;repeat(2)@(negedge clk);
if(rgb!==irgb||!de||!hs)$fatal(1,"UI pipeline RGB/control alignment");
ide=0;context_code=0;activity=~activity;repeat(3)@(negedge clk);frame;
if(dut.hint_left!=300)$fatal(1,"5s hint initial count");repeat(299)frame;
if(dut.hint_left!=1)$fatal(1,"hint disappeared before 300 display frames");frame;if(dut.hint_left!=0)$fatal(1,"hint did not finish at 5s");
release dut.x;release dut.y;release dut.oldde;
$display("PASS UI55_CONTEXTUAL actual RTL previews; clean FULL; persistent card; effective H/L; 6-row scroll; frame-atomic close; EXPR exact ROI/heading/search geometry; independent NUMBER title/preview removed; auxiliary-only hide; two-stage RGB/control alignment; 300 display frames/5s hint counter; fixed DISPLAY FPS60 independent of invalid/arbitrary measurement inputs");$finish;
end
initial begin #100000000;$fatal(1,"UI timeout");end
endmodule
