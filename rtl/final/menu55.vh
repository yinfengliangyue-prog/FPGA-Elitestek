localparam FULL=0,SPLIT=1,SHAPE=2,EXPR=3;
localparam OBJECT=0,STYLE=1,STYLE_A=2,STYLE_B=3,SYNC=4,RUN=5,UPDATE=6,
 WB=7,HIGH=8,LOW=9,DENOISE=10,OSD=11,FPS=12,RESET_VIEW=13,RESET_DETECT=14,AUX=15,RESULT=16,
 PAGE=17,PLAY=18,SPEED=19,FRAME_A=20,FRAME_B=21,NEW_TAKE=22,STOP=23,FRAME_INDEX=24,WB_R=25,WB_G=26,WB_B=27,LOCK_PAIR=28;
function uses_edges(input [2:0] m);uses_edges=m==1||m==2||m==4;endfunction
function [4:0] menu_count(input [2:0] app,input edge_style,input [1:0] page);
begin case(app)FULL:menu_count=edge_style?14:10;SPLIT:menu_count=page==0?(edge_style?17:14):16;SHAPE:menu_count=13;default:menu_count=13;endcase end
endfunction
function [4:0] menu_item(input [2:0] app,input [4:0] index,input edge_style,input [1:0] page);
integer j;begin menu_item=RESET_VIEW;j=index;
if((app==FULL&&edge_style)||app==SHAPE||app==EXPR||(app==SPLIT&&page==0&&edge_style))begin
 case(index)0:menu_item=HIGH;1:menu_item=LOW;2:menu_item=DENOISE;default:menu_item=31;endcase j=index-3;end
else menu_item=31;
if(menu_item==31)case(app)
FULL:case(j)0:menu_item=STYLE;1:menu_item=WB;2:menu_item=WB_R;3:menu_item=WB_G;4:menu_item=WB_B;
5:menu_item=RUN;6:menu_item=UPDATE;7:menu_item=OSD;8:menu_item=FPS;9:menu_item=RESET_VIEW;10:menu_item=RESET_DETECT;endcase
SPLIT:begin
if(page!=0)case(index)
0:menu_item=page==1?PLAY:OBJECT;1:menu_item=page==1?FRAME_INDEX:FRAME_A;2:menu_item=page==1?SPEED:FRAME_B;
3:menu_item=PAGE;4:menu_item=STYLE_A;5:menu_item=STYLE_B;6:menu_item=NEW_TAKE;7:menu_item=WB;
8:menu_item=WB_R;9:menu_item=WB_G;10:menu_item=WB_B;11:menu_item=OSD;12:menu_item=FPS;13:menu_item=RESET_VIEW;
14:menu_item=HIGH;15:menu_item=LOW;endcase
else case(j)0:menu_item=PAGE;1:menu_item=STOP;2:menu_item=STYLE_A;3:menu_item=STYLE_B;4:menu_item=NEW_TAKE;
5:menu_item=LOCK_PAIR;6:menu_item=WB;7:menu_item=WB_R;8:menu_item=WB_G;9:menu_item=WB_B;10:menu_item=OSD;11:menu_item=FPS;12:menu_item=RESET_VIEW;13:menu_item=RESET_DETECT;endcase
end
SHAPE:case(j)0:menu_item=AUX;1:menu_item=RESULT;2:menu_item=WB;3:menu_item=WB_R;4:menu_item=WB_G;5:menu_item=WB_B;
6:menu_item=OSD;7:menu_item=FPS;8:menu_item=RESET_VIEW;9:menu_item=RESET_DETECT;endcase
default:case(j)0:menu_item=AUX;1:menu_item=RESULT;2:menu_item=WB;3:menu_item=WB_R;4:menu_item=WB_G;5:menu_item=WB_B;6:menu_item=OSD;7:menu_item=FPS;8:menu_item=RESET_VIEW;9:menu_item=RESET_DETECT;endcase
endcase end endfunction
