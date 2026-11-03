// Shared menu IDs and navigation: the controller and renderer use one table.
localparam FULL=0,SPLIT=1,SHAPE=2,NUMBER=3,EXPR=4;
localparam OBJECT=0,STYLE=1,STYLE_A=2,STYLE_B=3,SYNC=4,RUN=5,UPDATE=6,
 WB=7,HIGH=8,LOW=9,DENOISE=10,OSD=11,FPS=12,RESET_VIEW=13,RESET_DETECT=14,AUX=15,RESULT=16;
function [3:0] menu_count(input [2:0] app,input edge_style);
 begin case(app) FULL:menu_count=edge_style?12:8;SPLIT:menu_count=edge_style?14:10;
 SHAPE:menu_count=10;default:menu_count=6;endcase end
endfunction
function [4:0] menu_item(input [2:0] app,input [3:0] index,input edge_style);
 begin
 menu_item=RESET_VIEW;
 case(app)
 FULL:case(index)
 0:menu_item=OBJECT;1:menu_item=STYLE;2:menu_item=RUN;3:menu_item=UPDATE;4:menu_item=WB;
 5:menu_item=edge_style?HIGH:OSD;6:menu_item=edge_style?LOW:FPS;7:menu_item=edge_style?DENOISE:RESET_VIEW;
 8:menu_item=OSD;9:menu_item=FPS;10:menu_item=RESET_VIEW;11:menu_item=RESET_DETECT;endcase
 SPLIT:case(index)
 0:menu_item=OBJECT;1:menu_item=STYLE_A;2:menu_item=STYLE_B;3:menu_item=SYNC;
 4:menu_item=RUN;5:menu_item=UPDATE;6:menu_item=WB;
 7:menu_item=edge_style?HIGH:OSD;8:menu_item=edge_style?LOW:FPS;9:menu_item=edge_style?DENOISE:RESET_VIEW;
 10:menu_item=OSD;11:menu_item=FPS;12:menu_item=RESET_VIEW;13:menu_item=RESET_DETECT;endcase
 SHAPE:case(index)
 0:menu_item=AUX;1:menu_item=RESULT;2:menu_item=WB;3:menu_item=HIGH;4:menu_item=LOW;
 5:menu_item=DENOISE;6:menu_item=OSD;7:menu_item=FPS;8:menu_item=RESET_VIEW;9:menu_item=RESET_DETECT;endcase
 default:case(index)0:menu_item=AUX;1:menu_item=RESULT;2:menu_item=WB;3:menu_item=OSD;4:menu_item=FPS;5:menu_item=RESET_VIEW;endcase
 endcase
 end
endfunction
function uses_edges(input [2:0] m);uses_edges=m==1||m==2||m==4;endfunction
