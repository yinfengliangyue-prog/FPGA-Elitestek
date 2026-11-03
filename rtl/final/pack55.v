// Losslessly pack eight 48-bit pixels into three AXI128 words (no zero padding).
// Pair the original 32-bit 2x2 records with the delayed original-resolution
// 49 render values. Queue only quarter-resolution metadata, never full RGB.
module pack55 #(parameter W=1920,H=1080,FIFO_DEPTH=(1<<$clog2(W+64)))(
 input wire clk,rst_n,de,vs,input wire [47:0] rgb,input wire [15:0] mag,accepted,
 input wire [1:0] annotation,input wire exact_defaults,
 input wire render_de,render_vs,input wire [15:0] balanced,clean,
 output reg fifo_reset,frame_start,write_en,output reg [127:0] write_data,
 output reg pairing_fault
);
 localparam FW=$clog2(FIFO_DEPTH);
 reg vs_d,de_d,saw_vs,armed;reg [11:0] x,y;
 (* syn_ramstyle="block_ram",syn_ramdecomp="area" *) reg [15:0] even_line[0:W/2-1];
 reg [15:0] saved;reg odd_accepted;reg odd_valid;reg [15:0] odd_meta;
 wire [11:0] xi=de_d?x:12'd0;
 wire [7:0] pair_mag=mag[15:8]>mag[7:0]?mag[15:8]:mag[7:0];
 wire [7:0] pair_accepted=accepted[15:8]>accepted[7:0]?accepted[15:8]:accepted[7:0];
 wire choose_high=!annotation[0]&&annotation[1];
 wire [23:0] chosen=choose_high?rgb[47:24]:rgb[23:0];
 wire [15:0] meta={|accepted,|annotation,chosen[23:19],chosen[15:11],chosen[7:4]};
 wire [15:0] final_meta=saved[14]?saved:(odd_meta[14]?odd_meta:saved);
 wire [15:0] base_pixel={saved[15]|odd_accepted,final_meta[14:0]};
 reg rvs_d,rde_d,rsaw_vs,rarmed;reg [11:0] rx,ry;
 (* syn_ramstyle="block_ram",syn_ramdecomp="area" *) reg [15:0] render_line[0:W/2-1];
 reg [15:0] render_saved;reg [7:0] odd_balanced,odd_clean;reg render_valid;
 wire [11:0] rxi=rde_d?rx:12'd0;
 wire [7:0] pair_balanced=balanced[15:8]>balanced[7:0]?balanced[15:8]:balanced[7:0];
 wire [7:0] pair_clean=clean[15:8]>clean[7:0]?clean[15:8]:clean[7:0];
 wire [7:0] block_balanced=render_saved[15:8]>odd_balanced?render_saved[15:8]:odd_balanced;
 wire [7:0] block_clean=render_saved[7:0]>odd_clean?render_saved[7:0]:odd_clean;
 wire [15:0] render_pixel={block_balanced,block_clean};
 // Across VS the base stream can already contain the NEXT frame while the
 // renderer still finishes the preceding one, so these pointers never reset
 // at a frame boundary. Both streams arm after their first complete VS.
 (* syn_ramstyle="block_ram",syn_ramdecomp="area" *) reg [15:0] queue[0:FIFO_DEPTH-1];
 reg [FW:0] wp,rp;reg [15:0] base_q;reg [15:0] render_q;reg merge_valid;
 wire empty=wp==rp,full=wp[FW]!=rp[FW]&&wp[FW-1:0]==rp[FW-1:0];
 wire push=odd_valid&&!vs,pull=render_valid&&!render_vs;
 wire [31:0] pixel={render_q,base_q};
 reg [1:0] phase;reg [95:0] pack;
 always @(posedge clk)begin
 if(!rst_n)begin
  vs_d<=0;de_d<=0;saw_vs<=0;armed<=0;x<=0;y<=0;
  saved<=0;odd_accepted<=0;odd_valid<=0;odd_meta<=0;
  rvs_d<=0;rde_d<=0;rsaw_vs<=0;rarmed<=0;rx<=0;ry<=0;
  render_saved<=0;odd_balanced<=0;odd_clean<=0;render_valid<=0;
  wp<=0;rp<=0;base_q<=0;render_q<=0;merge_valid<=0;phase<=0;pack<=0;
  fifo_reset<=1;frame_start<=0;write_en<=0;write_data<=0;pairing_fault<=0;
 end else begin
  vs_d<=vs;de_d<=de;odd_valid<=armed&&!vs&&de&&y[0];
  rvs_d<=render_vs;rde_d<=render_de;render_valid<=rarmed&&!render_vs&&render_de&&ry[0];
  fifo_reset<=0;write_en<=0;merge_valid<=pull&&!empty;
  if(vs)begin saw_vs<=1;armed<=0;x<=0;y<=0;end
  if(vs_d&&!vs&&saw_vs)begin armed<=1;x<=0;y<=0;end
  if(armed&&!vs)begin
   if(de)begin
    x<=de_d?x+1'b1:1;
    if(!y[0])even_line[xi]<=meta;
    else begin saved<=even_line[xi];odd_accepted<=|accepted;odd_meta<=meta;end
   end
   if(de_d&&!de)begin x<=0;y<=y+1'b1;end
  end
  if(render_vs)begin rsaw_vs<=1;rarmed<=0;rx<=0;ry<=0;phase<=0;end
  if(rvs_d&&!render_vs&&rsaw_vs)begin rarmed<=1;fifo_reset<=1;frame_start<=1;rx<=0;ry<=0;phase<=0;end
  if(rarmed&&!render_vs)begin
   if(render_de)begin
    rx<=rde_d?rx+1'b1:1;
    if(!ry[0])render_line[rxi]<={pair_balanced,pair_clean};
    else begin render_saved<=render_line[rxi];odd_balanced<=pair_balanced;odd_clean<=pair_clean;end
   end
   if(rde_d&&!render_de)begin rx<=0;ry<=ry+1'b1;end
  end
  if(push)begin
   if(full)pairing_fault<=1;
   else begin queue[wp[FW-1:0]]<=base_pixel;wp<=wp+1'b1;end
  end
  if(pull)begin
   if(empty)pairing_fault<=1;
   else begin base_q<=queue[rp[FW-1:0]];rp<=rp+1'b1;render_q<=render_pixel;end
  end
  if(merge_valid&&!render_vs)begin
   pack<={pack[63:0],pixel};phase<=phase+1'b1;
   if(phase==3)begin write_data<={pack,pixel};write_en<=1;frame_start<=0;end
  end
 end end
 // synthesis translate_off
 initial if(W%16||H%2||FIFO_DEPTH<W+32||(1<<FW)!=FIFO_DEPTH)
  $fatal(1,"Invalid final_pack geometry/alignment queue");
 // synthesis translate_on
endmodule
