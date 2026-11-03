// Stage-one contour architecture: 2-bit compact bitmap, ordered Moore border
// tracing, 64 point resampling, circle/ellipse residual and closed-polygon RDP.
// No pixel flood-fill queue, RGB threshold, area-ratio classifier or type mask.
module shape_contour_detector #(
 parameter integer IMG_W=1920,IMG_H=1080,CELL_LOG2=3,STABLE_RESULTS=2,
 parameter integer MIN_EDGE_PIXELS=2, ELLIPSE_ERROR_PERCENT=60,
 parameter integer QUAD_DOT_FACTOR=2
)(
 input wire clk,rst_n,enable,input wire [15:0] edge_bits,
 input wire de,valid,vs,output reg [2:0] pending_types,
 output wire result_ready,input wire result_ack,output wire done,busy,
 output wire color_start,color_write,output wire [7:0] color_x,color_y,
 output wire [1:0] color_class,output wire [7:0] color_query_x,color_query_y,
 input wire [1:0] color_neighbor_class
);
 localparam CELL=1<<CELL_LOG2,COLS=(IMG_W+CELL-1)/CELL,ROWS=(IMG_H+CELL-1)/CELL;
 localparam CELLS=COLS*ROWS,AW=$clog2(CELLS),LW=$clog2(CELLS*4+1);
 localparam IDLE=0,CAPTURE=1,SCAN_R=2,SCAN_C=3,NEXT_SCAN=4,SPAN_INIT=5,
  SPAN_R=6,SPAN_W=7,NEIGH_R=8,NEIGH_C=9,TRACE_END=10,RADIAL=11,
  FAR_INIT=12,FAR_SCAN=13,SEG_SETUP=14,SEG_POP=15,SEG_INIT=16,SEG_SCAN=17,
  SEG_TEST=18,MERGE_INIT=19,MERGE_SCAN=20,MERGE_SHIFT=21,POLY_INIT=22,
  POLY_SCAN=23,CANDIDATE=24,FILL_R=25,FILL_C=26,FILL_W=27,FINISH=28,WAIT_COMMIT=29;
 localparam P_A_R=30,P_A_C=31,P_B_R=32,P_B_C=33,FAR_R=34,SEG_R=35,
  MERGE_SHORT=36,MERGE_CHORD=37,MERGE_VALUE=38,POLY_CROSS=39,POLY_DOT=40,
  POLY_LEN1=41,POLY_LEN2=42,RAD_INIT=43,RAD_R=44,RAD_C=45, MOM_XY=46,
  ELL_INIT=47,ELL_DET=48,ELL_ASPECT=49,ELL_R=50,ELL_X=51,
  ELL_Y=52,ELL_XY=53,ELL_ACC=54,ELL_DONE=55,ELL_PRE=56,
  TRI_INIT=57,TRI_AREA=58,TRI_R=59,TRI_CROSS=60,TRI_DOT=61,
  TRI_TEST=62,TRI_POINT=63,TRI_DONE=64,QUAD_AREA1=65,QUAD_AREA2=66,QUAD_AREA_TEST=67,OBB_INIT=68,OBB_RESET=69,OBB_R=70,OBB_U=71,OBB_V=72,OBB_TEST=73,COLOR_MARK=74,
  NEAR_R=75,NEAR_C=76,NEAR_DONE=77,RESCUE_BEGIN=78,RESCUE_BUILD=79,RESCUE_NEXT=80;
 reg [6:0] state;
 reg vs_d,de_d,seen_high;reg [11:0] x,y;
 wire [11:0] px=de_d?x:12'd0;
 wire sof=vs_d&&!vs;
 wire [7:0] capture_col=px>>CELL_LOG2;
 wire first_pair=px[CELL_LOG2-1:0]==0;
 wire last_pair=px[CELL_LOG2-1:0]==CELL-2||px==IMG_W-2;
 wire first_row=y[CELL_LOG2-1:0]==0;
 wire last_row=y[CELL_LOG2-1:0]==CELL-1||y==IMG_H-1;
 wire [1:0] edge_samples={1'b0,(edge_bits[7:0]==255)}+{1'b0,(edge_bits[15:8]==255)};
 (* syn_ramstyle="block_ram",syn_ramdecomp="area" *) reg [8:0] columns[0:COLS-1];
 reg [8:0] column_q;reg [5:0] horizontal;
 wire [8:0] row_count=(first_pair?6'd0:horizontal)+edge_samples;
 wire [8:0] total_count=(first_row?9'd0:column_q)+row_count;
 wire capture_write=state==CAPTURE&&de&&valid&&last_pair&&last_row;
 wire [AW-1:0] capture_addr=(y>>CELL_LOG2)*COLS+capture_col;
 // bit0 pooled edge, bit1 visited. No wholesale reset: capture overwrites all.
 (* syn_ramstyle="block_ram",syn_ramdecomp="area" *) reg [1:0] bitmap[0:CELLS-1];
 reg [1:0] map_q;
 reg [AW-1:0] scan;reg [7:0] scan_x,scan_y;reg scan_previous;
 reg [7:0] cur_x,cur_y,start_x,start_y,first_x,first_y;
 reg first_valid,second_pass,color_pass;reg [2:0] direction,attempt;
 reg [LW-1:0] steps,trace_length,sample_acc;
 reg [6:0] sample_count,sample_goal;
 reg signed [31:0] area2;
 wire [31:0] abs_area;
 reg [7:0] left,right,top,bottom,bw,bh,epsilon;
 reg [1:0] candidate_shape;
 reg [2:0] raw_types;
 reg associated_contour;reg [LW:0] nearby_hits[0:2];
 reg [3:0] near_index;reg [2:0] near_types;
 reg [7:0] near_x,near_y;reg near_valid;
 always @* begin
  near_x=cur_x;near_y=cur_y;near_valid=1;
  case(near_index%3)
   0:begin near_x=cur_x-2;near_valid=cur_x>=2;end
   2:begin near_x=cur_x+2;near_valid=cur_x+2<COLS;end
   default:begin end
  endcase
  case(near_index/3)
   0:begin near_y=cur_y-2;near_valid=near_valid&&cur_y>=2;end
   2:begin near_y=cur_y+2;near_valid=near_valid&&cur_y+2<ROWS;end
   default:begin end
  endcase
 end
 // Keep radial evidence while independently checking the polygon model.
 reg round_candidate,quad_conflict;reg [20:0] quad_area_part,quad_area;
 // Rotation-aware rectangularity: projected enclosing rectangles in 16
 // directions. The original trace area fills a square, but not a circle.
 reg [3:0] obb_index;reg signed [12:0] obb_umin,obb_umax,obb_vmin,obb_vmax;
 reg signed [9:0] obb_a,obb_b;reg [7:0] obb_norm;
 always @* begin
  case(obb_index)
   0:begin obb_a=1;obb_b=0;obb_norm=1;end
   1:begin obb_a=8;obb_b=1;obb_norm=65;end
   2:begin obb_a=4;obb_b=1;obb_norm=17;end
   3:begin obb_a=8;obb_b=3;obb_norm=73;end
   4:begin obb_a=2;obb_b=1;obb_norm=5;end
   5:begin obb_a=8;obb_b=5;obb_norm=89;end
   6:begin obb_a=4;obb_b=3;obb_norm=25;end
   7:begin obb_a=8;obb_b=7;obb_norm=113;end
   8:begin obb_a=1;obb_b=1;obb_norm=2;end
   9:begin obb_a=7;obb_b=8;obb_norm=113;end
   10:begin obb_a=3;obb_b=4;obb_norm=25;end
   11:begin obb_a=5;obb_b=8;obb_norm=89;end
   12:begin obb_a=1;obb_b=2;obb_norm=5;end
   13:begin obb_a=3;obb_b=8;obb_norm=73;end
   14:begin obb_a=1;obb_b=4;obb_norm=17;end
   default:begin obb_a=1;obb_b=8;obb_norm=65;end
  endcase
 end
 reg strict_matched;reg [6:0] strict_supported;reg [6:0] strict_hits[0:3];
 reg [7:0] age[0:2];integer ti;
 // Diagnostic flags for verification; not extra on-screen controls.
 reg trace_overflow,geometry_overflow;
 reg [15:0] examined_contours,accepted_contours;
 (* syn_ramstyle="block_ram",syn_ramdecomp="area" *) reg [15:0] points[0:63];
 (* syn_ramstyle="registers" *) reg [13:0] stack[0:15];
 (* syn_ramstyle="registers" *) reg [15:0] vertices[0:7];
 reg [20:0] radius_min,radius_max;reg [26:0] radius_sum;
 // Centred second moments estimate ellipse orientation, including rotated
 // ellipses. Coefficients are normalised together; no divider or trig unit.
 reg [26:0] cov_xx,cov_yy;reg signed [26:0] cov_xy;
 reg [9:0] ell_xx,ell_yy;reg signed [10:0] ell_xy;
 reg [20:0] ell_det;reg [31:0] ell_q;
 reg [4:0] moment_shift;integer mi;
 always @* begin
  moment_shift=0;
  for(mi=10;mi<27;mi=mi+1)
   if(cov_xx[mi]||cov_yy[mi]) moment_shift=mi-9;
 end
 wire [10:0] ell_absxy=ell_xy[10]?-ell_xy:ell_xy;
 wire [10:0] ell_trace={1'b0,ell_xx}+{1'b0,ell_yy};
 reg [6:0] point_i,pivot,seg_a,seg_b,max_index;
 reg [4:0] stack_count;
 reg [3:0] vertex_count,merge_i,shift_i,poly_i;
 reg [17:0] far_distance,length_sq;
 reg [18:0] max_cross;
 reg [15:0] endpoint_a,endpoint_b;
 reg polygon_ok,sign_known,cross_sign;
 reg [15:0] point_q,origin;
 reg [17:0] merge_short,merge_length,poly_len1,poly_len2;
 reg [18:0] merge_abs_reg,poly_absdot_reg;
 // Validate the final triangle against the pre-simplification contour.
 // Counts and quarter-edge bins are independent for all finite sides; triangle and quadrilateral validation share this unit.
 reg [17:0] tri_edge_length[0:3];
 reg [6:0] tri_side_hits[0:3];reg [3:0] tri_bins[0:3];
 reg [6:0] tri_supported;reg tri_matched;
 reg signed [20:0] tri_projection;
reg [15:0] triangle_rejections;
 // A quantised triangle tip can leave one tiny fourth side. Keep the
 // quadrilateral in vertices[4:7], and verify both endpoint-removal models.
 reg rescue_active,rescue_checked,best_triangle_valid;reg [4:0] rescue_trial;
 reg [1:0] rescue_short_index;
 reg [6:0] best_support,best_strict;
 reg [6:0] quad_support_ref,quad_strict_ref;
 reg [20:0] trial_area,best_area_error;
 reg [15:0] best_v0,best_v1,best_v2;
 reg [6:0] straight_mid_hits[0:3];
 reg [17:0] shortest_sq,second_shortest_sq;reg [1:0] shortest_index;
 integer si;
 always @* begin
  shortest_sq=tri_edge_length[0];second_shortest_sq=18'h3ffff;shortest_index=0;
  for(si=1;si<4;si=si+1) begin
   if(tri_edge_length[si]<shortest_sq) begin
    second_shortest_sq=shortest_sq;shortest_sq=tri_edge_length[si];shortest_index=si;
   end else if(tri_edge_length[si]<second_shortest_sq) second_shortest_sq=tri_edge_length[si];
  end
 end
 wire [20:0] trial_area_error=trial_area>abs_area?trial_area-abs_area:abs_area-trial_area;
 wire [1:0] rescue_drop=rescue_trial==1?rescue_short_index:(rescue_short_index==3?2'd0:rescue_short_index+1'b1);
 wire [15:0] rescue_end_a=vertices[4+rescue_short_index];
 wire [15:0] rescue_end_b=vertices[4+(rescue_short_index==3?0:rescue_short_index+1)];
 wire [8:0] rescue_mid_x=({1'b0,rescue_end_a[15:8]}+{1'b0,rescue_end_b[15:8]})>>1;
 wire [8:0] rescue_mid_y=({1'b0,rescue_end_a[7:0]}+{1'b0,rescue_end_b[7:0]})>>1;
 function signed [9:0] tip_offset;
  input [4:0] i;input [7:0] e;
  begin case(i) 0:tip_offset=-$signed({2'b0,e});1:tip_offset=-$signed(({2'b0,e}+1)>>1);
   2:tip_offset=0;3:tip_offset=({2'b0,e}+1)>>1;default:tip_offset={2'b0,e};endcase end
 endfunction
 wire [4:0] rescue_grid=rescue_trial>=2?rescue_trial-2:0;
 wire signed [9:0] tip_x=$signed({1'b0,rescue_mid_x})+tip_offset(rescue_grid%5,epsilon);
 wire signed [9:0] tip_y=$signed({1'b0,rescue_mid_y})+tip_offset(rescue_grid/5,epsilon);
 wire [7:0] tip_clamped_x=tip_x<0?0:tip_x>=COLS?COLS-1:tip_x[7:0];
 wire [7:0] tip_clamped_y=tip_y<0?0:tip_y>=ROWS?ROWS-1:tip_y[7:0];
 wire [18:0] rescue_size_limit;
 wire try_triangle_tip;
 wire [4:0] tri_tolerance;
 wire [9:0] tri_tolerance_squared;
 function [2:0] count_bins;
  input [3:0] b;
  begin count_bins={2'b0,b[0]}+{2'b0,b[1]}+{2'b0,b[2]}+{2'b0,b[3]};end
 endfunction
 wire [20:0] tri_project4=tri_projection<<2;
 wire [19:0] tri_len_ext={2'b0,tri_edge_length[poly_i]};
 wire [1:0] tri_bin=tri_project4<tri_len_ext?0:
  tri_project4<(tri_len_ext<<1)?1:tri_project4<tri_len_ext*3?2:3;
 wire tri_edge_coverage=tri_side_hits[0]>=3&&tri_side_hits[1]>=3&&tri_side_hits[2]>=3&&
  count_bins(tri_bins[0])>=3&&count_bins(tri_bins[1])>=3&&count_bins(tri_bins[2])>=3&&
  tri_bins[0][0]&&tri_bins[0][3]&&tri_bins[1][0]&&tri_bins[1][3]&&tri_bins[2][0]&&tri_bins[2][3]&&
  (vertex_count!=4||(tri_side_hits[3]>=3&&count_bins(tri_bins[3])>=3&&tri_bins[3][0]&&tri_bins[3][3]));
 wire [23:0] strict_edge_limit=tri_edge_length[poly_i]*9;
 wire strict_quad_support=strict_supported*100>=sample_count*70&&
  strict_hits[0]>=2&&strict_hits[1]>=2&&strict_hits[2]>=2&&strict_hits[3]>=2&&
  strict_hits[0]*2>=tri_side_hits[0]&&strict_hits[1]*2>=tri_side_hits[1]&&
  strict_hits[2]*2>=tri_side_hits[2]&&strict_hits[3]*2>=tri_side_hits[3];
 // One vector datapath (two signed products) is time-multiplexed across all
 // point-distance, line-cross-product, angle and radial measurements.
 reg [15:0] ga,gb,gp;reg [2:0] gmode;
 reg signed [9:0] gux,guy,gvx,gvy;
 wire signed [19:0] gm0=gux*(gmode==5?obb_a:gmode==6?obb_b:gmode==4?guy:gmode==1?gvy:gmode==2?gvx:gux);
 wire signed [19:0] gm1=guy*(gmode==5?obb_b:gmode==6?obb_a:gmode==4?10'sd0:gmode==1?gvx:gmode==2?gvy:guy);
 wire signed [20:0] gvalue=gmode==1?$signed(gm0)-$signed(gm1):gmode==6?$signed(gm1)-$signed(gm0):$signed(gm0)+$signed(gm1);
 wire [20:0] gabs=gvalue[20]?-gvalue:gvalue;
 reg [7:0] next_x,next_y;reg neighbour_ok;
 always @* begin
  next_x=cur_x;next_y=cur_y;neighbour_ok=1;
  case(direction)
   0:begin next_x=cur_x-1'b1;neighbour_ok=cur_x>0;end
   1:begin next_x=cur_x-1'b1;next_y=cur_y-1'b1;neighbour_ok=cur_x>0&&cur_y>0;end
   2:begin next_y=cur_y-1'b1;neighbour_ok=cur_y>0;end
   3:begin next_x=cur_x+1'b1;next_y=cur_y-1'b1;neighbour_ok=cur_x<COLS-1&&cur_y>0;end
   4:begin next_x=cur_x+1'b1;neighbour_ok=cur_x<COLS-1;end
   5:begin next_x=cur_x+1'b1;next_y=cur_y+1'b1;neighbour_ok=cur_x<COLS-1&&cur_y<ROWS-1;end
   6:begin next_y=cur_y+1'b1;neighbour_ok=cur_y<ROWS-1;end
   7:begin next_x=cur_x-1'b1;next_y=cur_y+1'b1;neighbour_ok=cur_x>0&&cur_y<ROWS-1;end
  endcase
 end
 wire [AW-1:0] neighbour_addr=neighbour_ok?next_y*COLS+next_x:0;
 wire [AW-1:0] read_addr=state==NEIGH_R?neighbour_addr:scan;
 wire visit_write=state==SPAN_W&&!second_pass;
 wire [AW-1:0] write_addr=capture_write?capture_addr:cur_y*COLS+cur_x;
 wire [15:0] cur_point={cur_x,cur_y};
 wire sample_emit=state==NEIGH_C&&neighbour_ok&&map_q[0]&&second_pass&&!color_pass&&
  !(first_valid&&cur_x==start_x&&cur_y==start_y&&next_x==first_x&&next_y==first_y)&&sample_acc>=trace_length&&sample_count<64;
 wire [5:0] point_read_addr=state==P_A_R?seg_a[5:0]:state==P_B_R?(seg_b==sample_count?6'd0:seg_b[5:0]):point_i[5:0];
 wire [15:0] merge_prev=vertices[merge_i==0?vertex_count-1:merge_i-1];
 wire [15:0] merge_cur=vertices[merge_i],merge_next=vertices[merge_i+1==vertex_count?0:merge_i+1];
 wire [15:0] poly_prev=vertices[poly_i==0?vertex_count-1:poly_i-1];
 wire [15:0] poly_cur=vertices[poly_i],poly_next=vertices[poly_i+1==vertex_count?0:poly_i+1];
 always @* begin
  ga=0;gb=0;gp=0;gmode=0;
  case(state)
   FAR_SCAN:begin ga=origin;gb=point_q;end
   P_B_C:begin ga=endpoint_a;gb=point_q;end
   SEG_SCAN:begin ga=endpoint_a;gb=endpoint_b;gp=point_q;gmode=1;end
   MERGE_SHORT:begin ga=merge_prev;gb=merge_cur;end
   MERGE_CHORD:begin ga=merge_prev;gb=merge_next;end
   MERGE_VALUE:begin ga=merge_prev;gb=merge_next;gp=merge_cur;gmode=1;end
   POLY_CROSS:begin ga=poly_prev;gb=poly_cur;gp=poly_next;gmode=1;end
   POLY_DOT:begin ga=poly_prev;gb=poly_cur;gp=poly_next;gmode=2;end
   POLY_LEN1:begin ga=poly_prev;gb=poly_cur;end
   POLY_LEN2:begin ga=poly_cur;gb=poly_next;end
   QUAD_AREA1:begin ga=vertices[0];gb=vertices[1];gp=vertices[2];gmode=1;end
   QUAD_AREA2:begin ga=vertices[0];gb=vertices[2];gp=vertices[3];gmode=1;end
   OBB_U,OBB_V:begin ga={left,top};gb=point_q;gmode=state==OBB_U?5:6;end
   TRI_AREA:begin ga=vertices[0];gb=vertices[1];gp=vertices[2];gmode=1;end
   TRI_CROSS,TRI_DOT:begin ga=vertices[poly_i];gb=vertices[poly_i==vertex_count-1?0:poly_i+1];gp=point_q;gmode=state==TRI_CROSS?1:2;end
   RAD_C,ELL_PRE:begin gb=point_q;gmode=3;end
   MOM_XY,ELL_Y:begin gb=point_q;gmode=4;end
   default:begin end
  endcase
  gux=$signed({2'b0,gb[15:8]})-$signed({2'b0,ga[15:8]});
  guy=$signed({2'b0,gb[7:0]})-$signed({2'b0,ga[7:0]});
  gvx=$signed({2'b0,gp[15:8]})-$signed({2'b0,(gmode==2?gb[15:8]:ga[15:8])});
  gvy=$signed({2'b0,gp[7:0]})-$signed({2'b0,(gmode==2?gb[7:0]:ga[7:0])});
  if(gmode==3||gmode==4) begin
   gux=$signed({1'b0,gb[15:8],1'b0})-$signed({2'b0,left})-$signed({2'b0,right});
   guy=$signed({1'b0,gb[7:0],1'b0})-$signed({2'b0,top})-$signed({2'b0,bottom});
  end
 end
 // Two wide products are likewise shared by RDP tolerances, polygon angles
 // and normalised radial error, rather than inferred at every call site.
 reg [26:0] wa,wb,wc,wd;
 wire [53:0] wide_product=wa*wb,wide_limit=wc*wd;
wire [15:0] epsilon_squared=epsilon*epsilon;
 assign rescue_size_limit=({3'b0,epsilon_squared}+({11'b0,epsilon}<<1)+1'b1)<<1;
 assign try_triangle_tip=!round_candidate&&!rescue_active&&!rescue_checked&&
  shortest_sq>0&&shortest_sq<=rescue_size_limit&&({4'b0,shortest_sq}<<4)<=second_shortest_sq&&
  straight_mid_hits[shortest_index]<2;
 always @* begin
  wa=max_cross;wb=max_cross;wc=epsilon_squared;wd=length_sq;
  case(state)
   MERGE_SCAN:begin wa=merge_abs_reg;wb=merge_abs_reg;wd=merge_length;end
   POLY_SCAN:begin wa=poly_absdot_reg;wb=poly_absdot_reg;wc=poly_len1;wd=poly_len2;end
   RADIAL:begin wa=radius_max-radius_min;wb=sample_count;wc=radius_sum;wd=(bw>bh?bw:bh)<=12?55:40;end
   OBB_TEST:begin wa=$unsigned(obb_umax-obb_umin);wb=$unsigned(obb_vmax-obb_vmin);wc=abs_area;wd=obb_norm;end
   TRI_TEST:begin wa=max_cross;wb=max_cross;wc=tri_tolerance_squared;wd=tri_edge_length[poly_i];end
   ELL_DET:begin wa=ell_xx;wb=ell_yy;wc=ell_absxy;wd=ell_absxy;end
   ELL_ASPECT:begin wa=ell_trace;wb=ell_trace;wc=ell_det;wd=25;end
   ELL_X:begin wa=ell_yy;wb=merge_short;end
   ELL_Y:begin wa=ell_xx;wb=merge_length;end
   ELL_XY:begin wa=ell_absxy;wb=merge_abs_reg;end
   ELL_DONE:begin wa=radius_max-radius_min;wb=sample_count;wc=radius_sum;wd=ELLIPSE_ERROR_PERCENT;end
   default:begin end
  endcase
 end
 reg signed [31:0] edge_area;
 always @* begin
  case(direction)
   0:edge_area=$signed({1'b0,cur_y});
   1:edge_area=$signed({1'b0,cur_y})-$signed({1'b0,cur_x});
   2:edge_area=-$signed({1'b0,cur_x});
   3:edge_area=-$signed({1'b0,cur_x})-$signed({1'b0,cur_y});
   4:edge_area=-$signed({1'b0,cur_y});
   5:edge_area=$signed({1'b0,cur_x})-$signed({1'b0,cur_y});
   6:edge_area=$signed({1'b0,cur_x});
   default:edge_area=$signed({1'b0,cur_x})+$signed({1'b0,cur_y});
  endcase
 end
 assign abs_area=area2[31]?-area2:area2;
 wire [8:0] contour_width={1'b0,right}-{1'b0,left}+1'b1;
 wire [8:0] contour_height={1'b0,bottom}-{1'b0,top}+1'b1;
 wire [8:0] long_side=contour_width>contour_height?contour_width:contour_height;
 wire [8:0] short_side=contour_width<contour_height?contour_width:contour_height;
 wire [8:0] size_epsilon=(long_side>>5)+2;
 wire [8:0] thin_epsilon=(short_side>>3)+1;
 // Final support tolerance is tighter than the RDP simplification epsilon.
 // Half-cell units: 1.5 cells plus one cell per 32 cells of short side.
 assign tri_tolerance=3+((short_side>>5)<<1);
 assign tri_tolerance_squared=tri_tolerance*tri_tolerance;
 wire circle_aspect=bw*8<=bh*9&&bh*8<=bw*9;
 // Third contour walk emits only accepted boundary cells, never its interior.
 assign color_start=state==IDLE&&sof&&seen_high&&enable;
 assign color_write=state==COLOR_MARK&&enable;
 assign color_x=cur_x;assign color_y=cur_y;assign color_class=candidate_shape;
 assign color_query_x=(state==NEAR_R||state==NEAR_C)?(near_valid?near_x:8'd0):cur_x;
 assign color_query_y=(state==NEAR_R||state==NEAR_C)?(near_valid?near_y:8'd0):cur_y;
 assign busy=state!=IDLE;assign result_ready=state==WAIT_COMMIT;assign done=result_ready&&result_ack;
 // synthesis translate_off
 initial begin
  if(CELL_LOG2<2||CELL_LOG2>4||COLS<2||COLS>255||ROWS>255||IMG_W%2||STABLE_RESULTS<1||STABLE_RESULTS>255)
   $fatal(1,"Unsupported contour detector configuration");
 end
 // synthesis translate_on
 always @(posedge clk) begin
  if(sample_emit) points[sample_count[5:0]]<=cur_point;
  if(state==P_A_R||state==P_B_R||state==FAR_R||state==SEG_R||state==RAD_R||state==ELL_R||state==TRI_R||state==OBB_R) point_q<=points[point_read_addr];
  if(state==CAPTURE&&de&&valid) begin
   if(first_pair) column_q<=columns[capture_col];
   if(last_pair) columns[capture_col]<=total_count;
  end
  if(state==SCAN_R||state==NEIGH_R) map_q<=bitmap[read_addr];
  if(capture_write||visit_write)
   bitmap[write_addr]<=capture_write?{1'b0,total_count>=MIN_EDGE_PIXELS}:2'b11;

 end
 always @(posedge clk) begin
  if(!rst_n) begin
   state<=IDLE;vs_d<=0;de_d<=0;seen_high<=0;x<=0;y<=0;horizontal<=0;
   scan<=0;scan_x<=0;scan_y<=0;scan_previous<=0;cur_x<=0;cur_y<=0;start_x<=0;start_y<=0;
   first_x<=0;first_y<=0;first_valid<=0;second_pass<=0;color_pass<=0;direction<=0;attempt<=0;
   steps<=0;trace_length<=0;sample_acc<=0;sample_goal<=0;sample_count<=0;area2<=0;
   left<=0;right<=0;top<=0;bottom<=0;bw<=0;bh<=0;epsilon<=0;candidate_shape<=0;
   radius_min<=0;radius_max<=0;radius_sum<=0;cov_xx<=0;cov_yy<=0;cov_xy<=0;ell_xx<=0;ell_yy<=0;ell_xy<=0;ell_det<=0;ell_q<=0;point_i<=0;pivot<=0;far_distance<=0;
   seg_a<=0;seg_b<=0;stack_count<=0;vertex_count<=0;endpoint_a<=0;endpoint_b<=0;
   length_sq<=0;max_cross<=0;max_index<=0;merge_i<=0;shift_i<=0;poly_i<=0;polygon_ok<=0;sign_known<=0;cross_sign<=0;
   tri_supported<=0;tri_matched<=0;tri_projection<=0;triangle_rejections<=0;
   round_candidate<=0;quad_conflict<=0;quad_area_part<=0;quad_area<=0;obb_index<=0;obb_umin<=0;obb_umax<=0;obb_vmin<=0;obb_vmax<=0;strict_matched<=0;strict_supported<=0;
   for(ti=0;ti<4;ti=ti+1) begin tri_side_hits[ti]<=0;tri_bins[ti]<=0;tri_edge_length[ti]<=0;strict_hits[ti]<=0;end
   origin<=0;merge_short<=0;merge_length<=0;merge_abs_reg<=0;poly_len1<=0;poly_len2<=0;poly_absdot_reg<=0;raw_types<=0;pending_types<=0;trace_overflow<=0;geometry_overflow<=0;examined_contours<=0;accepted_contours<=0;
   for(ti=0;ti<3;ti=ti+1) age[ti]<=0;
   rescue_active<=0;rescue_checked<=0;rescue_trial<=0;best_triangle_valid<=0;rescue_short_index<=0;
   best_support<=0;best_strict<=0;quad_support_ref<=0;quad_strict_ref<=0;trial_area<=0;best_area_error<=0;best_v0<=0;best_v1<=0;best_v2<=0;
   for(ti=0;ti<4;ti=ti+1) straight_mid_hits[ti]<=0;
   associated_contour<=0;near_index<=0;near_types<=0;for(ti=0;ti<3;ti=ti+1) nearby_hits[ti]<=0;
  end else begin
   vs_d<=vs;de_d<=de;if(vs) seen_high<=1;
   if(sof) begin x<=0;y<=0;end
   else if(de&&valid) x<=px+2;
   else if(de_d&&!de) begin x<=0;y<=y+1'b1;end
   if(state==CAPTURE&&de&&valid) horizontal<=last_pair?0:row_count;
   case(state)
    IDLE:if(sof&&seen_high&&enable) begin state<=CAPTURE;raw_types<=0;horizontal<=0;trace_overflow<=0;geometry_overflow<=0;examined_contours<=0;accepted_contours<=0;triangle_rejections<=0;end
    CAPTURE:if(vs&&!vs_d) begin
     if(y==IMG_H) begin scan<=0;scan_x<=0;scan_y<=0;scan_previous<=0;state<=SCAN_R;end else state<=IDLE;
    end
    SCAN_R:state<=SCAN_C;
    SCAN_C:begin
     scan_previous<=map_q[0];
     if(map_q[0]&&!map_q[1]&&(scan_x==0||!scan_previous)) begin
      start_x<=scan_x;start_y<=scan_y;cur_x<=scan_x;cur_y<=scan_y;left<=scan_x;right<=scan_x;top<=scan_y;bottom<=scan_y;
      first_valid<=0;second_pass<=0;steps<=0;area2<=0;direction<=0;attempt<=0;candidate_shape<=0;round_candidate<=0;quad_conflict<=0;
      rescue_active<=0;rescue_checked<=0;best_triangle_valid<=0;
      color_pass<=0;associated_contour<=0;for(ti=0;ti<3;ti=ti+1) nearby_hits[ti]<=0;
      state<=SPAN_R;examined_contours<=examined_contours+1'b1;
     end else state<=NEXT_SCAN;
    end
    NEXT_SCAN:if(scan==CELLS-1) state<=FINISH;
     else begin
      scan<=scan+1'b1;
      if(scan_x==COLS-1) begin scan_x<=0;scan_y<=scan_y+1'b1;scan_previous<=0;end else scan_x<=scan_x+1'b1;
      state<=SCAN_R;
     end
    SPAN_R:state<=SPAN_W;
    SPAN_W:begin
     if(!second_pass) begin near_index<=0;near_types<=0;state<=NEAR_R;end
     else state<=color_pass?COLOR_MARK:NEIGH_R;
    end
    NEAR_R:state<=NEAR_C;
    NEAR_C:begin
     if(near_valid&&color_neighbor_class!=0) near_types[color_neighbor_class-1'b1]<=1;
     if(near_index==8) state<=NEAR_DONE;else begin near_index<=near_index+1'b1;state<=NEAR_R;end
    end
    NEAR_DONE:begin
     for(ti=0;ti<3;ti=ti+1) if(near_types[ti]) nearby_hits[ti]<=nearby_hits[ti]+1'b1;
     state<=NEIGH_R;
    end
    COLOR_MARK:state<=NEIGH_R;
    NEIGH_R:state<=NEIGH_C;
    NEIGH_C:if(neighbour_ok&&map_q[0]) begin
     if(first_valid&&cur_x==start_x&&cur_y==start_y&&next_x==first_x&&next_y==first_y) state<=TRACE_END;
     else if(steps>=CELLS*4-1) begin trace_overflow<=1;color_pass<=0;state<=NEXT_SCAN;end
     else begin
      if(!first_valid) begin first_x<=next_x;first_y<=next_y;first_valid<=1;end
      if(!second_pass) begin
       area2<=area2+edge_area;
       if(cur_x<left) left<=cur_x;if(cur_x>right) right<=cur_x;
       if(cur_y<top) top<=cur_y;if(cur_y>bottom) bottom<=cur_y;
      end else if(!color_pass) begin
       if(sample_acc>=trace_length) begin
        if(sample_count<64) begin
         if(sample_count==0) origin<=cur_point;
         sample_count<=sample_count+1'b1;
        end
        sample_acc<=sample_acc-trace_length+sample_goal;
       end else sample_acc<=sample_acc+sample_goal;
      end
      steps<=steps+1'b1;cur_x<=next_x;cur_y<=next_y;attempt<=0;
      direction<=((direction>>1)*2+6)&7;state<=SPAN_R;
     end
    end else if(attempt==7) state<=NEXT_SCAN;
     else begin attempt<=attempt+1'b1;direction<=direction+1'b1;state<=NEIGH_R;end
    TRACE_END:if(color_pass) begin color_pass<=0;state<=NEXT_SCAN;end
     else if(!second_pass) begin
     bw<=right-left+1'b1;bh<=bottom-top+1'b1;
     // Do not simplify a narrow curved contour into a spurious triangle.
     epsilon<=size_epsilon<thin_epsilon?size_epsilon:thin_epsilon;
     if(steps<12||right-left<5||bottom-top<5||abs_area<32) state<=NEXT_SCAN;
     // Only a boundary mostly overlapping existing accepted boundary tiles
     // inherits its class. Never suppress or recolor a whole enclosed region.
     else if(nearby_hits[0]*3>=steps*2||nearby_hits[1]*3>=steps*2||nearby_hits[2]*3>=steps*2) begin
      candidate_shape<=nearby_hits[0]*3>=steps*2?1:nearby_hits[1]*3>=steps*2?2:3;
      associated_contour<=1;state<=CANDIDATE;
     end
     else begin
      trace_length<=steps;sample_goal<=steps<64?steps:64;sample_acc<=steps;sample_count<=0;
      radius_min<=21'h1fffff;radius_max<=0;radius_sum<=0;
      cur_x<=start_x;cur_y<=start_y;first_valid<=0;direction<=0;attempt<=0;steps<=0;second_pass<=1;state<=SPAN_R;
     end
    end else state<=RAD_INIT;
    RAD_INIT:begin radius_min<=21'h1fffff;radius_max<=0;radius_sum<=0;cov_xx<=0;cov_yy<=0;cov_xy<=0;point_i<=0;state<=RAD_R;end
    RAD_R:state<=RAD_C;
    RAD_C:begin
     radius_sum<=radius_sum+gvalue;
     if(gvalue<radius_min) radius_min<=gvalue;
     if(gvalue>radius_max) radius_max<=gvalue;
     cov_xx<=cov_xx+gm0;cov_yy<=cov_yy+gm1;state<=MOM_XY;
    end
    MOM_XY:begin
     cov_xy<=cov_xy+gvalue;
     if(point_i==sample_count-1) state<=RADIAL;else begin point_i<=point_i+1'b1;state<=RAD_R;end
    end
    RADIAL:if(sample_count<3) state<=NEXT_SCAN;
     else begin
      round_candidate<=circle_aspect&&wide_product*100<=wide_limit;
      state<=FAR_INIT;
     end
    FAR_INIT:begin point_i<=1;pivot<=0;far_distance<=0;state<=FAR_R;end
    FAR_R:state<=FAR_SCAN;
    FAR_SCAN:begin
     if(gvalue>far_distance) begin far_distance<=gvalue;pivot<=point_i;end
     if(point_i==sample_count-1) state<=SEG_SETUP;else begin point_i<=point_i+1'b1;state<=FAR_R;end
    end
    SEG_SETUP:begin stack[0]<={pivot,sample_count};stack[1]<={7'd0,pivot};stack_count<=2;vertex_count<=0;state<=SEG_POP;end
    SEG_POP:if(stack_count==0) state<=MERGE_INIT;
     else begin {seg_a,seg_b}<=stack[stack_count-1'b1];stack_count<=stack_count-1'b1;state<=P_A_R;end
    P_A_R:state<=P_A_C;
    P_A_C:begin endpoint_a<=point_q;state<=P_B_R;end
    P_B_R:state<=P_B_C;
    P_B_C:begin
     endpoint_b<=point_q;length_sq<=gvalue;max_cross<=0;max_index<=0;
     point_i<=seg_a+1'b1;state<=seg_b>seg_a+1'b1 ? SEG_R : SEG_TEST;
    end
    SEG_R:state<=SEG_SCAN;
    SEG_SCAN:begin
     if(gabs>max_cross) begin max_cross<=gabs;max_index<=point_i;end
     if(point_i==seg_b-1'b1) state<=SEG_TEST;else begin point_i<=point_i+1'b1;state<=SEG_R;end
    end
    SEG_TEST:if(wide_product>wide_limit&&max_index>seg_a&&max_index<seg_b) begin
     if(stack_count>14) begin geometry_overflow<=1;state<=ELL_INIT;end
     else begin stack[stack_count]<={max_index,seg_b};stack[stack_count+1'b1]<={seg_a,max_index};stack_count<=stack_count+2;state<=SEG_POP;end
    end else if(vertex_count>=8) begin geometry_overflow<=1;state<=ELL_INIT;end
     else begin vertices[vertex_count]<=endpoint_a;vertex_count<=vertex_count+1'b1;state<=SEG_POP;end
    MERGE_INIT:begin merge_i<=0;state<=vertex_count<=3?POLY_INIT:MERGE_SHORT;end
    MERGE_SHORT:begin merge_short<=gvalue;state<=MERGE_CHORD;end
    MERGE_CHORD:begin merge_length<=gvalue;state<=MERGE_VALUE;end
    MERGE_VALUE:begin merge_abs_reg<=gabs;state<=MERGE_SCAN;end
    MERGE_SCAN:if(vertex_count<=3) state<=POLY_INIT;
     else if(merge_short<=(epsilon_squared<<1)||wide_product<=wide_limit) begin shift_i<=merge_i;state<=MERGE_SHIFT;end
     else if(merge_i==vertex_count-1) state<=POLY_INIT;
     else begin merge_i<=merge_i+1'b1;state<=MERGE_SHORT;end
    MERGE_SHIFT:if(shift_i>=vertex_count-1) begin vertex_count<=vertex_count-1'b1;state<=MERGE_INIT;end
     else begin vertices[shift_i]<=vertices[shift_i+1'b1];shift_i<=shift_i+1'b1;end
    POLY_INIT:if(vertex_count!=3&&vertex_count!=4) state<=ELL_INIT;
     else begin polygon_ok<=1;sign_known<=0;poly_i<=0;state<=POLY_CROSS;end
    POLY_CROSS:begin
     if(gvalue==0) polygon_ok<=0;
     if(!sign_known) begin cross_sign<=gvalue[20];sign_known<=1;end
     else if(cross_sign!=gvalue[20]) polygon_ok<=0;
     state<=POLY_DOT;
    end
    POLY_DOT:begin poly_absdot_reg<=gabs;state<=POLY_LEN1;end
    POLY_LEN1:begin
     poly_len1<=gvalue;
     // POLY_LEN1 is previous -> current, i.e. side (i+2)%3.
     tri_edge_length[poly_i==0?vertex_count-1:poly_i-1]<=gvalue;
     state<=POLY_LEN2;
    end
    POLY_LEN2:begin poly_len2<=gvalue;state<=POLY_SCAN;end
    POLY_SCAN:begin
     if(vertex_count==4&&(wide_product*QUAD_DOT_FACTOR)>wide_limit) polygon_ok<=0;
     if(poly_i==vertex_count-1) begin state<=TRI_INIT;candidate_shape<=vertex_count==3?3:1;end
     else begin poly_i<=poly_i+1'b1;state<=POLY_CROSS;end
    end
    TRI_INIT:begin
     tri_supported<=0;tri_matched<=0;point_i<=0;poly_i<=0;strict_supported<=0;strict_matched<=0;
     for(ti=0;ti<4;ti=ti+1) begin tri_side_hits[ti]<=0;tri_bins[ti]<=0;strict_hits[ti]<=0;straight_mid_hits[ti]<=0;end
     state<=vertex_count==4?QUAD_AREA1:TRI_AREA;
    end
    QUAD_AREA1:begin quad_area_part<=gabs;state<=QUAD_AREA2;end
    QUAD_AREA2:begin quad_area<=quad_area_part+gabs;state<=QUAD_AREA_TEST;end
    QUAD_AREA_TEST:if(!polygon_ok||quad_area*4<abs_area*3) state<=ELL_INIT;
     else if(quad_area*4>abs_area*5) begin quad_conflict<=1;state<=ELL_INIT;end
     else state<=TRI_R;
    TRI_AREA:if(!polygon_ok||gabs*4<abs_area*3||gabs*4>abs_area*5) begin
     triangle_rejections<=triangle_rejections+1'b1;state<=rescue_active?RESCUE_NEXT:ELL_INIT;
    end else begin trial_area<=gabs;state<=TRI_R;end
    TRI_R:state<=TRI_CROSS;
    TRI_CROSS:begin max_cross<=gabs;state<=TRI_DOT;end
    // Shared angle datapath computes (b-a).(p-b); translate to (p-a).
    TRI_DOT:begin tri_projection<=gvalue+$signed({3'b0,tri_edge_length[poly_i]});state<=TRI_TEST;end
    TRI_TEST:begin
     if(tri_projection>=0&&tri_projection<=$signed({3'b0,tri_edge_length[poly_i]})&&(wide_product<<2)<=wide_limit) begin
      tri_matched<=1;tri_side_hits[poly_i]<=tri_side_hits[poly_i]+1'b1;tri_bins[poly_i][tri_bin]<=1;
      // Preserve real short straight sides: require central support within
      // half a grid cell before considering the short side a tip artifact.
      if((wide_product<<2)<=tri_edge_length[poly_i]&&tri_project4>=tri_len_ext&&tri_project4<=tri_len_ext*3)
       straight_mid_hits[poly_i]<=straight_mid_hits[poly_i]+1'b1;
      // 0.75-cell core checks long straight support, not just loose fit.
      if((wide_product<<4)<=strict_edge_limit) begin strict_matched<=1;strict_hits[poly_i]<=strict_hits[poly_i]+1'b1;end
     end
     if(poly_i==vertex_count-1) state<=TRI_POINT;
     else begin poly_i<=poly_i+1'b1;state<=TRI_CROSS;end
    end
    TRI_POINT:begin
     if(tri_matched) tri_supported<=tri_supported+1'b1;
     if(strict_matched) strict_supported<=strict_supported+1'b1;
     if(point_i==sample_count-1) state<=TRI_DONE;
     else begin point_i<=point_i+1'b1;poly_i<=0;tri_matched<=0;strict_matched<=0;state<=TRI_R;end
    end
    TRI_DONE:if(tri_edge_coverage&&tri_supported*100>=sample_count*85) begin
     if(rescue_active) begin
      if(tri_supported>=quad_support_ref&&strict_supported>=quad_strict_ref+2&&
       (!best_triangle_valid||tri_supported>best_support||
       (tri_supported==best_support&&strict_supported>best_strict)||
       (tri_supported==best_support&&strict_supported==best_strict&&trial_area_error<best_area_error))) begin
       best_triangle_valid<=1;best_support<=tri_supported;best_strict<=strict_supported;best_area_error<=trial_area_error;
       best_v0<=vertices[0];best_v1<=vertices[1];best_v2<=vertices[2];
      end
      state<=RESCUE_NEXT;
     end else if(vertex_count==4&&try_triangle_tip) state<=RESCUE_BEGIN;
     else if(vertex_count==4&&round_candidate) state<=OBB_INIT;
     else state<=CANDIDATE;
    end else begin
     if(rescue_active) begin triangle_rejections<=triangle_rejections+1'b1;state<=RESCUE_NEXT;end
     else begin
      if(vertex_count==4) quad_conflict<=1;else triangle_rejections<=triangle_rejections+1'b1;
      state<=ELL_INIT;
     end
    end
    RESCUE_BEGIN:begin
     vertices[4]<=vertices[0];vertices[5]<=vertices[1];vertices[6]<=vertices[2];vertices[7]<=vertices[3];
     rescue_short_index<=shortest_index;rescue_active<=1;rescue_trial<=0;best_triangle_valid<=0;
     quad_support_ref<=tri_supported;quad_strict_ref<=strict_supported;
     state<=RESCUE_BUILD;
    end
    RESCUE_BUILD:begin
     if(rescue_trial<2) case(rescue_drop)
      0:begin vertices[0]<=vertices[5];vertices[1]<=vertices[6];vertices[2]<=vertices[7];end
      1:begin vertices[0]<=vertices[4];vertices[1]<=vertices[6];vertices[2]<=vertices[7];end
      2:begin vertices[0]<=vertices[4];vertices[1]<=vertices[5];vertices[2]<=vertices[7];end
      3:begin vertices[0]<=vertices[4];vertices[1]<=vertices[5];vertices[2]<=vertices[6];end
     endcase
     else begin
      vertices[0]<={tip_clamped_x,tip_clamped_y};
      case(rescue_short_index)
       0:begin vertices[1]<=vertices[6];vertices[2]<=vertices[7];end
       1:begin vertices[1]<=vertices[7];vertices[2]<=vertices[4];end
       2:begin vertices[1]<=vertices[4];vertices[2]<=vertices[5];end
       3:begin vertices[1]<=vertices[5];vertices[2]<=vertices[6];end
      endcase
     end
     vertex_count<=3;state<=POLY_INIT;
    end
    RESCUE_NEXT:if(rescue_trial<26) begin rescue_trial<=rescue_trial+1'b1;state<=RESCUE_BUILD;end
     else if(best_triangle_valid) begin
      vertices[0]<=best_v0;vertices[1]<=best_v1;vertices[2]<=best_v2;
      vertex_count<=3;candidate_shape<=3;polygon_ok<=1;rescue_active<=0;rescue_checked<=1;state<=CANDIDATE;
     end else begin
      vertices[0]<=vertices[4];vertices[1]<=vertices[5];vertices[2]<=vertices[6];vertices[3]<=vertices[7];
      vertex_count<=4;rescue_active<=0;rescue_checked<=1;state<=POLY_INIT;
     end
    OBB_INIT:begin obb_index<=0;state<=OBB_RESET;end
    OBB_RESET:begin point_i<=0;state<=OBB_R;end
    OBB_R:state<=OBB_U;
    OBB_U:begin
     if(point_i==0||gvalue<obb_umin) obb_umin<=gvalue;
     if(point_i==0||gvalue>obb_umax) obb_umax<=gvalue;
     state<=OBB_V;
    end
    OBB_V:begin
     if(point_i==0||gvalue<obb_vmin) obb_vmin<=gvalue;
     if(point_i==sample_count-1) state<=OBB_TEST;
     else begin point_i<=point_i+1'b1;state<=OBB_R;end
     if(point_i==0||gvalue>obb_vmax) obb_vmax<=gvalue;
    end
    // abs_area is twice the original contour area; projection axes have
    // norm a*a+b*b. No division, square root or trigonometry is required.
    OBB_TEST:if(wide_limit*100>=wide_product*170) begin
     if(strict_quad_support) state<=CANDIDATE;
     else begin quad_conflict<=1;state<=ELL_INIT;end
    end else if(obb_index==15) state<=ELL_INIT;
     else begin obb_index<=obb_index+1'b1;state<=OBB_RESET;end
    CANDIDATE:if(candidate_shape==2||polygon_ok||associated_contour) begin
     raw_types[candidate_shape-1'b1]<=1;accepted_contours<=accepted_contours+1'b1;
     color_pass<=1;second_pass<=1;cur_x<=start_x;cur_y<=start_y;
     first_valid<=0;direction<=0;attempt<=0;steps<=0;state<=SPAN_R;
    end else state<=ELL_INIT;
    // Polygon tests take precedence over the broader ellipse model, so a
    // four-sided tilted rectangle is not accepted merely as an ellipse.
    ELL_INIT:if(quad_conflict) state<=NEXT_SCAN;
     else if(round_candidate) begin candidate_shape<=2;state<=CANDIDATE;end
     else begin
     ell_xx<=cov_xx>>moment_shift;ell_yy<=cov_yy>>moment_shift;
     ell_xy<=$signed(cov_xy)>>>moment_shift;state<=ELL_DET;
    end
    ELL_DET:if(wide_product<=wide_limit) state<=NEXT_SCAN;
     else begin ell_det<=wide_product-wide_limit;state<=ELL_ASPECT;end
    // lambda_max/lambda_min <= 4: estimated ellipse axis ratio <= 2.
    ELL_ASPECT:if((wide_product<<2)>wide_limit||bw>bh*2||bh>bw*2) state<=NEXT_SCAN;
     else begin radius_min<=21'h1fffff;radius_max<=0;radius_sum<=0;point_i<=0;state<=ELL_R;end
    ELL_R:state<=ELL_PRE;
    ELL_PRE:begin merge_short<=gm0;merge_length<=gm1;state<=ELL_X;end
    ELL_X:begin ell_q<=wide_product;state<=ELL_Y;end
    ELL_Y:begin ell_q<=ell_q+wide_product;merge_abs_reg<=gabs;cross_sign<=gvalue[20];state<=ELL_XY;end
    ELL_XY:begin
     if(ell_xy[10]==cross_sign) ell_q<=ell_q-(wide_product<<1);
     else ell_q<=ell_q+(wide_product<<1);
     state<=ELL_ACC;
    end
    ELL_ACC:begin
     // Shared exponent and fixed shift retain a common scale for all points.
     radius_sum<=radius_sum+(ell_q>>8);
     if((ell_q>>8)<radius_min) radius_min<=ell_q>>8;
     if((ell_q>>8)>radius_max) radius_max<=ell_q>>8;
     if(point_i==sample_count-1) state<=ELL_DONE;
     else begin point_i<=point_i+1'b1;state<=ELL_R;end
    end
    ELL_DONE:if(radius_sum!=0&&wide_product*100<=wide_limit) begin candidate_shape<=2;state<=CANDIDATE;end
     else state<=NEXT_SCAN;
    // Visited flags suppress repeat tracing of the same boundary. Preserve
    // interior edges so thick strokes and independent nested objects survive.
    FINISH:begin
     for(ti=0;ti<3;ti=ti+1) begin
      if(raw_types[ti]) begin if(age[ti]<STABLE_RESULTS) age[ti]<=age[ti]+1'b1;pending_types[ti]<=age[ti]>=STABLE_RESULTS-1;end
      else begin age[ti]<=0;pending_types[ti]<=0;end
     end
     state<=WAIT_COMMIT;
    end
    WAIT_COMMIT:if(result_ack) state<=IDLE;
    default:state<=IDLE;
   endcase
   if(!enable) begin state<=IDLE;color_pass<=0;raw_types<=0;pending_types<=0;for(ti=0;ti<3;ti=ti+1) age[ti]<=0;end
  end
 end
endmodule


