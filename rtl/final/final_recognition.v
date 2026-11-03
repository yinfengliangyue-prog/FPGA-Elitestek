// User-selected second2.2 geometry and color maps, fed by user-selected Canny.
module final_recognition #(parameter UI_V2=0,W=1920,H=1080,HT=1066)(
 input wire clk,rst_n,shape_enable,number_enable,
 input wire aux_visible,shape_lock_request,
 output wire shape_locked,shape_result_valid,output wire [2:0] capture_tag,
 input wire [47:0] rgb_in,input wire [15:0] edges,number_edges,mag,accepted,input wire de,hs,vs,
 output wire [47:0] rgb_out,output wire [1:0] overlay_mask,
 output reg [15:0] mag_out,accepted_out,output wire de_out,hs_out,vs_out
);
 wire [47:0] colored;
 reg shape_on,vs_old,aux_on;reg [1:0] mask_d;
 assign capture_tag={shape_on,aux_on,shape_locked};
 wire sof=vs_old&&!vs;
 always @(posedge clk)begin
 if(!rst_n)begin aux_on<=1;shape_on<=0;vs_old<=0;mask_d<=0;mag_out<=0;accepted_out<=0;end
 else begin
  vs_old<=vs;if(sof)begin shape_on<=shape_enable;aux_on<=UI_V2?aux_visible:1'b1;end
  mag_out<=mag;accepted_out<=accepted;
  mask_d<={shape_on&&aux_on&&edges[15:8]!=0,shape_on&&aux_on&&edges[7:0]!=0};
 end end
 wire [2:0] types;wire ready,ack,cstart,cwrite;wire [7:0] cx,cy,qx,qy;wire [1:0] cc,nearby;
 shape_contour_detector #(.IMG_W(W),.IMG_H(H)) detector(
 .clk(clk),.rst_n(rst_n),.enable(shape_on),.edge_bits(edges),.de(de),.valid(de),.vs(vs),
 .pending_types(types),.result_ready(ready),.result_ack(ack),.done(),.busy(),
 .color_start(cstart),.color_write(cwrite),.color_x(cx),.color_y(cy),.color_class(cc),
 .color_query_x(qx),.color_query_y(qy),.color_neighbor_class(nearby));
 shape_color_overlay #(.IMG_W(W),.IMG_H(H),.PANEL_SWAP_RB_ON_EDGE(0)) color_overlay(
 .clk(clk),.rst_n(rst_n),.enable(shape_on),.rgb_in(rgb_in),.edge_bits(shape_on&&aux_on?edges:16'd0),
 .de(de),.valid(de),.hs(hs),.vs(vs),.color_start(cstart),.color_write(cwrite),.color_x(cx),.color_y(cy),.color_class(cc),
 .query_x(qx),.query_y(qy),.neighbor_class(nearby),.result_ack(ack),.pending_types(types),.rgb_out(colored),
 .de_out(de_out),.valid_out(),.hs_out(hs_out),.vs_out(vs_out));
 wire enabled;
 final_shape_overlay #(.LOCK_SUPPORT(UI_V2),.IMG_W(W),.IMG_H(H)) overlay(
 .clk(clk),.rst_n(rst_n),.enable(shape_on),.lock_request(shape_lock_request),.locked(shape_locked),.rgb_in(colored),.de(de_out),.valid(de_out),.vs(vs_out),
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
