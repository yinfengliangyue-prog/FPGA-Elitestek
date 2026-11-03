// Two 16x16 classification maps. Synchronous lookup adds exactly one clock
// to RGB and all video controls; no whole-frame video buffer is introduced.
module shape_color_overlay #(
 parameter integer IMG_W=1920,IMG_H=1080,CELL_LOG2=3,LABEL_LOG2=4,
 parameter PANEL_SWAP_RB_ON_EDGE=1'b1
)(
 input wire clk,rst_n,enable,
 input wire [47:0] rgb_in,input wire [15:0] edge_bits,
 input wire de,valid,hs,vs,
 input wire color_start,color_write,input wire [7:0] color_x,color_y,
 input wire [1:0] color_class,
 input wire [7:0] query_x,query_y,output wire [1:0] neighbor_class,
 input wire result_ack,input wire [2:0] pending_types,
 output wire [47:0] rgb_out,output reg de_out,valid_out,hs_out,vs_out
);
 localparam COLS=(IMG_W+(1<<LABEL_LOG2)-1)>>LABEL_LOG2;
 localparam ROWS=(IMG_H+(1<<LABEL_LOG2)-1)>>LABEL_LOG2;
 localparam CELLS=COLS*ROWS,AW=$clog2(CELLS),SHIFT=LABEL_LOG2-CELL_LOG2;
 (* syn_ramstyle="block_ram",syn_ramdecomp="area" *) reg [1:0] labels0[0:CELLS-1];
 (* syn_ramstyle="block_ram",syn_ramdecomp="area" *) reg [1:0] labels1[0:CELLS-1];
 reg [1:0] q0,q1;
 reg front_bank,front_valid,clearing,on_frame;
 reg [AW-1:0] clear_addr;
 reg [2:0] published_types;
 reg [47:0] rgb_d;reg [15:0] edge_d;
 reg vs_d,de_d;reg [11:0] x,y;
 wire [11:0] px=de_d?x:12'd0;
 wire sof=vs_d&&!vs;
 wire [AW-1:0] display_addr=de&&valid&&px<IMG_W&&y<IMG_H?
  (y>>LABEL_LOG2)*COLS+(px>>LABEL_LOG2):0;
 wire [AW-1:0] label_addr=(color_y>>SHIFT)*COLS+(color_x>>SHIFT);
 wire [AW-1:0] query_addr=(query_y>>SHIFT)*COLS+(query_x>>SHIFT);
 wire write_en=clearing||color_write;
 wire [AW-1:0] write_addr=clearing?clear_addr:label_addr;
 wire [1:0] write_data=clearing?2'd0:color_class;
 wire [1:0] visible_label=front_bank?q1:q0;
 assign neighbor_class=front_bank?q0:q1;
 function [23:0] panel;
  input [23:0] c;
  begin panel=PANEL_SWAP_RB_ON_EDGE?{c[7:0],c[15:8],c[23:16]}:c;end
 endfunction
 function [23:0] paint;
  input [23:0] p;input [7:0] edge_value;input [1:0] label;
  begin
   paint=p;
   if(edge_value==255) begin
    paint=panel(24'hff0000);
    if(on_frame&&front_valid) case(label)
     1:if(published_types[0]) paint=panel(24'h00ff00);
     2:if(published_types[1]) paint=panel(24'h0000ff);
     3:if(published_types[2]) paint=panel(24'hffff00);
     default:begin end
    endcase
   end
  end
 endfunction
 assign rgb_out={paint(rgb_d[47:24],edge_d[15:8],visible_label),paint(rgb_d[23:0],edge_d[7:0],visible_label)};
 always @(posedge clk) begin
  q0<=labels0[front_bank?query_addr:display_addr];
  q1<=labels1[front_bank?display_addr:query_addr];
  // Back bank is cleared during capture, well before contour classification.
  if(write_en) begin
   if(front_bank) labels0[write_addr]<=write_data;
   else labels1[write_addr]<=write_data;
  end
 end
 always @(posedge clk) begin
  if(!rst_n) begin
   front_bank<=0;front_valid<=0;published_types<=0;clearing<=0;clear_addr<=0;on_frame<=0;
   rgb_d<=0;edge_d<=0;de_out<=0;valid_out<=0;hs_out<=0;vs_out<=0;
   vs_d<=0;de_d<=0;x<=0;y<=0;
  end else begin
   rgb_d<=rgb_in;edge_d<=edge_bits;de_out<=de;valid_out<=valid;hs_out<=hs;vs_out<=vs;
   vs_d<=vs;de_d<=de;
   if(sof) begin
    x<=0;y<=0;on_frame<=enable;
    if(!enable) begin front_valid<=0;published_types<=0;end
   end else if(de&&valid) x<=px+2;
   else if(de_d&&!de) begin x<=0;y<=y+1'b1;end
   if(color_start) begin clearing<=1;clear_addr<=0;end
   else if(clearing) begin
    if(clear_addr==CELLS-1) clearing<=0;else clear_addr<=clear_addr+1'b1;
   end
   if(result_ack) begin front_bank<=!front_bank;front_valid<=enable;published_types<=pending_types;end
  end
 end
 // synthesis translate_off
 initial begin
  if(LABEL_LOG2<CELL_LOG2||LABEL_LOG2<2||CELLS<2) $fatal(1,"Unsupported color map configuration");
 end
 always @(posedge clk) if(rst_n) begin
  if(color_write&&clearing) $fatal(1,"Color boundary before back map clear finished");
  if(color_write&&label_addr>=CELLS) $fatal(1,"Color map write out of bounds");
  if(result_ack&&(color_write||clearing)) $fatal(1,"Publishing incomplete color map");
 end
 // synthesis translate_on
endmodule
