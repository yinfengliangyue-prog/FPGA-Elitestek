// User-selected second2.2 geometry and color maps, fed by user-selected Canny.
module golden_recognition56 #(parameter UI_V2=0,W=1920,H=1080,HT=1066)(
 input wire clk,rst_n,shape_enable,number_enable,
 input wire aux_visible,shape_lock_request,
 output wire shape_locked,shape_result_valid,output wire [2:0] capture_tag,
 input wire [47:0] rgb_in,input wire [15:0] edges,number_edges,mag,accepted,input wire de,hs,vs,
 output wire [47:0] rgb_out,output wire [1:0] overlay_mask,
 output reg [15:0] mag_out,accepted_out,output wire de_out,hs_out,vs_out
);
 localparam ROI=(W>=768&&H>=768)?768:((W<H?W:H)/4*4);
 localparam RX=((W-ROI)/8)*4,RY=((H-ROI)/8)*4;
 wire [47:0] number_rgb,colored;wire [1:0] number_mask;
 reg num_on,shape_on,vs_old,aux_on;
 assign capture_tag={shape_on,aux_on,shape_locked};reg [1:0] mask_d,number_mask_d;reg [47:0] number_rgb_d;
 wire sof=vs_old&&!vs;
 always @(posedge clk)begin
 if(!rst_n)begin aux_on<=1;num_on<=0;shape_on<=0;vs_old<=0;mask_d<=0;number_mask_d<=0;number_rgb_d<=0;mag_out<=0;accepted_out<=0;end
 else begin
  vs_old<=vs;if(sof)begin num_on<=UI_V2?1'b0:number_enable;shape_on<=shape_enable;aux_on<=UI_V2?aux_visible:1'b1;end
  mag_out<=mag;accepted_out<=accepted;
  number_mask_d<=number_mask;number_rgb_d<=number_rgb;
  mask_d<=number_mask|{shape_on&&aux_on&&edges[15:8]!=0,shape_on&&aux_on&&edges[7:0]!=0};
 end end
 golden_number_annotation56 #(.IMG_W(W),.IMG_H(H),.ROI_SIZE(ROI),.ROI_X(RX),.ROI_Y(RY),.H_TOTAL_BEATS(HT),.PANEL_SWAP_RB_ON_EDGE(0)) number(
 .clk(clk),.rst_n(rst_n),.enable(num_on),.rgb_in(rgb_in),.canny_edges(number_edges),
 .de_in(de),.valid_in(de),.hs_in(hs),.vs_in(vs),.rgb_out(number_rgb),.overlay_mask(number_mask),
 .de_out(),.valid_out(),.hs_out(),.vs_out(),.enabled_frame(),.detected_frame());
 wire [2:0] types;wire ready,ack,cstart,cwrite;wire [7:0] cx,cy,qx,qy;wire [1:0] cc,nearby;
 shape_contour_detector #(.IMG_W(W),.IMG_H(H)) detector(
 .clk(clk),.rst_n(rst_n),.enable(shape_on),.edge_bits(edges),.de(de),.valid(de),.vs(vs),
 .pending_types(types),.result_ready(ready),.result_ack(ack),.done(),.busy(),
 .color_start(cstart),.color_write(cwrite),.color_x(cx),.color_y(cy),.color_class(cc),
 .color_query_x(qx),.color_query_y(qy),.color_neighbor_class(nearby));
 shape_color_overlay #(.IMG_W(W),.IMG_H(H),.PANEL_SWAP_RB_ON_EDGE(0)) color_overlay(
 .clk(clk),.rst_n(rst_n),.enable(shape_on),.rgb_in(number_rgb),.edge_bits(shape_on&&aux_on?edges:16'd0),
 .de(de),.valid(de),.hs(hs),.vs(vs),.color_start(cstart),.color_write(cwrite),.color_x(cx),.color_y(cy),.color_class(cc),
 .query_x(qx),.query_y(qy),.neighbor_class(nearby),.result_ack(ack),.pending_types(types),.rgb_out(colored),
 .de_out(de_out),.valid_out(),.hs_out(hs_out),.vs_out(vs_out));
 wire [47:0] hud_protected={number_mask_d[1]?number_rgb_d[47:24]:colored[47:24],
                            number_mask_d[0]?number_rgb_d[23:0]:colored[23:0]};
 wire enabled;
 final_shape_overlay #(.LOCK_SUPPORT(UI_V2),.IMG_W(W),.IMG_H(H)) overlay(
 .clk(clk),.rst_n(rst_n),.enable(shape_on),.lock_request(shape_lock_request),.locked(shape_locked),.rgb_in(hud_protected),.de(de_out),.valid(de_out),.vs(vs_out),
 .result_ready(ready),.pending_types(types),.result_ack(ack),.rgb_out(rgb_out),.enabled_frame(enabled),.detected_frame(shape_result_valid),.visible_types());
 reg dd,vd;reg [11:0] x,y;
 wire [11:0] px=dd?x:12'd0;
 always @(posedge clk)begin
 if(!rst_n)begin dd<=0;vd<=0;x<=0;y<=0;end
 else begin dd<=de_out;vd<=vs_out;
 if(vd&&!vs_out)begin x<=0;y<=0;end
 else if(de_out)x<=px+2;else if(dd)begin x<=0;y<=y+1'b1;end end end
 function mask(input [11:0] xx,yy);mask=enabled&&de_out&&xx>=300&&xx<420&&yy>=32&&yy<92;endfunction
 assign overlay_mask=mask_d|{mask(px+12'd1,y),mask(px,y)};
endmodule

// Number UI shell requested by the user: identical ROI/cross/preview/HUD,
// no preprocessing, MLP, vote filter or digit result. NUMBER ? is deliberate.
module golden_number_annotation56 #(
 parameter integer IMG_W=1920,IMG_H=1080,ROI_SIZE=768,
 parameter integer ROI_X=(IMG_W-ROI_SIZE)/2,ROI_Y=(IMG_H-ROI_SIZE)/2,
 parameter integer H_TOTAL_BEATS=1066,
 parameter PANEL_SWAP_RB_ON_EDGE=1'b1,
 parameter [7:0] DETECT_THRESHOLD_MIN=8'd6,
 parameter integer MARGIN_MIN=300,STABLE_RESULTS=3,HOLD_ANALYSES=3,
 parameter integer CROP_PAD_CELLS=1
)(
 input wire clk,rst_n,enable,input wire [47:0] rgb_in,
 input wire de_in,valid_in,hs_in,vs_in,input wire [15:0] canny_edges,
 output wire [47:0] rgb_out,output wire de_out,valid_out,hs_out,vs_out,
 output wire [1:0] overlay_mask,output wire enabled_frame,detected_frame
);
 wire [47:0] red_edges=rgb_in;
 wire edge_de=de_in,edge_valid=valid_in,edge_hs=hs_in,edge_vs=vs_in;
 wire [3:0] result=4'd15;
 wire box_valid=1'b0,front=1'b0;
 wire [7:0] box_x0=0,box_x1=0,box_y0=0,box_y1=0;
 wire [783:0] preview0=784'd0,preview1=784'd0;
 reg vs_d,de_d,on_frame;reg [11:0] x,y;
 wire [11:0] px=de_d?x:12'd0;
 wire sof=vs_d&&!edge_vs;
 assign de_out=edge_de;assign valid_out=edge_valid;assign hs_out=edge_hs;assign vs_out=edge_vs;
 assign enabled_frame=on_frame;assign detected_frame=1'b0;
 always @(posedge clk)begin
  if(!rst_n)begin vs_d<=0;de_d<=0;on_frame<=0;x<=0;y<=0;end
  else begin
   vs_d<=edge_vs;de_d<=edge_de;
   if(sof)begin x<=0;y<=0;on_frame<=enable;end
   else if(edge_de&&edge_valid)x<=px+2;
   else if(de_d&&!edge_de)begin x<=0;y<=y+1'b1;end
  end
 end
 function [34:0] glyph;
  input [7:0] c;
  begin case(c)
   "0":glyph=35'b01110_10001_10011_10101_11001_10001_01110;
   "1":glyph=35'b00100_01100_00100_00100_00100_00100_01110;
   "2":glyph=35'b01110_10001_00001_00010_00100_01000_11111;
   "3":glyph=35'b11110_00001_00001_01110_00001_00001_11110;
   "4":glyph=35'b00010_00110_01010_10010_11111_00010_00010;
   "5":glyph=35'b11111_10000_10000_11110_00001_00001_11110;
   "6":glyph=35'b01110_10000_10000_11110_10001_10001_01110;
   "7":glyph=35'b11111_00001_00010_00100_01000_01000_01000;
   "8":glyph=35'b01110_10001_10001_01110_10001_10001_01110;
   "9":glyph=35'b01110_10001_10001_01111_00001_00001_01110;
   "N":glyph=35'b10001_11001_11001_10101_10011_10011_10001;
   "U":glyph=35'b10001_10001_10001_10001_10001_10001_01110;
   "M":glyph=35'b10001_11011_10101_10101_10001_10001_10001;
   "B":glyph=35'b11110_10001_10001_11110_10001_10001_11110;
   "E":glyph=35'b11111_10000_10000_11110_10000_10000_11111;
   "R":glyph=35'b11110_10001_10001_11110_10100_10010_10001;
   "O":glyph=35'b01110_10001_10001_10001_10001_10001_01110;
   "F":glyph=35'b11111_10000_10000_11110_10000_10000_10000;
   "?":glyph=35'b01110_10001_00001_00010_00100_00000_00100;
   default:glyph=0;
  endcase end
 endfunction
 function [23:0] paint;
  input [23:0] p;input [11:0] xx,yy;
  reg [63:0] text;reg [34:0] bits;integer tx,ty,ci,cc,pi;
  begin
   paint=p;text=on_frame?{"NUMBER ",result<10?(8'd48+{4'd0,result}):8'd63}:"OFF     ";bits=0;tx=0;ty=0;ci=0;cc=0;pi=0;
   if(edge_de&&edge_valid)begin
    if(on_frame&&xx>=ROI_X&&xx<ROI_X+ROI_SIZE&&yy>=ROI_Y&&yy<ROI_Y+ROI_SIZE&&
     (xx<ROI_X+2||xx>=ROI_X+ROI_SIZE-2||yy<ROI_Y+2||yy>=ROI_Y+ROI_SIZE-2))paint=24'hffffff;
    if(on_frame&&((xx>=ROI_X+ROI_SIZE/2-8&&xx<ROI_X+ROI_SIZE/2+8&&yy==ROI_Y+ROI_SIZE/2)||
     (yy>=ROI_Y+ROI_SIZE/2-8&&yy<ROI_Y+ROI_SIZE/2+8&&xx==ROI_X+ROI_SIZE/2)))paint=24'hffffff;
    if(on_frame&&box_valid&&xx>=ROI_X+box_x0*4&&xx<ROI_X+(box_x1+1)*4&&yy>=ROI_Y+box_y0*4&&yy<ROI_Y+(box_y1+1)*4&&
     (xx<ROI_X+box_x0*4+2||xx>=ROI_X+(box_x1+1)*4-2||yy<ROI_Y+box_y0*4+2||yy>=ROI_Y+(box_y1+1)*4-2))paint=result<10?24'h00ff00:(PANEL_SWAP_RB_ON_EDGE?24'h00ffff:24'hffff00);
    if(on_frame&&xx>=32&&xx<144&&yy>=96&&yy<208)begin
     pi=((yy-96)/4)*28+(xx-32)/4;paint=(front?preview1[pi]:preview0[pi])?24'hffffff:24'h000000;
    end
    if(on_frame&&xx>=32&&xx<224&&yy>=32&&yy<64)begin
     tx=(xx-32)/4;ty=(yy-32)/4;ci=tx/6;cc=tx%6;bits=glyph(text[63-ci*8 -:8]);
     paint=(ty<7&&cc<5&&bits[34-ty*5-cc])?24'hffffff:24'h000000;
    end
   end
  end
 endfunction
 function mask(input [11:0] xx,yy);
 begin
 mask=edge_de&&edge_valid&&(
 (on_frame&&xx>=32&&xx<224&&yy>=32&&yy<64)||
 (on_frame&&xx>=32&&xx<144&&yy>=96&&yy<208)||
 (on_frame&&xx>=ROI_X&&xx<ROI_X+ROI_SIZE&&yy>=ROI_Y&&yy<ROI_Y+ROI_SIZE&&
 (xx<ROI_X+2||xx>=ROI_X+ROI_SIZE-2||yy<ROI_Y+2||yy>=ROI_Y+ROI_SIZE-2))||
 (on_frame&&((xx>=ROI_X+ROI_SIZE/2-8&&xx<ROI_X+ROI_SIZE/2+8&&yy==ROI_Y+ROI_SIZE/2)||
 (yy>=ROI_Y+ROI_SIZE/2-8&&yy<ROI_Y+ROI_SIZE/2+8&&xx==ROI_X+ROI_SIZE/2)))||
 (on_frame&&box_valid&&xx>=ROI_X+box_x0*4&&xx<ROI_X+(box_x1+1)*4&&yy>=ROI_Y+box_y0*4&&yy<ROI_Y+(box_y1+1)*4&&
 (xx<ROI_X+box_x0*4+2||xx>=ROI_X+(box_x1+1)*4-2||yy<ROI_Y+box_y0*4+2||yy>=ROI_Y+(box_y1+1)*4-2)));
 end endfunction
 assign overlay_mask={mask(px+12'd1,y),mask(px,y)};
 assign rgb_out={paint(red_edges[47:24],px+12'd1,y),paint(red_edges[23:0],px,y)};
endmodule
