// Menu v2. Debounced single-key gestures execute once on release.
// Chords (including overlapping releases) and startup-held keys are discarded.
module keys55 #(parameter BOOT_APP=0,parameter integer DEBOUNCE_CYCLES=1485000,
 parameter integer HOLD_CYCLES=44550000,REPEAT_CYCLES=11137500)(
 input wire clk,rst_n,input wire [3:0] key_n,
 input wire shape_result_valid,shape_locked,
 output reg recognition_run,
 input wire [1:0] frame_page,frame_speed,input wire frame_playing,frame_recording,frame_selected,
 input wire [7:0] frame_count,frame_a,frame_b,input wire [15:0] frame_delta,
 input wire [11:0] wb_qr,wb_qg,wb_qb,
 output reg replay_command_toggle,output reg [3:0] replay_command,
 output wire [2:0] replay_style_a,replay_style_b,
 output wire [7:0] threshold_a,threshold_b,low_a,low_b,
 output wire [2:0] mode_a,mode_b,
 output wire selected_b,swap_sides,same_frame,fullscreen,shape_enable,number_enable,edit_low,
 output reg live_b,capture_a,capture_b,live_a,live_group,capture_group,awb_lock_request,
 output reg [7:0] analysis_high,analysis_low,output reg denoise_enable,
 output wire [1:0] menu_page,output wire [7:0] ai_min_strength,output wire ai_min_select,
 output reg osd_activity_toggle,output wire osd_help_toggle,output reg [2:0] osd_context,
 output reg [2:0] app_mode,output reg settings_open,editing,confirm_reset,
 output wire [4:0] menu_cursor,output wire [4:0] selected_item,
 output wire aux_visible,output reg shape_lock_request,osd_detail,fps_show
);
 `include "rtl/final/menu55.vh"
 localparam CW=DEBOUNCE_CYCLES>1?$clog2(DEBOUNCE_CYCLES+1):1;
 (* async_reg="true" *) reg [3:0] key_meta,key_sync;
 reg [3:0] down,seen;reg [CW-1:0] count[0:3],startup;
 reg ready,gesture,bad,repeated,rolled_back,repeated_nav;
 reg [4:0] saved_cursor;reg [3:0] saved_context;reg [25:0] held;
 reg [7:0] saved_high,saved_low;
 localparam G_BAL=0,G_CLEAN=1,G_RED=2,G_SHAPE=3,G_EXPR=4;
 reg [2:0] threshold_group;
 reg [7:0] bal_high,bal_low,clean_high,clean_low,red_high,red_low,shape_high,shape_low,expr_high,expr_low;
 reg [3:0] previous_ctx;reg [2:0] previous_app;reg [4:0] previous_item;
 reg [4:0] cursors[0:7];reg [2:0] history_a[0:2],history_b[0:2];reg [2:0] full_style,split_a,split_b;
 reg full_b,split_sel,split_sync;reg [3:0] auxiliaries;
 wire edge_style=app_mode==FULL?uses_edges(full_style):app_mode==SPLIT?(uses_edges(history_a[frame_page])||uses_edges(history_b[frame_page])):(app_mode==SHAPE||app_mode==EXPR);
 wire [3:0] ctx_index=app_mode==FULL?(edge_style?1:0):app_mode==SPLIT?(frame_page==0?(edge_style?3:2):frame_page==1?4:5):app_mode==SHAPE?6:7;
 assign replay_style_a=history_a[frame_page];assign replay_style_b=history_b[frame_page];
 // Track the edited setting by identity when its own value reorders the menu.
 // The combinational cursor also prevents one transient frame of wrong focus.
 wire carry_focus=settings_open&&editing&&app_mode==previous_app&&ctx_index!=previous_ctx&&
   ((app_mode==FULL&&previous_item==STYLE)||
    (app_mode==SPLIT&&(previous_item==STYLE_A||previous_item==STYLE_B||previous_item==PAGE)));
 function [4:0] focused_index(input [4:0] id,input edge_context,input [1:0] page_context);
 begin case(id)
 STYLE:focused_index=edge_context?3:0;
 STYLE_A:focused_index=page_context!=0?4:edge_context?5:2;
 STYLE_B:focused_index=page_context!=0?5:edge_context?6:3;
 default:focused_index=page_context!=0?3:edge_context?3:0;
 endcase end endfunction
 assign menu_cursor=carry_focus?focused_index(previous_item,edge_style,frame_page):cursors[ctx_index];
 assign selected_item=menu_item(app_mode,menu_cursor,edge_style,frame_page);
 assign mode_a=app_mode==FULL?full_style:app_mode==SPLIT?replay_style_a:3'd0;
 assign mode_b=app_mode==FULL?full_style:app_mode==SPLIT?replay_style_b:3'd0;
 assign selected_b=app_mode==FULL?full_b:app_mode==SPLIT?frame_selected:1'b0;
 assign same_frame=0;
 assign fullscreen=app_mode!=SPLIT;assign shape_enable=app_mode==SHAPE;assign number_enable=0;
 assign threshold_a=analysis_high;assign threshold_b=analysis_high;assign low_a=analysis_low;assign low_b=analysis_low;
 assign swap_sides=0;assign menu_page=0;assign ai_min_strength=0;assign ai_min_select=0;
 assign edit_low=editing&&selected_item==LOW;assign osd_help_toggle=0;
 assign aux_visible=auxiliaries[app_mode];
 wire target_live=same_frame?live_group:selected_b?live_b:live_a;
 wire single_down=down==1||down==2||down==4||down==8;
 wire [3:0] gesture_mask=seen|down|(~key_sync);
 wire numeric=selected_item==HIGH||selected_item==LOW||selected_item==FRAME_INDEX||selected_item==FRAME_A||selected_item==FRAME_B;
 integer k;
 // Keep stored style codes compatible with existing DDR records.
 // Display order: ORIG(0), BAL(2), CLEAN(4), RED(1), GREY(3).
 function [2:0] next_style(input [2:0] s);begin case(s)
  0:next_style=2;2:next_style=4;4:next_style=1;1:next_style=3;default:next_style=0;
 endcase end endfunction
 function [2:0] previous_style(input [2:0] s);begin case(s)
  0:previous_style=3;3:previous_style=1;1:previous_style=4;4:previous_style=2;default:previous_style=0;
 endcase end endfunction
 task set_threshold(input [7:0] h,l);
 begin
 analysis_high<=h;analysis_low<=l;
 case(threshold_group)
 G_BAL:begin bal_high<=h;bal_low<=l;end
 G_CLEAN:begin clean_high<=h;clean_low<=l;end
 G_RED:begin red_high<=h;red_low<=l;end
 G_SHAPE:begin shape_high<=h;shape_low<=l;end
 G_EXPR:begin expr_high<=h;expr_low<=l;end
 endcase
 end endtask
 task select_group(input [2:0] g);
 begin
 threshold_group<=g;shape_lock_request<=0;
 case(g)
 G_BAL:begin analysis_high<=bal_high;analysis_low<=bal_low;end
 G_CLEAN:begin analysis_high<=clean_high;analysis_low<=clean_low;end
 G_RED:begin analysis_high<=red_high;analysis_low<=red_low;end
 G_SHAPE:begin analysis_high<=shape_high;analysis_low<=shape_low;end
 G_EXPR:begin analysis_high<=expr_high;analysis_low<=expr_low;end
 endcase
 end endtask
 task select_preset(input [2:0] s);
 begin case(s)2:select_group(G_BAL);4:select_group(G_CLEAN);1:select_group(G_RED);default:begin end endcase end endtask
 task restore_threshold;
 begin case(threshold_group)
 G_BAL:set_threshold(6,4);G_RED:set_threshold(8,4);G_CLEAN:set_threshold(9,4);G_EXPR:set_threshold(11,5);G_SHAPE:set_threshold(6,3);
 endcase end endtask
 task notice(input [2:0] c);begin osd_activity_toggle<=~osd_activity_toggle;osd_context<=c;end endtask
 task send(input [3:0] value);begin replay_command<=value;replay_command_toggle<=~replay_command_toggle;end endtask
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
 else if(app_mode==EXPR)begin recognition_run<=~recognition_run;notice(6);end
 else notice(3);
 end endtask
 task adjust(input plus);
 begin
 if(selected_item==HIGH||selected_item==LOW||selected_item==DENOISE)shape_lock_request<=0;
 case(selected_item)
 OBJECT:if(app_mode==SPLIT)send(13);
 STYLE:begin full_style<=plus?next_style(full_style):previous_style(full_style);select_preset(plus?next_style(full_style):previous_style(full_style));end
 STYLE_A:begin history_a[frame_page]<=plus?next_style(replay_style_a):previous_style(replay_style_a);if(frame_page==0)select_preset(plus?next_style(replay_style_a):previous_style(replay_style_a));end
 STYLE_B:begin history_b[frame_page]<=plus?next_style(replay_style_b):previous_style(replay_style_b);if(frame_page==0)select_preset(plus?next_style(replay_style_b):previous_style(replay_style_b));end
 PAGE:send(plus?(frame_page==2?10:frame_page==0?11:12):(frame_page==0?12:frame_page==1?10:11));
 PLAY:send(14);SPEED:send(plus?3:5);
 FRAME_A,FRAME_B,FRAME_INDEX:send(plus?4:2);
 RUN:set_live(!target_live);
 WB:begin awb_lock_request<=~awb_lock_request;shape_lock_request<=0;end
 HIGH:if(plus)begin if(analysis_high<255)set_threshold(analysis_high+1'b1,analysis_low);end
      else if(analysis_high>1)set_threshold(analysis_high-1'b1,analysis_low>=analysis_high?analysis_high-1'b1:analysis_low);
 LOW:if(plus)begin if(analysis_low<analysis_high)set_threshold(analysis_high,analysis_low+1'b1);end
     else if(analysis_low>1)set_threshold(analysis_high,analysis_low-1'b1);
 DENOISE:denoise_enable<=~denoise_enable;
 OSD:osd_detail<=~osd_detail;FPS:fps_show<=~fps_show;
 AUX:auxiliaries[app_mode]<=~auxiliaries[app_mode];RESULT:result_toggle;
 endcase end endtask
 task restore;
 begin
 if(selected_item==RESET_DETECT)begin restore_threshold;denoise_enable<=1;shape_lock_request<=0;end
 else if(selected_item==NEW_TAKE)send(9);
 else case(app_mode)
 FULL:begin full_b<=0;full_style<=0;end
 SPLIT:begin history_a[frame_page]<=frame_page==2?2:0;history_b[frame_page]<=frame_page==0||frame_page==2?2:0;end
 default:begin auxiliaries[app_mode]<=1;recognition_run<=0;end
 endcase
 confirm_reset<=0;notice(7);
 end endtask
 task move_cursor(input forward);
 begin
 if(forward)begin if(menu_cursor+1<menu_count(app_mode,edge_style,frame_page))cursors[ctx_index]<=menu_cursor+1'b1;end
 else if(menu_cursor>0)cursors[ctx_index]<=menu_cursor-1'b1;
 end endtask
 task execute(input [3:0] key);
 begin
 if(key==2)begin
  if(confirm_reset)confirm_reset<=0;
  else begin settings_open<=~settings_open;editing<=0;if(!settings_open)cursors[ctx_index]<=0;end
 end
 else if(settings_open)begin
  if(confirm_reset)begin if(key==1)restore;end
  else if(editing)begin if(key==1)editing<=0;else if(key==4||key==8)adjust(key==8);end
  else case(key)
   1:if(selected_item==RESET_VIEW||selected_item==RESET_DETECT||selected_item==NEW_TAKE)confirm_reset<=1;
     else if(selected_item==UPDATE)begin if(!target_live)update_frame;end
     else if(selected_item==RESULT)result_toggle;
     else if(selected_item==STOP)send(8);
     else if(selected_item==LOCK_PAIR)send(15);
     else if(selected_item>=WB_R&&selected_item<=WB_B)begin end
     else begin editing<=1;
      if(selected_item==FRAME_A&&frame_selected)send(13);
      if(selected_item==FRAME_B&&!frame_selected)send(13);
     end
   4:move_cursor(0);8:move_cursor(1);
  endcase
 end else case(key)
 1:begin
  app_mode<=app_mode==EXPR?FULL:app_mode+1'b1;
  case(app_mode)
   FULL:begin
    if(uses_edges(frame_selected?replay_style_b:replay_style_a))select_preset(frame_selected?replay_style_b:replay_style_a);
    else if(uses_edges(frame_selected?replay_style_a:replay_style_b))select_preset(frame_selected?replay_style_a:replay_style_b);
    else select_group(G_BAL);
   end
   SPLIT:select_group(G_SHAPE);
   SHAPE:select_group(G_EXPR);
   default:if(uses_edges(full_style))select_preset(full_style);else select_group(G_BAL);
  endcase
  shape_lock_request<=0;recognition_run<=0;notice(0);
 end
 4:begin if(app_mode==FULL)begin full_style<=next_style(full_style);select_preset(next_style(full_style));notice(1);end
    else if(app_mode==SPLIT)begin send(frame_page==0?11:2);notice(1);end
    else begin auxiliaries[app_mode]<=~auxiliaries[app_mode];notice(2);end end
 8:if(app_mode==FULL)begin set_live(!target_live);notice(4);end else if(app_mode==SPLIT)begin send(frame_page==0?8:4);notice(1);end else result_toggle;
 endcase
 end endtask
 always @(posedge clk)begin
 if(!rst_n)begin
 key_meta<=15;key_sync<=15;down<=0;seen<=0;startup<=0;ready<=0;gesture<=0;bad<=0;repeated<=0;rolled_back<=0;repeated_nav<=0;saved_cursor<=0;saved_context<=0;held<=0;
 saved_high<=6;saved_low<=4;previous_ctx<=0;previous_app<=FULL;previous_item<=STYLE;
 for(k=0;k<4;k=k+1)count[k]<=0;for(k=0;k<8;k=k+1)cursors[k]<=0;
 for(k=0;k<3;k=k+1)begin history_a[k]<=k==2?2:0;history_b[k]<=k==0||k==2?2:0;end
 replay_command<=0;replay_command_toggle<=0;
 app_mode<=BOOT_APP;settings_open<=0;editing<=0;confirm_reset<=0;full_style<=0;split_a<=0;split_b<=2;
 recognition_run<=0;full_b<=0;split_sel<=1;split_sync<=0;auxiliaries<=15;shape_lock_request<=0;osd_detail<=0;fps_show<=0;
 live_a<=1;live_b<=1;live_group<=1;capture_a<=0;capture_b<=0;capture_group<=0;awb_lock_request<=0;
 bal_high<=6;bal_low<=4;clean_high<=9;clean_low<=4;expr_high<=11;expr_low<=5;red_high<=8;red_low<=4;shape_high<=6;shape_low<=3;
 threshold_group<=BOOT_APP==SHAPE?G_SHAPE:BOOT_APP==EXPR?G_EXPR:G_BAL;
 analysis_high<=BOOT_APP==SHAPE?6:BOOT_APP==EXPR?11:6;analysis_low<=BOOT_APP==SHAPE?3:BOOT_APP==EXPR?5:4;denoise_enable<=1;osd_activity_toggle<=0;osd_context<=0;
 end else begin
 key_meta<=key_n;key_sync<=key_meta;
 for(k=0;k<4;k=k+1)begin
  if((~key_sync[k])==down[k])count[k]<=0;
  else if(count[k]==DEBOUNCE_CYCLES-1)begin down[k]<=~key_sync[k];count[k]<=0;end
  else count[k]<=count[k]+1'b1;
 end
 if(menu_cursor>=menu_count(app_mode,edge_style,frame_page))cursors[ctx_index]<=menu_count(app_mode,edge_style,frame_page)-1'b1;
 if(!ready)begin
  if(key_sync!=15||down!=0)startup<=0;
  else if(startup==DEBOUNCE_CYCLES-1)ready<=1;else startup<=startup+1'b1;
 end else if(down!=0)begin
  gesture<=1;seen<=seen|down;
  if(!gesture)begin saved_high<=analysis_high;saved_low<=analysis_low;saved_cursor<=menu_cursor;saved_context<=ctx_index;end
  if(!single_down||((seen|down)!=down)||
     (gesture_mask!=1&&gesture_mask!=2&&gesture_mask!=4&&gesture_mask!=8))begin
   bad<=1;
   if(repeated&&!rolled_back)begin
    if(repeated_nav)begin if(saved_context==ctx_index)cursors[ctx_index]<=saved_cursor;end
    else set_threshold(saved_high,saved_low);
    rolled_back<=1;end
  end
  if(!bad&&single_down&&((seen|down)==down)&&((settings_open&&!confirm_reset&&(!editing||numeric))||(!settings_open&&app_mode==SPLIT&&frame_page!=0))&&(down==4||down==8)&&key_sync==~down)begin
   if(held==(repeated?REPEAT_CYCLES-1:HOLD_CYCLES-1))begin
    if(settings_open&&!editing)begin move_cursor(down==8);repeated_nav<=1;end
    else if(settings_open)adjust(down==8);else send(down==8?4:2);
    held<=0;repeated<=1;end
   else held<=held+1'b1;
  end else held<=0;
 end else if(gesture)begin
  gesture<=0;seen<=0;held<=0;bad<=0;repeated<=0;rolled_back<=0;repeated_nav<=0;
  if(!bad&&!repeated&&(seen==1||seen==2||seen==4||seen==8))execute(seen);
 end
 previous_ctx<=ctx_index;previous_app<=app_mode;previous_item<=selected_item;
 if(previous_ctx!=ctx_index)begin
  confirm_reset<=0;
  if(carry_focus)cursors[ctx_index]<=menu_cursor;
  else begin editing<=0;if(settings_open)cursors[ctx_index]<=0;end
 end
 end end
endmodule
