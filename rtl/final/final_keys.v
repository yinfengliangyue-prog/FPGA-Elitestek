// Menu v2. Debounced single-key gestures execute once on release.
// Chords (including overlapping releases) and startup-held keys are discarded.
module final_keys #(parameter integer DEBOUNCE_CYCLES=1485000,
 parameter integer HOLD_CYCLES=44550000,REPEAT_CYCLES=11137500)(
 input wire clk,rst_n,input wire [3:0] key_n,
 input wire shape_result_valid,shape_locked,
 output wire [7:0] threshold_a,threshold_b,low_a,low_b,
 output wire [2:0] mode_a,mode_b,
 output wire selected_b,swap_sides,same_frame,fullscreen,shape_enable,number_enable,edit_low,
 output reg live_b,capture_a,capture_b,live_a,live_group,capture_group,awb_lock_request,
 output reg [7:0] analysis_high,analysis_low,output reg denoise_enable,
 output wire [1:0] menu_page,output wire [7:0] ai_min_strength,output wire ai_min_select,
 output reg osd_activity_toggle,output wire osd_help_toggle,output reg [2:0] osd_context,
 output reg [2:0] app_mode,output reg settings_open,editing,confirm_reset,
 output wire [3:0] menu_cursor,output wire [4:0] selected_item,
 output wire aux_visible,output reg shape_lock_request,osd_detail,fps_show
);
 `include "rtl/final/final_menu_defs.vh"
 localparam CW=DEBOUNCE_CYCLES>1?$clog2(DEBOUNCE_CYCLES+1):1;
 (* async_reg="true" *) reg [3:0] key_meta,key_sync;
 reg [3:0] down,seen;reg [CW-1:0] count[0:3],startup;
 reg ready,gesture,bad,repeated,rolled_back;reg [25:0] held;
 reg [7:0] saved_high,saved_low;
 reg [3:0] cursors[0:4];reg [2:0] full_style,split_a,split_b;
 reg full_b,split_sel,split_sync;reg [4:0] auxiliaries;
 wire edge_style=app_mode==FULL?uses_edges(full_style):app_mode==SPLIT?(uses_edges(split_a)||uses_edges(split_b)):app_mode==SHAPE;
 assign menu_cursor=cursors[app_mode];assign selected_item=menu_item(app_mode,menu_cursor,edge_style);
 assign mode_a=app_mode==FULL?full_style:app_mode==SPLIT?split_a:3'd0;
 assign mode_b=app_mode==FULL?full_style:app_mode==SPLIT?split_b:3'd0;
 assign selected_b=app_mode==FULL?full_b:app_mode==SPLIT?split_sel:1'b0;
 assign same_frame=app_mode==SPLIT&&split_sync;
 assign fullscreen=app_mode!=SPLIT;assign shape_enable=app_mode==SHAPE;assign number_enable=0;
 assign threshold_a=6;assign threshold_b=6;assign low_a=3;assign low_b=3;
 assign swap_sides=0;assign menu_page=0;assign ai_min_strength=0;assign ai_min_select=0;
 assign edit_low=editing&&selected_item==LOW;assign osd_help_toggle=0;
 assign aux_visible=auxiliaries[app_mode];
 wire target_live=same_frame?live_group:selected_b?live_b:live_a;
 wire single_down=down==1||down==2||down==4||down==8;
 wire [3:0] gesture_mask=seen|down|(~key_sync);
 wire numeric=selected_item==HIGH||selected_item==LOW;
 integer k;
 task notice(input [2:0] c);begin osd_activity_toggle<=~osd_activity_toggle;osd_context<=c;end endtask
 task set_live(input value);
 begin
 if(same_frame)begin live_group<=value;if(!value&&live_group)capture_group<=~capture_group;end
 else if(selected_b)begin live_b<=value;if(!value&&live_b)capture_b<=~capture_b;end
 else begin live_a<=value;if(!value&&live_a)capture_a<=~capture_a;end
 end endtask
 task update_frame;
 begin if(same_frame)capture_group<=~capture_group;else if(selected_b)capture_b<=~capture_b;else capture_a<=~capture_a;notice(5);end endtask
 task result_toggle;
 begin
 if(app_mode==SHAPE&&(shape_locked||shape_lock_request))shape_lock_request<=0;
 else if(app_mode==SHAPE&&shape_result_valid)shape_lock_request<=1;
 else notice(3);
 end endtask
 task adjust(input plus);
 begin
 if(selected_item==HIGH||selected_item==LOW||selected_item==DENOISE)shape_lock_request<=0;
 case(selected_item)
 OBJECT:if(app_mode==FULL)full_b<=~full_b;else split_sel<=~split_sel;
 STYLE:full_style<=plus?(full_style==4?0:full_style+1'b1):(full_style==0?4:full_style-1'b1);
 STYLE_A:split_a<=plus?(split_a==4?0:split_a+1'b1):(split_a==0?4:split_a-1'b1);
 STYLE_B:split_b<=plus?(split_b==4?0:split_b+1'b1):(split_b==0?4:split_b-1'b1);
 SYNC:split_sync<=~split_sync;
 RUN:set_live(!target_live);
 WB:begin awb_lock_request<=~awb_lock_request;shape_lock_request<=0;end
 HIGH:if(plus)begin if(analysis_high<255)analysis_high<=analysis_high+1'b1;end
      else if(analysis_high>1)begin analysis_high<=analysis_high-1'b1;if(analysis_low>=analysis_high)analysis_low<=analysis_high-1'b1;end
 LOW:if(plus)begin if(analysis_low<analysis_high)analysis_low<=analysis_low+1'b1;end
     else if(analysis_low>1)analysis_low<=analysis_low-1'b1;
 DENOISE:denoise_enable<=~denoise_enable;
 OSD:osd_detail<=~osd_detail;FPS:fps_show<=~fps_show;
 AUX:auxiliaries[app_mode]<=~auxiliaries[app_mode];RESULT:result_toggle;
 endcase end endtask
 task restore;
 begin
 if(selected_item==RESET_DETECT)begin analysis_high<=6;analysis_low<=3;denoise_enable<=1;shape_lock_request<=0;end
 else case(app_mode)
 FULL:begin full_b<=0;full_style<=0;end
 SPLIT:begin split_sel<=1;split_a<=0;split_b<=2;end
 default:auxiliaries[app_mode]<=1;
 endcase
 confirm_reset<=0;notice(7);
 end endtask
 task execute(input [3:0] key);
 begin
 if(key==2)begin
  if(confirm_reset)confirm_reset<=0;
  else begin settings_open<=~settings_open;editing<=0;end
 end
 else if(settings_open)begin
  if(confirm_reset)begin if(key==1)restore;end
  else if(editing)begin if(key==1)editing<=0;else if(key==4||key==8)adjust(key==8);end
  else case(key)
   1:if(selected_item==RESET_VIEW||selected_item==RESET_DETECT)confirm_reset<=1;
     else if(selected_item==UPDATE)begin if(!target_live)update_frame;end
     else if(selected_item==RESULT)result_toggle;
     else editing<=1;
   4:if(menu_cursor>0)cursors[app_mode]<=menu_cursor-1'b1;
   8:if(menu_cursor+1<menu_count(app_mode,edge_style))cursors[app_mode]<=menu_cursor+1'b1;
  endcase
 end else case(key)
 1:begin app_mode<=app_mode==EXPR?FULL:app_mode+1'b1;shape_lock_request<=0;notice(0);end
 4:begin if(app_mode==FULL)begin full_style<=full_style==4?0:full_style+1'b1;notice(1);end
    else if(app_mode==SPLIT)begin split_sel<=~split_sel;notice(1);end
    else begin auxiliaries[app_mode]<=~auxiliaries[app_mode];notice(2);end end
 8:if(app_mode<=SPLIT)begin set_live(!target_live);notice(4);end else result_toggle;
 endcase
 end endtask
 always @(posedge clk)begin
 if(!rst_n)begin
 key_meta<=15;key_sync<=15;down<=0;seen<=0;startup<=0;ready<=0;gesture<=0;bad<=0;repeated<=0;rolled_back<=0;held<=0;
 saved_high<=6;saved_low<=3;for(k=0;k<4;k=k+1)count[k]<=0;for(k=0;k<5;k=k+1)cursors[k]<=0;
 app_mode<=FULL;settings_open<=0;editing<=0;confirm_reset<=0;full_style<=0;split_a<=0;split_b<=2;
 full_b<=0;split_sel<=1;split_sync<=0;auxiliaries<=31;shape_lock_request<=0;osd_detail<=0;fps_show<=0;
 live_a<=1;live_b<=1;live_group<=1;capture_a<=0;capture_b<=0;capture_group<=0;awb_lock_request<=0;
 analysis_high<=6;analysis_low<=3;denoise_enable<=1;osd_activity_toggle<=0;osd_context<=0;
 end else begin
 key_meta<=key_n;key_sync<=key_meta;
 for(k=0;k<4;k=k+1)begin
  if((~key_sync[k])==down[k])count[k]<=0;
  else if(count[k]==DEBOUNCE_CYCLES-1)begin down[k]<=~key_sync[k];count[k]<=0;end
  else count[k]<=count[k]+1'b1;
 end
 if(menu_cursor>=menu_count(app_mode,edge_style))cursors[app_mode]<=menu_count(app_mode,edge_style)-1'b1;
 if(!ready)begin
  if(key_sync!=15||down!=0)startup<=0;
  else if(startup==DEBOUNCE_CYCLES-1)ready<=1;else startup<=startup+1'b1;
 end else if(down!=0)begin
  gesture<=1;seen<=seen|down;
  if(!gesture)begin saved_high<=analysis_high;saved_low<=analysis_low;end
  if(!single_down||((seen|down)!=down)||
     (gesture_mask!=1&&gesture_mask!=2&&gesture_mask!=4&&gesture_mask!=8))begin
   bad<=1;
   if(repeated&&!rolled_back)begin analysis_high<=saved_high;analysis_low<=saved_low;rolled_back<=1;end
  end
  if(!bad&&single_down&&((seen|down)==down)&&settings_open&&editing&&numeric&&(down==4||down==8)&&key_sync==~down)begin
   if(held==(repeated?REPEAT_CYCLES-1:HOLD_CYCLES-1))begin adjust(down==8);held<=0;repeated<=1;end
   else held<=held+1'b1;
  end else held<=0;
 end else if(gesture)begin
  gesture<=0;seen<=0;held<=0;bad<=0;repeated<=0;rolled_back<=0;
  if(!bad&&!repeated&&(seen==1||seen==2||seen==4||seen==8))execute(seen);
 end
 end end
endmodule
