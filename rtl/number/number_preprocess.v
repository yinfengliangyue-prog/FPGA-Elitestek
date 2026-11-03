// 00 background, 01 unvisited, 11 pending small component, 10 retained.
// Bounded 8-connected BFS, nearest-centre component, thin-stroke max sampling.
module number_preprocess #(
 parameter integer IMG_W=1920,IMG_H=1080,ROI_SIZE=768,
 parameter integer ROI_X=(IMG_W-ROI_SIZE)/2,ROI_Y=(IMG_H-ROI_SIZE)/2,
 parameter integer CELL_MIN_HITS=2,MIN_COMPONENT_CELLS=8,MAX_CELLS=8000,
 parameter integer MIN_HEIGHT_CELLS=8,QUEUE_DEPTH=1024,
 parameter integer CROP_PAD_CELLS=1,EXPRESSION_NOISE_FILTER=1,
 parameter integer MAX_EXPRESSION_COMPONENTS=32,
 parameter integer CROP_STABILIZE=1,CROP_DEADBAND_CELLS=1,
 parameter integer CROP_SHRINK_ANALYSES=3,CROP_MATCH_CELLS=4,
 parameter integer CROP_HISTORY_FRAMES=12
)(
 input wire clk,rst_n,enable,input wire expression_enable,input wire [15:0] edge_bits,
 input wire de,valid,vs,inference_busy,
 output reg pixel_we,output reg [9:0] pixel_addr,output reg pixel_bit,
 output reg start,empty,output reg sequence_start,sequence_done,output reg [2:0] token_index,token_count,output wire busy,output reg selection_valid,overflow,
 output reg [7:0] selected_xmin,selected_xmax,selected_ymin,selected_ymax,
 output reg [7:0] noise_rejected,output reg [3:0] reject_reason,
 output reg [5:0] candidate_count,output wire [159:0] sampling_boxes
);
 localparam G=ROI_SIZE/4,N=G*G,AW=$clog2(N),QW=$clog2(QUEUE_DEPTH);
 localparam IDLE=0,CAP=1,SA=2,SW=3,SE=4,PC=5,PA=6,PW=7,PL=8,
  NA=9,NW=10,NE=11,PROMOTE=12,CD=13,ERASE=14,ADV=15,SELECT=16,
  TILE=17,RA=18,RW=19,ACC=20,EMIT=21,START=22,WAIT_NN=23,AREA=24,EX_INIT=25,EX_RA=26,EX_RW=27,EX_ACC=28,EX_COL=29,EX_ADV=30,EX_TAIL=31,EX_CHECK=32,EX_LOAD=33,EX_NORM=34,
  LINE_INIT=35,LINE_REF=36,LINE_SCAN=37,LINE_EVAL=38,LINE_FINAL=39,
  CLASS_INIT=40,CLASSIFY=41,ASSOC_INIT=42,ASSOC_SCAN=43,ASSOC_DONE=44,
  MASK_INIT=45,MASK_RA=46,MASK_RW=47,MASK_ACC=48,
  OWNER_INIT=49,OWNER_SCAN=50,TRACK_INIT=51,TRACK_MATCH=52,
  TRACK_LOAD=53,TRACK_CROP=54,TRACK_DONE=55;
 reg [5:0] state,resume;
 reg expression_mode,expression_bad;
 reg [7:0] sx0[0:4],sx1[0:4],sy0[0:4],sy1[0:4];
 reg [2:0] segments;reg run_valid,gap,col_any;
 reg [7:0] run_x0,run_x1,run_y0,run_y1,col_y0,col_y1;
 reg vs_d,de_d;reg [11:0] vx,vy;
 wire sof=vs_d&&!vs;wire [11:0] px=de_d?vx:12'd0;
 wire inside_roi=px>=ROI_X&&px<ROI_X+ROI_SIZE&&vy>=ROI_Y&&vy<ROI_Y+ROI_SIZE;
 wire [11:0] rx=px-ROI_X,ry=vy-ROI_Y;wire [7:0] capx=rx>>2,capy=ry>>2;
 wire [1:0] hits={1'b0,(edge_bits[7:0]==255)}+{1'b0,(edge_bits[15:8]==255)};
 reg [4:0] columns[0:G-1];
 wire [4:0] total=((rx[1:0]==0&&ry[1:0]==0)?5'd0:columns[capx])+hits;
 reg [1:0] grid[0:N-1],gq;reg [15:0] fifo[0:QUEUE_DEPTH-1],fq;
 // Labels are written together with the CCL visit. Small components reuse the
 // next free label only after their grid cells have been erased. No frame-sized
 // labels or pixel buffers outside this 4x4 occupancy grid are required.
 wire [4:0] label_q;
 (* syn_ramstyle="registers" *) reg [7:0] comp_x0[0:31],comp_x1[0:31],comp_y0[0:31],comp_y1[0:31];
 // Only the predicate size > MAX_CELLS is ever read from this table.
 // Store the exact predicate rather than sixteen unused count bits.
 reg comp_large[0:31];reg comp_touch[0:31];
 reg [2:0] comp_owner[0:31];
 reg [31:0] keep_components,base_components;
 reg [5:0] component_count,ci,cj,line_best_score,line_score;
 reg [4:0] line_best;reg line_ambiguous;
 reg [7:0] line_y0,line_y1,line_height;
 reg [2:0] owner_token;
 wire filtered_expression=expression_mode&&EXPRESSION_NOISE_FILTER;
 wire [4:0] visit_label=component_count<32?component_count[4:0]:5'd31;
 wire [8:0] ih={1'b0,comp_y1[ci[4:0]]}-{1'b0,comp_y0[ci[4:0]]}+1;
 wire [8:0] iw={1'b0,comp_x1[ci[4:0]]}-{1'b0,comp_x0[ci[4:0]]}+1;
 wire [8:0] jh={1'b0,comp_y1[cj[4:0]]}-{1'b0,comp_y0[cj[4:0]]}+1;
 wire [8:0] jw={1'b0,comp_x1[cj[4:0]]}-{1'b0,comp_x0[cj[4:0]]}+1;
 wire i_anchor=ci<component_count&&!comp_touch[ci[4:0]]&&!comp_large[ci[4:0]]&&ih>=MIN_HEIGHT_CELLS&&iw<=2*ih;
 wire j_anchor=cj<component_count&&!comp_touch[cj[4:0]]&&!comp_large[cj[4:0]]&&jh>=MIN_HEIGHT_CELLS&&jw<=2*jh;
 wire [7:0] overlap_top=comp_y0[ci[4:0]]>comp_y0[cj[4:0]]?comp_y0[ci[4:0]]:comp_y0[cj[4:0]];
 wire [7:0] overlap_bottom=comp_y1[ci[4:0]]<comp_y1[cj[4:0]]?comp_y1[ci[4:0]]:comp_y1[cj[4:0]];
 wire [8:0] overlap_height=overlap_bottom>=overlap_top?{1'b0,overlap_bottom}-{1'b0,overlap_top}+1:9'd0;
 wire pair_support=j_anchor&&3*jh>=2*ih&&2*jh<=3*ih&&
  2*overlap_height>=(ih<jh?ih:jh)&&
  (comp_x1[ci[4:0]]<comp_x0[cj[4:0]]||comp_x1[cj[4:0]]<comp_x0[ci[4:0]]);
 wire [8:0] best_height={1'b0,comp_y1[line_best]}-{1'b0,comp_y0[line_best]}+1;
 wire disjoint_best=comp_y1[ci[4:0]]<comp_y0[line_best]||comp_y1[line_best]<comp_y0[ci[4:0]];
 // A far-away component which barely enters the row margin must not extend a
 // character box. The entire component is kept or removed; never crop strokes
 // at the row boundary. All old minimum-height digit candidates and plausible
 // short minus signs are protected even when much smaller than the main row.
 wire [8:0] component_ycentre={1'b0,comp_y0[ci[4:0]]}+{1'b0,comp_y1[ci[4:0]]};
 wire row_intersects=component_ycentre>=2*line_y0&&component_ycentre<=2*line_y1;
 wire plausible_minus=iw>=8&&iw>=3*ih;
 wire tiny_component=4*iw<line_height&&4*ih<line_height&&ih<MIN_HEIGHT_CELLS&&!plausible_minus;
 wire stroke_fragment=iw>=3*ih||ih>=3*iw;
 wire near_base={1'b0,comp_x0[ci[4:0]]}<={1'b0,comp_x1[cj[4:0]]}+9'd2&&
  {1'b0,comp_x0[cj[4:0]]}<={1'b0,comp_x1[ci[4:0]]}+9'd2&&
  {1'b0,comp_y0[ci[4:0]]}<={1'b0,comp_y1[cj[4:0]]}+9'd2&&
  {1'b0,comp_y0[cj[4:0]]}<={1'b0,comp_y1[ci[4:0]]}+9'd2;
 reg [QW-1:0] head,tail;reg [QW:0] queued;
 reg [7:0] scanx,scany,cx,cy,nbx,nby;reg nb_valid;reg [2:0] nb;
 reg [7:0] cminx,cmaxx,cminy,cmaxy,xmin,xmax,ymin,ymax;
 reg [15:0] component_cells,best_cells;reg best_valid;
 reg [9:0] best_distance;
 wire [8:0] centre_x={1'b0,cminx}+{1'b0,cmaxx},centre_y={1'b0,cminy}+{1'b0,cmaxy};
 wire [8:0] distance_x=centre_x>G-1?centre_x-(G-1):(G-1)-centre_x;
 wire [8:0] distance_y=centre_y>G-1?centre_y-(G-1):(G-1)-centre_y;
 wire [9:0] centre_distance={1'b0,distance_x}+{1'b0,distance_y};
 wire inside_best=cminx>=xmin&&cmaxx<=xmax&&cminy>=ymin&&cmaxy<=ymax;
 wire encloses_best=cminx<=xmin&&cmaxx>=xmax&&cminy<=ymin&&cmaxy>=ymax;
 reg [AW-1:0] members[0:MIN_COMPONENT_CELLS-1];reg [7:0] mi;
 reg [9:0] oi;reg [4:0] ox,oy,tile_w,tile_h;
 // Keep raw detected bounds for operator geometry and expression voting. The
 // sampling/display window has its own history; one grid cell is four pixels.
 reg [7:0] crop_xmin,crop_xmax,crop_ymin,crop_ymax;
 reg [7:0] desired_xmin,desired_xmax,desired_ymin,desired_ymax;
 reg [7:0] history_x0[0:4],history_x1[0:4],history_y0[0:4],history_y1[0:4];
 reg [7:0] stable_x0[0:4],stable_x1[0:4],stable_y0[0:4],stable_y1[0:4];
 localparam SCW=CROP_SHRINK_ANALYSES>1?$clog2(CROP_SHRINK_ANALYSES):1;
 localparam HCW=CROP_HISTORY_FRAMES>1?$clog2(CROP_HISTORY_FRAMES):1;
 reg [SCW-1:0] shrink_x0[0:4],shrink_x1[0:4],shrink_y0[0:4],shrink_y1[0:4];
 reg history_valid,crop_ready,tracking_match;reg [2:0] history_count;
 reg [HCW-1:0] history_age;
 reg [8:0] neighbour_limit,left_limit,right_limit;
 reg [7:0] next_x0,next_x1,next_y0,next_y1;
 wire shrink_l=desired_xmin>stable_x0[token_index]+CROP_DEADBAND_CELLS;
 wire shrink_r=stable_x1[token_index]>desired_xmax+CROP_DEADBAND_CELLS;
 wire shrink_t=desired_ymin>stable_y0[token_index]+CROP_DEADBAND_CELLS;
 wire shrink_b=stable_y1[token_index]>desired_ymax+CROP_DEADBAND_CELLS;
 function coordinate_near;input [7:0] a,b;begin
  coordinate_near={1'b0,a}+CROP_MATCH_CELLS>={1'b0,b}&&{1'b0,b}+CROP_MATCH_CELLS>={1'b0,a};
 end endfunction
 genvar box_i;
 generate for(box_i=0;box_i<5;box_i=box_i+1)begin:sample_box_output
  assign sampling_boxes[box_i*32+:32]={stable_x0[box_i],stable_x1[box_i],stable_y0[box_i],stable_y1[box_i]};
 end endgenerate
 always @*begin
  desired_xmin=xmin>CROP_PAD_CELLS?xmin-CROP_PAD_CELLS:0;
  desired_xmax=xmax+CROP_PAD_CELLS<G?xmax+CROP_PAD_CELLS:G-1;
  desired_ymin=ymin>CROP_PAD_CELLS?ymin-CROP_PAD_CELLS:0;
  desired_ymax=ymax+CROP_PAD_CELLS<G?ymax+CROP_PAD_CELLS:G-1;
  neighbour_limit=0;left_limit=0;right_limit=G-1;
  // Divide the blank gap between adjacent symbols. No crop may reach a
  // neighbour's foreground, even if a larger padding parameter is selected.
  if(expression_mode&&token_index<token_count)begin
   if(token_index>0)begin
    neighbour_limit=(({1'b0,sx1[token_index-1]}+{1'b0,xmin})>>1)+9'd1;
    left_limit=neighbour_limit;
    if({1'b0,desired_xmin}<neighbour_limit)desired_xmin=neighbour_limit[7:0];
   end
   if(token_index+1<token_count)begin
    neighbour_limit=({1'b0,xmax}+{1'b0,sx0[token_index+1]})>>1;
    right_limit=neighbour_limit;
    if({1'b0,desired_xmax}>neighbour_limit)desired_xmax=neighbour_limit[7:0];
   end
  end
  crop_xmin=desired_xmin;crop_xmax=desired_xmax;crop_ymin=desired_ymin;crop_ymax=desired_ymax;
  if(expression_mode&&CROP_STABILIZE&&crop_ready&&token_index<token_count)begin
   crop_xmin=stable_x0[token_index];crop_xmax=stable_x1[token_index];
   crop_ymin=stable_y0[token_index];crop_ymax=stable_y1[token_index];
  end
  next_x0=desired_xmin;next_x1=desired_xmax;next_y0=desired_ymin;next_y1=desired_ymax;
  if(CROP_STABILIZE&&tracking_match)begin
   // Keep a fixed sampling transform while current strokes fit. Expand as soon
   // as a raw foreground bound escapes; contract one cell after persistent room.
   next_x0=xmin<stable_x0[token_index]?desired_xmin:stable_x0[token_index];
   next_x1=xmax>stable_x1[token_index]?desired_xmax:stable_x1[token_index];
   next_y0=ymin<stable_y0[token_index]?desired_ymin:stable_y0[token_index];
   next_y1=ymax>stable_y1[token_index]?desired_ymax:stable_y1[token_index];
   if(shrink_l&&shrink_x0[token_index]>=CROP_SHRINK_ANALYSES-1)next_x0=stable_x0[token_index]+1'b1;
   if(shrink_r&&shrink_x1[token_index]>=CROP_SHRINK_ANALYSES-1)next_x1=stable_x1[token_index]-1'b1;
   if(shrink_t&&shrink_y0[token_index]>=CROP_SHRINK_ANALYSES-1)next_y0=stable_y0[token_index]+1'b1;
   if(shrink_b&&shrink_y1[token_index]>=CROP_SHRINK_ANALYSES-1)next_y1=stable_y1[token_index]-1'b1;
   // Repartition the CURRENT neighbour gap even for a historical crop.
   if({1'b0,next_x0}<left_limit)next_x0=left_limit[7:0];
   if({1'b0,next_x1}>right_limit)next_x1=right_limit[7:0];
  end
 end
 wire [8:0] bw={1'b0,crop_xmax}-{1'b0,crop_xmin}+1,bh={1'b0,crop_ymax}-{1'b0,crop_ymin}+1;
 wire [8:0] longest=bw>bh?bw:bh;
 reg [8:0] side,padx,pady;
 wire [4:0] colx=ox-5'd4,coly=oy-5'd4;
 wire [5:0] colx1={1'b0,colx}+6'd1,coly1={1'b0,coly}+6'd1;
 wire [13:0] mx0=({9'd0,colx}*{5'd0,side})/14'd20,my0=({9'd0,coly}*{5'd0,side})/14'd20;
 wire [13:0] mx1=({8'd0,colx1}*{5'd0,side})/14'd20,my1=({8'd0,coly1}*{5'd0,side})/14'd20;
 wire signed [11:0] bx0=$signed({4'd0,crop_xmin})+$signed({2'd0,mx0[9:0]})-$signed({3'd0,padx});
 wire signed [11:0] by0=$signed({4'd0,crop_ymin})+$signed({2'd0,my0[9:0]})-$signed({3'd0,pady});
 wire signed [11:0] bx1=$signed({4'd0,crop_xmin})+$signed({2'd0,mx1[9:0]})-$signed({3'd0,padx});
 wire signed [11:0] by1=$signed({4'd0,crop_ymin})+$signed({2'd0,my1[9:0]})-$signed({3'd0,pady});
 wire signed [11:0] endx=bx1>bx0?bx1:bx0+1,endy=by1>by0?by1:by0+1;
 reg signed [11:0] ax,ay,tx0,tx1,ty1;reg [15:0] area,ones;reg tile_bit;
 wire norm_valid=ax>=crop_xmin&&ax<=crop_xmax&&ay>=crop_ymin&&ay<=crop_ymax;
 wire owned_foreground=!filtered_expression||comp_owner[label_q]==token_index;
 wire [15:0] next_ones=ones+((norm_valid&&gq==2'b10&&owned_foreground)?1:0);
 wire [AW-1:0] scan_addr=scany*G+scanx,nb_addr=nby*G+nbx,norm_addr=norm_valid?ay*G+ax:0;
 wire [AW-1:0] rdaddr=(state==NA||state==NW||state==NE)?(nb_valid?nb_addr:0):((state==RA||state==RW||state==ACC)?norm_addr:scan_addr);
 wire component_ok=component_cells>=MIN_COMPONENT_CELLS&&component_cells<=MAX_CELLS&&cmaxy-cminy+1>=MIN_HEIGHT_CELLS&&cminx!=0&&cminy!=0&&cmaxx!=G-1&&cmaxy!=G-1;
 always @*begin
  nbx=cx;nby=cy;nb_valid=1;
  case(nb)
   0:begin nbx=cx-1;nby=cy-1;nb_valid=cx>0&&cy>0;end
   1:begin nby=cy-1;nb_valid=cy>0;end
   2:begin nbx=cx+1;nby=cy-1;nb_valid=cx<G-1&&cy>0;end
   3:begin nbx=cx-1;nb_valid=cx>0;end
   4:begin nbx=cx+1;nb_valid=cx<G-1;end
   5:begin nbx=cx-1;nby=cy+1;nb_valid=cx>0&&cy<G-1;end
   6:begin nby=cy+1;nb_valid=cy<G-1;end
   7:begin nbx=cx+1;nby=cy+1;nb_valid=cx<G-1&&cy<G-1;end
  endcase
 end
 // Explicit one-write-port mux keeps the 2-bit grid in block RAM.
 reg grid_we,fifo_we;reg [AW-1:0] grid_wa;reg [1:0] grid_wd;
 reg label_we;reg [AW-1:0] label_wa;
 reg [QW-1:0] fifo_wa;reg [15:0] fifo_wd;
 always @*begin
  grid_we=0;grid_wa=0;grid_wd=0;fifo_we=0;fifo_wa=0;fifo_wd=0;label_we=0;label_wa=0;
  case(state)
   CAP:if(de&&valid&&inside_roi&&ry[1:0]==3&&rx[1:0]==2)begin grid_we=1;grid_wa=capy*G+capx;grid_wd=total>=CELL_MIN_HITS?2'b01:2'b00;end
   SE:if(gq==2'b01)begin grid_we=1;grid_wa=scan_addr;grid_wd=2'b11;fifo_we=1;fifo_wa=0;fifo_wd={scany,scanx};end
   NE:if(nb_valid&&gq==2'b01&&queued<QUEUE_DEPTH)begin grid_we=1;grid_wa=nb_addr;grid_wd=component_cells>=MIN_COMPONENT_CELLS?2'b10:2'b11;fifo_we=1;fifo_wa=tail;fifo_wd={nby,nbx};end
   PROMOTE:begin grid_we=1;grid_wa=members[mi];grid_wd=2'b10;end
   ERASE:begin grid_we=1;grid_wa=members[mi];grid_wd=2'b00;end
   MASK_ACC:if(gq==2'b10&&!keep_components[label_q])begin grid_we=1;grid_wa=scan_addr;grid_wd=2'b00;end
  endcase
  // One explicit write port lets synthesis infer block RAM for component IDs.
  if(state==SE&&gq==2'b01)begin label_we=1;label_wa=scan_addr;end
  else if(state==NE&&nb_valid&&gq==2'b01&&queued<QUEUE_DEPTH)begin label_we=1;label_wa=nb_addr;end
 end
 // Explicit 2048x5 banks retain all 32 component IDs, read-before-write
 // semantics and the original one-cycle read latency without power-of-two
 // fragmentation of the 36864-cell label plane.
 localparam LABEL_BANKS=(N+2047)/2048,LSW=LABEL_BANKS>1?$clog2(LABEL_BANKS):1;
 wire [4:0] label_data[0:LABEL_BANKS-1];reg [LSW-1:0] label_sel;
 genvar lb;
 generate for(lb=0;lb<LABEL_BANKS;lb=lb+1)begin:label_bank
  (* syn_ramstyle="block_ram",syn_ramdecomp="area" *) reg [4:0] mem[0:2047];reg [4:0] q;
  always @(posedge clk)begin
   if((rdaddr>>11)==lb)q<=mem[rdaddr%2048];
   if(rst_n&&enable&&filtered_expression&&label_we&&(label_wa>>11)==lb)mem[label_wa%2048]<=visit_label;
  end
  assign label_data[lb]=q;
 end endgenerate
 always @(posedge clk)label_sel<=rdaddr>>11;
 assign label_q=label_data[label_sel];
 always @(posedge clk)begin
  gq<=grid[rdaddr];fq<=fifo[head];
  if(rst_n&&enable&&grid_we)grid[grid_wa]<=grid_wd;
  if(rst_n&&enable&&fifo_we)fifo[fifo_wa]<=fifo_wd;

 end
 assign busy=state!=IDLE;
 always @(posedge clk)begin
  if(!rst_n)begin
   state<=IDLE;resume<=0;expression_mode<=0;expression_bad<=0;sequence_start<=0;sequence_done<=0;token_index<=0;token_count<=0;segments<=0;run_valid<=0;gap<=0;col_any<=0;run_x0<=0;run_x1<=0;run_y0<=0;run_y1<=0;col_y0<=0;col_y1<=0;vs_d<=0;de_d<=0;vx<=0;vy<=0;pixel_we<=0;pixel_addr<=0;pixel_bit<=0;start<=0;empty<=0;
   selection_valid<=0;overflow<=0;selected_xmin<=0;selected_xmax<=0;selected_ymin<=0;selected_ymax<=0;
   noise_rejected<=0;reject_reason<=0;candidate_count<=0;component_count<=0;
   ci<=0;cj<=0;line_best<=0;line_best_score<=0;line_score<=0;line_ambiguous<=0;
   line_y0<=0;line_y1<=0;line_height<=0;keep_components<=0;base_components<=0;owner_token<=0;
   head<=0;tail<=0;queued<=0;scanx<=0;scany<=0;cx<=0;cy<=0;nb<=0;mi<=0;
   cminx<=0;cmaxx<=0;cminy<=0;cmaxy<=0;xmin<=0;xmax<=0;ymin<=0;ymax<=0;component_cells<=0;best_cells<=0;best_valid<=0;
   best_distance<=1023;oi<=0;ox<=0;oy<=0;tile_w<=0;tile_h<=0;side<=0;padx<=0;pady<=0;ax<=0;ay<=0;tx0<=0;tx1<=0;ty1<=0;area<=0;ones<=0;tile_bit<=0;
   history_valid<=0;crop_ready<=0;tracking_match<=0;history_count<=0;history_age<=0;
   for(integer k=0;k<5;k=k+1)begin
    history_x0[k]<=0;history_x1[k]<=0;history_y0[k]<=0;history_y1[k]<=0;
    stable_x0[k]<=0;stable_x1[k]<=0;stable_y0[k]<=0;stable_y1[k]<=0;
    shrink_x0[k]<=0;shrink_x1[k]<=0;shrink_y0[k]<=0;shrink_y1[k]<=0;
   end
  end else begin
   vs_d<=vs;de_d<=de;pixel_we<=0;start<=0;empty<=0;sequence_start<=0;sequence_done<=0;
   if(sof)begin vx<=0;vy<=0;end else if(de&&valid)vx<=px+2;else if(de_d&&!de)begin vx<=0;vy<=vy+1;end
   if(sof&&history_valid)begin
    if(history_age>=CROP_HISTORY_FRAMES-1)history_valid<=0;
    else history_age<=history_age+1'b1;
   end
   if(!enable)begin state<=IDLE;selection_valid<=0;history_valid<=0;crop_ready<=0;end
   else case(state)
    IDLE:if(sof&&!inference_busy)begin state<=CAP;expression_mode<=expression_enable;expression_bad<=0;sequence_start<=1;token_index<=0;token_count<=0;overflow<=0;best_valid<=0;best_cells<=0;best_distance<=1023;component_count<=0;candidate_count<=0;noise_rejected<=0;reject_reason<=0;crop_ready<=0;if(!expression_enable)history_valid<=0;end
    CAP:begin if(de&&valid&&inside_roi)columns[capx]<=total;if(sof)begin scanx<=0;scany<=0;state<=SA;end end
    SA:state<=SW;
    SW:state<=SE;
    SE:if(gq==2'b01)begin members[0]<=scan_addr;head<=0;tail<=1;queued<=1;component_cells<=1;cminx<=scanx;cmaxx<=scanx;cminy<=scany;cmaxy<=scany;state<=PC;end else state<=ADV;
    PC:state<=queued!=0?PA:CD;
    PA:state<=PW;
    PW:state<=PL;
    PL:begin cx<=fq[7:0];cy<=fq[15:8];head<=head+1'b1;queued<=queued-1'b1;nb<=0;state<=NA;end
    NA:state<=NW;
    NW:state<=NE;
    NE:begin
     nb<=nb+1'b1;state<=nb==7?PC:NA;
     if(nb_valid&&gq==2'b01)begin
      if(queued==QUEUE_DEPTH)begin overflow<=1;empty<=1;selection_valid<=0;reject_reason<=4;state<=IDLE;end
      else begin
       queued<=queued+1'b1;tail<=tail+1'b1;component_cells<=component_cells+1;
       if(nbx<cminx)cminx<=nbx;if(nbx>cmaxx)cmaxx<=nbx;if(nby<cminy)cminy<=nby;if(nby>cmaxy)cmaxy<=nby;
       if(component_cells<MIN_COMPONENT_CELLS)members[component_cells]<=nb_addr;
       if(component_cells==MIN_COMPONENT_CELLS-1)begin mi<=0;resume<=nb==7?PC:NA;state<=PROMOTE;end
      end
     end
    end
    PROMOTE:if(mi==MIN_COMPONENT_CELLS-1)state<=resume;else mi<=mi+1;
    CD:begin
     if(component_cells<MIN_COMPONENT_CELLS)begin mi<=0;state<=ERASE;if(expression_mode&&noise_rejected!=255)noise_rejected<=noise_rejected+1'b1;end
     else begin
      if(filtered_expression)begin
       if(component_count==MAX_EXPRESSION_COMPONENTS)begin overflow<=1;empty<=1;selection_valid<=0;reject_reason<=4;state<=IDLE;end
       else begin
        comp_x0[component_count[4:0]]<=cminx;comp_x1[component_count[4:0]]<=cmaxx;
        comp_y0[component_count[4:0]]<=cminy;comp_y1[component_count[4:0]]<=cmaxy;
        comp_large[component_count[4:0]]<=component_cells>MAX_CELLS;
        comp_touch[component_count[4:0]]<=cminx==0||cminy==0||cmaxx==G-1||cmaxy==G-1;
        component_count<=component_count+1'b1;candidate_count<=component_count+1'b1;state<=ADV;
       end
      end else begin if(component_cells>MAX_CELLS||cminx==0||cminy==0||cmaxx==G-1||cmaxy==G-1)expression_bad<=1;state<=ADV;end
      if(component_ok&&(!best_valid||(encloses_best&&component_cells>best_cells)||(!inside_best&&(centre_distance<best_distance||(centre_distance==best_distance&&component_cells>best_cells)))))begin best_valid<=1;best_cells<=component_cells;best_distance<=centre_distance;xmin<=cminx;xmax<=cmaxx;ymin<=cminy;ymax<=cmaxy;end
     end
    end
    ERASE:if(mi==component_cells-1)state<=ADV;else mi<=mi+1;
    ADV:if(scanx==G-1)begin scanx<=0;if(scany==G-1)state<=SELECT;else begin scany<=scany+1;state<=SA;end end else begin scanx<=scanx+1;state<=SA;end
    SELECT:if(expression_mode)begin if(filtered_expression)state<=LINE_INIT;else if(expression_bad)begin empty<=1;selection_valid<=0;reject_reason<=3;state<=IDLE;end else state<=EX_INIT;end else if(!best_valid)begin empty<=1;selection_valid<=0;reject_reason<=5;state<=IDLE;end else begin selection_valid<=1;selected_xmin<=xmin;selected_xmax<=xmax;selected_ymin<=ymin;selected_ymax<=ymax;oi<=0;ox<=0;oy<=0;side<=longest;padx<=(longest-bw)>>1;pady<=(longest-bh)>>1;state<=TILE;end
    TILE:if(ox<4||ox>=24||oy<4||oy>=24)begin pixel_we<=1;pixel_addr<=oi;pixel_bit<=0;if(oi==783)state<=START;else begin oi<=oi+1;if(ox==27)begin ox<=0;oy<=oy+1;end else ox<=ox+1;end end
     else begin ax<=bx0;ay<=by0;tx0<=bx0;tx1<=endx;ty1<=endy;tile_w<=endx-bx0;tile_h<=endy-by0;state<=AREA;end
    AREA:begin area<=tile_w*tile_h;ones<=0;state<=RA;end
    RA:state<=RW;
    RW:state<=ACC;
    ACC:begin ones<=next_ones;if(ax==tx1-1)begin ax<=tx0;if(ay==ty1-1)begin tile_bit<=next_ones!=0;state<=EMIT;end else begin ay<=ay+1;state<=RA;end end else begin ax<=ax+1;state<=RA;end end
    EMIT:begin pixel_we<=1;pixel_addr<=oi;pixel_bit<=tile_bit;oi<=oi+1;ox<=ox+1;state<=TILE;end
    START:begin start<=1;state<=WAIT_NN;end
    WAIT_NN:if(!inference_busy&&!start)begin
     if(expression_mode)begin
      if(token_index+1<token_count)begin token_index<=token_index+1'b1;state<=EX_LOAD;end
      else begin sequence_done<=1;state<=IDLE;end
     end else state<=IDLE;
    end
    // Score geometrically compatible, horizontally separate anchors. This is
    // independent of recognized labels and arithmetic legality. One large
    // unrelated component cannot select the row by itself.
    LINE_INIT:begin ci<=0;line_best<=0;line_best_score<=0;line_ambiguous<=0;state<=LINE_REF;end
    LINE_REF:if(ci>=component_count)state<=LINE_FINAL;
     else if(i_anchor)begin cj<=0;line_score<=1;state<=LINE_SCAN;end
     else ci<=ci+1'b1;
    LINE_SCAN:if(cj>=component_count)state<=LINE_EVAL;
     else begin if(pair_support)line_score<=line_score+1'b1;cj<=cj+1'b1;end
    LINE_EVAL:begin
     if(line_score>=2)begin
      if(line_score>line_best_score)begin line_best<=ci[4:0];line_best_score<=line_score;line_ambiguous<=0;end
      else if(line_score==line_best_score)begin
       if(disjoint_best)line_ambiguous<=1;
       if(ih>best_height)line_best<=ci[4:0];
      end
     end
     ci<=ci+1'b1;state<=LINE_REF;
    end
    LINE_FINAL:if(line_best_score<2||line_ambiguous)begin
     empty<=1;selection_valid<=0;reject_reason<=component_count==0?4'd5:4'd1;state<=IDLE;
    end else begin
     line_height<=best_height[7:0];
     line_y0<=comp_y0[line_best]>(best_height>>2)?comp_y0[line_best]-(best_height>>2):0;
     line_y1<=comp_y1[line_best]+(best_height>>2)<G?comp_y1[line_best]+(best_height>>2):G-1;
     state<=CLASS_INIT;
    end
    CLASS_INIT:begin ci<=0;keep_components<=0;base_components<=0;state<=CLASSIFY;end
    CLASSIFY:if(ci>=component_count)state<=ASSOC_INIT;
     else begin
      ci<=ci+1'b1;
      if(row_intersects&&!tiny_component)begin
       if(comp_touch[ci[4:0]]||comp_large[ci[4:0]])begin
        empty<=1;selection_valid<=0;reject_reason<=3;state<=IDLE;
       end else begin keep_components[ci[4:0]]<=1;base_components[ci[4:0]]<=1;end
      end
     end
    ASSOC_INIT:begin ci<=0;cj<=0;state<=ASSOC_SCAN;end
    // Compact tiny dots are removed even inside a digit hole. Tiny detached
    // stroke fragments may join a nearby body only when strongly elongated.
    // Full-sized inner contours remain base components and are never erased.
    ASSOC_SCAN:if(ci>=component_count)state<=MASK_INIT;
     else if(keep_components[ci[4:0]])begin ci<=ci+1'b1;cj<=0;end
     else if(row_intersects&&tiny_component&&stroke_fragment&&cj<component_count)begin
      if(base_components[cj[4:0]]&&near_base)begin keep_components[ci[4:0]]<=1;state<=ASSOC_DONE;end
      else cj<=cj+1'b1;
     end else state<=ASSOC_DONE;
    ASSOC_DONE:begin
     if(!keep_components[ci[4:0]]&&noise_rejected!=255)noise_rejected<=noise_rejected+1'b1;
     ci<=ci+1'b1;cj<=0;state<=ASSOC_SCAN;
    end
    MASK_INIT:begin scanx<=0;scany<=0;state<=MASK_RA;end
    MASK_RA:state<=MASK_RW;
    MASK_RW:state<=MASK_ACC;
    MASK_ACC:if(scanx==G-1)begin
     scanx<=0;if(scany==G-1)state<=EX_INIT;else begin scany<=scany+1'b1;state<=MASK_RA;end
    end else begin scanx<=scanx+1'b1;state<=MASK_RA;end
    EX_INIT:begin scanx<=0;scany<=0;segments<=0;run_valid<=0;gap<=0;col_any<=0;col_y0<=G-1;col_y1<=0;state<=EX_RA;end
    EX_RA:state<=EX_RW;
    EX_RW:state<=EX_ACC;
    EX_ACC:begin
     if(gq==2'b10)begin col_any<=1;if(scany<col_y0)col_y0<=scany;if(scany>col_y1)col_y1<=scany;end
     if(scany==G-1)state<=EX_COL;else begin scany<=scany+1'b1;state<=EX_RA;end
    end
    EX_COL:begin
     if(col_any)begin
      gap<=0;run_valid<=1;run_x1<=scanx;
      if(!run_valid)begin run_x0<=scanx;run_y0<=col_y0;run_y1<=col_y1;end
      else begin if(col_y0<run_y0)run_y0<=col_y0;if(col_y1>run_y1)run_y1<=col_y1;end
     end else if(run_valid)begin
      if(gap)begin
       if(segments==5)expression_bad<=1;
       else begin sx0[segments]<=run_x0;sx1[segments]<=run_x1;sy0[segments]<=run_y0;sy1[segments]<=run_y1;segments<=segments+1'b1;end
       run_valid<=0;
      end else gap<=1;
     end
     state<=EX_ADV;
    end
    EX_ADV:begin
     scany<=0;col_any<=0;col_y0<=G-1;col_y1<=0;
     if(scanx==G-1)state<=EX_TAIL;else begin scanx<=scanx+1'b1;state<=EX_RA;end
    end
    EX_TAIL:begin
     if(run_valid)begin
      if(segments==5)expression_bad<=1;
      else begin sx0[segments]<=run_x0;sx1[segments]<=run_x1;sy0[segments]<=run_y0;sy1[segments]<=run_y1;segments<=segments+1'b1;end
     end
     state<=EX_CHECK;
    end
    EX_CHECK:if(expression_bad||segments<3)begin empty<=1;selection_valid<=0;reject_reason<=expression_bad?4'd2:4'd5;state<=IDLE;end
     else begin token_count<=segments;token_index<=0;state<=filtered_expression?OWNER_INIT:TRACK_INIT;end
    OWNER_INIT:begin
     for(integer k=0;k<32;k=k+1)comp_owner[k]<=3'd7;
     ci<=0;owner_token<=0;state<=OWNER_SCAN;
    end
    OWNER_SCAN:if(ci>=component_count)begin token_index<=0;state<=TRACK_INIT;end
     else if(owner_token>=token_count)begin ci<=ci+1'b1;owner_token<=0;end
     else if(keep_components[ci[4:0]]&&comp_x0[ci[4:0]]>=sx0[owner_token]&&comp_x1[ci[4:0]]<=sx1[owner_token]&&
      comp_y0[ci[4:0]]>=sy0[owner_token]&&comp_y1[ci[4:0]]<=sy1[owner_token])begin
      comp_owner[ci[4:0]]<=owner_token;ci<=ci+1'b1;owner_token<=0;
     end else owner_token<=owner_token+1'b1;
    TRACK_INIT:begin tracking_match<=history_valid&&history_count==token_count;token_index<=0;state<=TRACK_MATCH;end
    TRACK_MATCH:begin
     if(!coordinate_near(sx0[token_index],history_x0[token_index])||!coordinate_near(sx1[token_index],history_x1[token_index])||
        !coordinate_near(sy0[token_index],history_y0[token_index])||!coordinate_near(sy1[token_index],history_y1[token_index]))tracking_match<=0;
     if(token_index+1==token_count)begin token_index<=0;state<=TRACK_LOAD;end
     else token_index<=token_index+1'b1;
    end
    TRACK_LOAD:begin xmin<=sx0[token_index];xmax<=sx1[token_index];ymin<=sy0[token_index];ymax<=sy1[token_index];state<=TRACK_CROP;end
    TRACK_CROP:begin
     stable_x0[token_index]<=next_x0;stable_x1[token_index]<=next_x1;stable_y0[token_index]<=next_y0;stable_y1[token_index]<=next_y1;
     // Match against the acquisition anchor, not only the preceding observation.
     // Otherwise slow drift could grow a held window indefinitely.
     if(!tracking_match||!CROP_STABILIZE)begin
      history_x0[token_index]<=xmin;history_x1[token_index]<=xmax;history_y0[token_index]<=ymin;history_y1[token_index]<=ymax;
     end
     shrink_x0[token_index]<=CROP_STABILIZE&&tracking_match&&shrink_l&&shrink_x0[token_index]<CROP_SHRINK_ANALYSES-1?shrink_x0[token_index]+1'b1:0;
     shrink_x1[token_index]<=CROP_STABILIZE&&tracking_match&&shrink_r&&shrink_x1[token_index]<CROP_SHRINK_ANALYSES-1?shrink_x1[token_index]+1'b1:0;
     shrink_y0[token_index]<=CROP_STABILIZE&&tracking_match&&shrink_t&&shrink_y0[token_index]<CROP_SHRINK_ANALYSES-1?shrink_y0[token_index]+1'b1:0;
     shrink_y1[token_index]<=CROP_STABILIZE&&tracking_match&&shrink_b&&shrink_y1[token_index]<CROP_SHRINK_ANALYSES-1?shrink_y1[token_index]+1'b1:0;
     if(token_index+1==token_count)begin token_index<=0;state<=TRACK_DONE;end
     else begin token_index<=token_index+1'b1;state<=TRACK_LOAD;end
    end
    TRACK_DONE:begin history_valid<=1;history_count<=token_count;history_age<=0;crop_ready<=1;state<=EX_LOAD;end
    EX_LOAD:begin xmin<=sx0[token_index];xmax<=sx1[token_index];ymin<=sy0[token_index];ymax<=sy1[token_index];state<=EX_NORM;end
    EX_NORM:begin selection_valid<=1;selected_xmin<=xmin;selected_xmax<=xmax;selected_ymin<=ymin;selected_ymax<=ymax;oi<=0;ox<=0;oy<=0;side<=longest;padx<=(longest-bw)>>1;pady<=(longest-bh)>>1;state<=TILE;end
    default:state<=IDLE;
   endcase
  end
 end
 // synthesis translate_off
 initial if(G<8||G>255||ROI_SIZE%4||ROI_X%4||ROI_Y%4||ROI_X<0||ROI_Y<0||ROI_X+ROI_SIZE>IMG_W||ROI_Y+ROI_SIZE>IMG_H||MIN_COMPONENT_CELLS<2||MIN_COMPONENT_CELLS>255||QUEUE_DEPTH<2||2**QW!=QUEUE_DEPTH||CROP_PAD_CELLS<0||CROP_PAD_CELLS>G||MAX_EXPRESSION_COMPONENTS<3||MAX_EXPRESSION_COMPONENTS>32||CROP_DEADBAND_CELLS<0||CROP_SHRINK_ANALYSES<1||CROP_SHRINK_ANALYSES>255||CROP_MATCH_CELLS<1||CROP_HISTORY_FRAMES<1||CROP_HISTORY_FRAMES>255)$fatal(1,"unsupported geometry/queue/padding/candidate count/stabilization");
 // synthesis translate_on
endmodule
