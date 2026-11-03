`timescale 1ns/1ps
`include "verification/golden_ui55.vh"
module tb_menu_identity56;reg [1:0] page=0;
reg clk=0;always #5 clk=~clk;reg rn=0,ide=0,ivs=0,ihs=0;
reg [47:0] irgb=48'h406080406080;reg [2:0] app=0,ma=0,mb=2;reg opened=0,edit=0,confirm=0,aux=1;
reg [4:0] cursor=0;reg la=1,lb=1,activity=0;reg [2:0] context_code=0;wire [47:0] rgb;wire de,hs,vs;
ui55 #(.HINT_FRAMES(300)) dut(
.frame_locked(1'b0),
.recognition_run(1'b0),.rec_text(256'd0),.rec_boxes(160'd0),.rec_count(3'd0),.rec_holding(1'b0),.rec_ready(1'b0),
.frame_page(page),.frame_speed(2'd1),.frame_playing(1'b0),.frame_recording(1'b0),.frame_selected(1'b0),.frame_count(8'd120),.frame_a(8'd1),.frame_b(8'd120),.frame_delta(16'd1990),.wb_qr(12'd320),.wb_qg(12'd158),.wb_qb(12'd329),
.clk(clk),.rst_n(rn),.rgb_in(irgb),.de_in(ide),.hs_in(ihs),.vs_in(ivs),.app_mode(app),.mode_a(ma),.mode_b(mb),.selected_b(1'b0),.same_frame(1'b0),
.live_a(la),.live_b(lb),.live_group(1'b1),.wb_locked(1'b0),.shape_locked(1'b0),.effective_high(8'd6),.effective_low(8'd3),.denoise_active(1'b1),
.settings_open(opened),.editing(edit),.confirm_reset(confirm),.menu_cursor(cursor),.aux_visible(aux),.osd_detail(1'b0),.fps_show(1'b0),.fps_cam(10'd30),.fps_vid(10'd60),.fps_valid(1'b1),
.activity(activity),.context_code(context_code),.image_valid(1'b1),.rgb_out(rgb),.de_out(de),.hs_out(hs),.vs_out(vs));
golden_ui55 #(.HINT_FRAMES(300)) golden(
.frame_page(page),.frame_speed(2'd1),.frame_playing(1'b0),.frame_recording(1'b0),.frame_selected(1'b0),.frame_count(8'd120),.frame_a(8'd1),.frame_b(8'd120),.frame_delta(16'd1990),.wb_qr(12'd320),.wb_qg(12'd158),.wb_qb(12'd329),
.clk(clk),.rst_n(rn),.rgb_in(irgb),.de_in(ide),.hs_in(ihs),.vs_in(ivs),.app_mode(app),.mode_a(ma),.mode_b(mb),.selected_b(1'b0),.same_frame(1'b0),
.live_a(la),.live_b(lb),.live_group(1'b1),.wb_locked(1'b0),.shape_locked(1'b0),.effective_high(8'd6),.effective_low(8'd3),.denoise_active(1'b1),
.settings_open(opened),.editing(edit),.confirm_reset(confirm),.menu_cursor(cursor),.aux_visible(aux),.osd_detail(1'b0),.fps_show(1'b0),.fps_cam(10'd30),.fps_vid(10'd60),.fps_valid(1'b1),
.activity(activity),.context_code(context_code),.image_valid(1'b1),.rgb_out(),.de_out(),.hs_out(),.vs_out());

reg [11:0] fx=0,fy=0;reg [23:0] actual,expected;reg [34:0] bits_a,bits_b;integer state,x,y,checks=0;
task frame;begin ide=0;@(negedge clk);ivs=1;repeat(3)@(negedge clk);ivs=0;repeat(3)@(negedge clk);end endtask
task compare_point(input integer xx,yy);begin
 fx=xx;fy=yy;ide=1;#1;
 bits_a=dut.glyph(dut.ch);bits_b=golden.glyph(golden.ch);
 actual=dut.ink_region&&bits_a[34-(dut.gr*5+dut.col)]?dut.ink_color:dut.base[23:0];
 expected=golden.ink_region&&bits_b[34-(golden.gr*5+golden.col)]?golden.ink_color:golden.base[23:0];
 // The user-requested enable switch replaces only RESULT LIVE with OFF/ON.
 if(!(app>=3&&opened&&xx>=1720&&xx<1768&&yy>=216&&yy<230))begin
  if(actual!==expected)$fatal(1,"FINAL04 menu difference state=%0d xy=%0d,%0d actual=%h original=%h",state,xx,yy,actual,expected);checks+=2;
 end
end endtask
initial begin
 repeat(4)@(negedge clk);rn=1;frame;
 force dut.x=fx;force dut.y=fy;force dut.oldde=1;
 force golden.x=fx;force golden.y=fy;force golden.oldde=1;
 for(state=0;state<9;state++)begin
  case(state)
   0:begin app=0;ma=0;page=0;end 1:begin app=0;ma=2;end
   2:begin app=1;ma=0;mb=0;page=0;end 3:begin app=1;mb=2;end
   4:begin app=1;page=1;end 5:begin app=1;page=2;end
   6:app=2;7:app=3;8:app=4;
  endcase
  opened=1;cursor=0;frame;
  for(y=160;y<432;y++)for(x=1496;x<1896;x+=2)compare_point(x,y);
  if(state<7)begin cursor=8;edit=1;frame;
   for(y=160;y<432;y++)for(x=1496;x<1896;x+=2)compare_point(x,y);
  end
  edit=0;cursor=0;opened=0;frame;
  if(state>=7)for(y=0;y<212;y++)for(x=0;x<800;x+=2)compare_point(x,y);
 end
 $display("PASS MENU_IDENTITY56 %0d pixels against unmodified FINAL04 UI; nine contexts, full settings card, editing, scroll, disabled NUMBER/EXPR headings. Only specified RESULT OFF/ON value differs.",checks);$finish;
end
endmodule
