// Full-resolution Canny/BAL before reduction. Pixel = BAL8,RED1,RGB887.
// BAL=max2x2, RED=OR2x2, WB=upper-left. Queue color once per footprint.
// Pointers span frames: input VS must not discard a tail in the edge pipeline.
module replay_pack52 #(parameter W=1920,H=1080)(
 input wire clk,rst_n,
 input wire [47:0] rgb,input wire color_de,color_vs,
 input wire [15:0] balanced,input wire [1:0] red,input wire de,vs,
 output reg fifo_reset,frame_start,write_en,output reg [127:0] write_data,output reg fault
);
 localparam DEPTH=1<<$clog2(4*W),AW=$clog2(DEPTH);
 (* syn_ramstyle="block_ram" *)reg [22:0] colors[0:DEPTH-1];
 reg [AW-1:0] wp,rp;reg [AW:0] used;
 reg cv_d,cd_d,low_seen,saw_cv,color_armed;reg [11:0] cy;
 wire push=color_armed&&!color_vs&&color_de&&!cy[0];
 reg vs_d,de_d,saw_vs,armed;reg [11:0] x,y;
 reg [8:0] even_line[0:W/2-1];reg [8:0] saved,odd;
 reg [22:0] saved_color;reg valid;reg [1:0] phase;reg [127:0] pack;
 wire [11:0] xi=de_d?x:12'd0;
 wire [7:0] max_pair=balanced[15:8]>balanced[7:0]?balanced[15:8]:balanced[7:0];
 wire pop=armed&&!vs&&de&&y[0];
 wire [7:0] block_max=saved[8:1]>odd[8:1]?saved[8:1]:odd[8:1];
 wire [31:0] pixel={block_max,saved[0]|odd[0],saved_color};
 always @(posedge clk)begin
  if(!rst_n)begin
   wp<=0;rp<=0;used<=0;cv_d<=0;cd_d<=0;low_seen<=0;saw_cv<=0;color_armed<=0;cy<=0;
   vs_d<=0;de_d<=0;saw_vs<=0;armed<=0;x<=0;y<=0;saved<=0;odd<=0;saved_color<=0;valid<=0;
   fifo_reset<=1;frame_start<=0;write_en<=0;write_data<=0;fault<=0;phase<=0;pack<=0;
  end else begin
   cv_d<=color_vs;cd_d<=color_de;
   if(!color_vs)low_seen<=1;
   if(color_vs&&!cv_d&&low_seen)saw_cv<=1;
   if(color_vs)begin color_armed<=0;cy<=0;end
   if(cv_d&&!color_vs&&saw_cv)color_armed<=1;
   if(cd_d&&!color_de&&!color_vs)cy<=cy+1'b1;
   if(push)begin colors[wp]<={rgb[23:8],rgb[7:1]};wp<=wp+1'b1;end
   if(pop)begin saved_color<=colors[rp];rp<=rp+1'b1;end
   case({push,pop})2'b10:used<=used+1'b1;2'b01:used<=used-1'b1;default:begin end endcase
   if((push&&!pop&&used==DEPTH)||(pop&&used==0))fault<=1;
   vs_d<=vs;de_d<=de;fifo_reset<=0;write_en<=0;valid<=pop;
   if(vs)begin saw_vs<=1;armed<=0;x<=0;y<=0;phase<=0;end
   if(vs_d&&!vs&&saw_vs)begin armed<=1;fifo_reset<=1;frame_start<=1;x<=0;y<=0;phase<=0;end
   if(armed&&!vs)begin
    if(de)begin
     x<=de_d?x+1'b1:1;
     if(!y[0])even_line[xi]<={max_pair,|red};
     else begin saved<=even_line[xi];odd<={max_pair,|red};end
    end
    if(de_d&&!de)begin x<=0;y<=y+1'b1;end
   end
   if(valid&&!vs)begin
    pack<={pack[95:0],pixel};phase<=phase+1'b1;
    if(phase==3)begin write_data<={pack[95:0],pixel};write_en<=1;frame_start<=0;end
   end
  end
 end
 // synthesis translate_off
 always @(posedge clk)if(rst_n&&fault)$fatal(1,"WB/BAL pairing queue overflow/underflow");
 // synthesis translate_on
endmodule
