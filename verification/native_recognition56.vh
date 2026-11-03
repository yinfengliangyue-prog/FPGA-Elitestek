// Preserve the production 768x768 ROI and 192x192 occupancy grid. Only the
// white outer camera margins are cropped to keep this algorithm/UI test fast.
module `NATIVE_MODULE;
reg clk=0;always #6.734 clk=~clk;reg rn=0,de=0,hs=0,vs=0,enable=1;reg [47:0] rgb=0;
localparam W=832,H=800,HT=556,VT=845,RX=32,RY=16;
`ifdef NATIVE_DIGIT
localparam EXPR=0,APP=3;
`else
localparam EXPR=1,APP=3;
`endif
`ifdef NATIVE_CANNY
localparam EXTERNAL=1;
wire [15:0] shared_edges;wire cde,cvalid,chs,cvs;
canny_stream_2ppc #(.IMG_W(W),.IMG_H(H),.H_TOTAL_BEATS(HT),.ORIGINAL_ENABLE(0)) shared_core(
 .clk(clk),.rst_n(rn),.rgb_x2_in(rgb),.de_in(de),.valid_in(de),.hsync_in(hs),.vsync_in(vs),
 .threshold_in(8'd10),.threshold_low_in(8'd5),.noise_in(4'd8),.exposure_level_in(2'd0),
 .edge_x2_out(shared_edges),.de_out(cde),.valid_out(cvalid),.hsync_out(chs),.vsync_out(cvs));
reg [7:0] canny_reference[0:W*H-1];integer cx=0,cy=0,edge_checks=0,red_count=0;reg cdd=0,cvd=0;
wire [11:0] cpx=cdd?cx:0;
always @(posedge clk)if(rn)begin
 cdd<=cde;cvd<=cvs;
 if(cvd&&!cvs)begin cx<=0;cy<=0;end
 else if(cde)begin
  if(shared_edges!=={canny_reference[cy*W+cpx+1],canny_reference[cy*W+cpx]})$fatal(1,"Canny10/5 differs from independent frame model xy=%0d,%0d",cpx,cy);
  cx<=cpx+2;edge_checks+=2;if(shared_edges!=0)red_count++;
 end else if(cdd)begin cx<=0;cy<=cy+1;end
end
`else
localparam EXTERNAL=0;
wire [15:0] shared_edges=0;wire cde=de,cvalid=de,chs=hs,cvs=vs;
`endif
wire [3:0] digit;wire [783:0] preview;wire [32:0] box;
wire [255:0] text;wire [159:0] boxes;wire [2:0] count;wire holdlast,ready,detected;
number_video_pipeline #(.IMG_W(W),.IMG_H(H),.H_TOTAL_BEATS(HT),.ROI_SIZE(768),.ROI_X(RX),.ROI_Y(RY),.PANEL_SWAP_RB_ON_EDGE(0),.EXTERNAL_EDGES(EXTERNAL)) dut(
 .clk(clk),.rst_n(rn&&enable),.enable(enable),.expression_mode(1'(EXPR)),.lock_pulse(1'b0),.rgb_in(rgb),.de_in(cde),.valid_in(cvalid),.hs_in(chs),.vs_in(cvs),.threshold_in(8'd2),.external_edge_bits(shared_edges),
 .rgb_out(),.de_out(),.valid_out(),.hs_out(),.vs_out(),.enabled_frame(),.detected_frame(detected),.ui_expression_locked(),
 .ui_digit(digit),.ui_preview(preview),.ui_box(box),.ui_expr_text(text),.ui_expr_boxes(boxes),.ui_expr_count(count),.ui_expr_holding(holdlast),.ui_expr_ready(ready));
ui55 ui(
.frame_locked(1'b0),
 .recognition_run(enable),.rec_text(text),.rec_boxes(boxes),.rec_count(count),.rec_holding(holdlast),.rec_ready(ready),
 .clk(clk),.rst_n(rn),.rgb_in(rgb),.de_in(de),.hs_in(hs),.vs_in(vs),.app_mode(3'(APP)),.mode_a(3'd0),.mode_b(3'd0),.selected_b(1'b0),.same_frame(1'b0),
 .live_a(1'b1),.live_b(1'b1),.live_group(1'b1),.wb_locked(1'b0),.shape_locked(1'b0),.effective_high(8'd6),.effective_low(8'd3),.denoise_active(1'b1),
 .settings_open(1'b1),.editing(1'b0),.confirm_reset(1'b0),.menu_cursor(5'd1),.frame_page(2'd0),.frame_speed(2'd1),.frame_playing(1'b0),.frame_recording(1'b1),.frame_selected(1'b0),
 .frame_count(8'd0),.frame_a(8'd0),.frame_b(8'd0),.frame_delta(16'd0),.wb_qr(12'd320),.wb_qg(12'd158),.wb_qb(12'd329),
 .aux_visible(1'b1),.osd_detail(1'b0),.fps_show(1'b0),.fps_cam(10'd30),.fps_vid(10'd60),.fps_valid(1'b1),.activity(1'b0),.context_code(3'd0),.image_valid(1'b1),.rgb_out(),.de_out(),.hs_out(),.vs_out());
reg [7:0] images[0:1920*1080-1],expected[0:5*784-1],rawboxes[0:19];reg [3:0] labels[0:4];
integer bits_checked=0,nn=0,observations=0,starts=0,row,col,f,i;reg [11:0] fx=0,fy=0;
always @(posedge clk)if(rn&&enable)begin
 if(dut.we)begin
`ifndef NATIVE_DIGIT
  if(dut.bit_in!==(expected[dut.token_index*784+dut.addr]!=0))$fatal(1,"native ROI normalization differs from34");
`endif
  bits_checked++;
 end
 if(dut.start)begin
`ifndef NATIVE_DIGIT
  i=dut.token_index*4;
  if({dut.sel_x0,dut.sel_x1,dut.sel_y0,dut.sel_y1}!=={rawboxes[i],rawboxes[i+1],rawboxes[i+2],rawboxes[i+3]})$fatal(1,"native original boxes differ");
`endif
  starts++;
 end
 if(dut.nn_done)begin
`ifdef NATIVE_DIGIT
  if(dut.number!=1||dut.margin<300)$fatal(1,"single digit1 inference");
`else
  if(labels[dut.token_index]<10)begin if(dut.number!=labels[dut.token_index]||dut.margin<300)$fatal(1,"native digit");end
  else if(dut.operator_symbol!=10)$fatal(1,"native operator");
`endif
  nn++;
 end
 if(dut.expr_done)observations++;
end
function [23:0] pixel(input integer xx,yy);reg [7:0] v;begin v=images[(yy+140)*1920+xx+544];pixel={v,v,v};end endfunction
task frame;begin
 for(row=0;row<VT;row++)for(col=0;col<HT;col++)begin
  @(negedge clk);hs=col<22;vs=row<5;de=col>=96&&col<96+W/2&&row>=41&&row<41+H;
  rgb=de?{pixel((col-96)*2+1,row-41),pixel((col-96)*2,row-41)}:0;
 end
end endtask
initial begin
`ifdef NATIVE_DIGIT
 $readmemh("verification/digit56_images.mem",images);
`else
`ifdef NATIVE_CANNY
 $readmemh("verification/expr_canny06_images.mem",images);
`else
 $readmemh("verification/number/expression_hd_images.mem",images);
`endif
`endif
`ifdef NATIVE_CANNY
 $readmemh("verification/expr_canny06_expected.mem",expected);$readmemh("verification/expr_canny06_boxes.mem",rawboxes);
 $readmemh("verification/expr_canny06_edges.mem",canny_reference);
`else
 $readmemh("verification/number/expression_hd_padding_expected.mem",expected);$readmemh("verification/number/expression_hd_boxes.mem",rawboxes);
`endif
 labels[0]=1;labels[1]=2;labels[2]=10;labels[3]=3;labels[4]=4;
 repeat(8)@(negedge clk);rn=1;
 for(f=0;f<20&&(f<4||!(EXPR?ready:digit==1));f++)frame;
 if(!detected)$fatal(1,"native ROI result never ready");frame;
 if(!ui.rec_on||ui.item_text(16)!="RESULT            ON            ")$fatal(1,"actual result menu binding");
`ifdef NATIVE_DIGIT
 if(ui.digit!=1||!ui.nbox[32]||ui.preview==0||nn<3)$fatal(1,"actual digit/box/preview publication");
`else
 if(!ui.rec_ok||ui.expression_text!=="12+34=46                        "||bits_checked<3*5*784||observations<3||nn<15)$fatal(1,"actual expression metadata publication");
`endif
 // Render the production full-HD UI coordinates from this real result bus.
 de=1;force ui.x=fx;force ui.y=fy;force ui.oldde=1;fx=32;fy=32;#1;
`ifdef NATIVE_DIGIT
 if(ui.txt!="NUMBER 1                        ")$fatal(1,"NUMBER1 heading layout");
 fx=576+ui.nbox[31:24]*4;fy=156+ui.nbox[15:8]*4;#1;
 if(ui.base!={2{24'h00ff00}})$fatal(1,"number bbox mapped incorrectly");
`else
 if(ui.txt!="EXPR LIVE READY                 ")$fatal(1,"READY heading layout");
 fx=32;fy=80;#1;if(ui.txt!=="12+34=46                        ")$fatal(1,"expression answer layout");
 fx=576+ui.expression_boxes[31:24]*4;fy=156+ui.expression_boxes[15:8]*4;#1;
 if(ui.base!={2{24'h00ff00}})$fatal(1,"expression box byte order/mapping");
`endif
 release ui.x;release ui.y;release ui.oldde;de=0;enable=0;frame;
 if(ui.rec_on||detected)$fatal(1,"OFF retains recognition");
`ifdef NATIVE_CANNY
 if(edge_checks<3*W*H||red_count<100)$fatal(1,"Canny oracle coverage");
 $display("PASS EXPR_CANNY06 shared full-resolution Canny H10/L5, independent oracle %0d pixels, positive edge pairs %0d, exact normalized bits %0d, true12+34=46 with %0d NN/%0d analyses, actual UI/result and OFF clearing",edge_checks,red_count,bits_checked,nn,observations);
`endif
 $display("PASS NATIVE_RECOGNITION56 app=%0d production 768x768 ROI /192x192 grid, real Sobel+continuity+preprocess+MLP, normalized_bits=%0d starts=%0d NN=%0d expressions=%0d; real UI heading/answer/preview/green-box/RESULT mapping and OFF clearing; outer white margins cropped only",APP,bits_checked,starts,nn,observations);$finish;
end
initial begin #400000000;$fatal(1,"native recognition timeout");end
endmodule
