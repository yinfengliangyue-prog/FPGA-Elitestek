module raster55 #(parameter W=1920,H=1080,HT=1100,VT=1125,HB=96,VB=41,HS=22,VS=5)(
 input wire clk,rst_n,ready,ack_toggle,input wire [2:0] app_mode,mode_a,mode_b,
 input wire [1:0] frame_page,input wire [7:0] frame_count,input wire [2:0] tag_a,tag_b,
 input wire aux_visible,shape_locked,
 output reg frame_toggle,fifo_reset,input wire empty,input wire [127:0] head,output wire pop,
 output reg [47:0] rgb,output reg de,hs,vs,underflow,output wire frame_tick,display_valid,
 output reg [2:0] frame_app,output reg [2:0] frame_ma,frame_mb);
 reg [11:0] h,v;reg [4:0] reset_count;reg [1:0] phase;reg frame_ok,ack_seen;
 reg [1:0] page;reg [7:0] count;reg [2:0] taga,tagb;reg aux,locked;
 wire active=h>=HB&&h<HB+W/2&&v>=VB&&v<VB+H;
 wire [11:0] xbeat=h-HB,y=v-VB;
 wire full=frame_app!=1;
 wire image_area=active&&(full||(y>=H/4&&y<H*3/4));
 wire right=xbeat>=W/4;
 // EXPR always visualizes the same captured Canny mask used for recognition.
 wire [2:0] mode=frame_app==3?3'd1:full?frame_ma:right?frame_mb:frame_ma;
 wire [2:0] tag=right&&!full?tagb:taga;
 wire compatible=frame_app==1?1'b1:tag[2]==(frame_app==2)&&(frame_app!=2||(tag[1]==aux&&tag[0]==locked));
 wire history_blank=frame_app==1&&count==0&&(page==2||(page==1&&right));
 wire [31:0] one=head[127-(phase*32)-:32];
 wire [63:0] pair=phase[0]?head[63:0]:head[127:64];
 function [23:0] render(input [31:0] p,input [2:0] m);
 reg [23:0] c;reg [15:0] g;begin
 c={p[13:9],p[13:11],p[8:4],p[8:6],p[3:0],p[3:0]};g=77*c[23:16]+150*c[15:8]+29*c[7:0];
 if(p[14])render=c;else case(m)
 1:render=p[15]?24'hff0000:c;2:render={3{p[31:24]}};3:render={3{g[15:8]}};4:render={3{p[23:16]}};default:render=c;endcase
 end endfunction
 assign frame_tick=h==0&&v==0;assign display_valid=frame_ok&&compatible&&!history_blank;
 assign pop=image_area&&frame_ok&&!empty&&(full?phase==3:phase[0]);
 always @(posedge clk)begin
 if(!rst_n)begin h<=0;v<=0;reset_count<=0;phase<=0;frame_ok<=0;ack_seen<=0;
 frame_toggle<=0;fifo_reset<=1;rgb<=0;de<=0;hs<=0;vs<=0;underflow<=0;
 frame_app<=0;frame_ma<=0;frame_mb<=2;page<=0;count<=0;taga<=0;tagb<=0;aux<=1;locked<=0;end
 else begin
 h<=h==HT-1?0:h+1'b1;if(h==HT-1)v<=v==VT-1?0:v+1'b1;
 hs<=h<HS;vs<=v<VS;de<=active;rgb<=active?{2{24'h101010}}:48'd0;
 if(ack_toggle!=ack_seen)begin ack_seen<=ack_toggle;frame_ok<=1;taga<=tag_a;tagb<=tag_b;page<=frame_page;count<=frame_count;end
 if(frame_tick)begin frame_toggle<=~frame_toggle;fifo_reset<=1;reset_count<=0;frame_ok<=0;
 frame_app<=app_mode;frame_ma<=mode_a;frame_mb<=mode_b;aux<=aux_visible;locked<=shape_locked;end
 else if(reset_count<16)begin reset_count<=reset_count+1'b1;fifo_reset<=1;end else fifo_reset<=0;
 if(!image_area)phase<=0;
 else if(frame_ok)begin
 if(empty)begin rgb<=0;underflow<=1;frame_ok<=0;end
 else begin
 phase<=full?phase+1'b1:{1'b0,~phase[0]};
 rgb<=!compatible||history_blank?48'd0:full?{2{render(one,mode)}}:{render(pair[31:0],mode),render(pair[63:32],mode)};
 end end else rgb<=0;
 end end
endmodule
