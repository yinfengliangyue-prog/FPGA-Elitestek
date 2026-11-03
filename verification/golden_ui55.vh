// Output-side UI: independent of image storage and freeze state.
// Two pipeline stages keep the character mux and font ROM off the RGB path.
module golden_ui55 #(parameter W=1920,H=1080,HINT_FRAMES=300)(
 input wire clk,rst_n,input wire [47:0] rgb_in,input wire de_in,hs_in,vs_in,
 input wire [2:0] app_mode,mode_a,mode_b,input wire selected_b,same_frame,
 input wire live_a,live_b,live_group,wb_locked,shape_locked,
 input wire [7:0] effective_high,effective_low,input wire denoise_active,
 input wire settings_open,editing,confirm_reset,input wire [4:0] menu_cursor,
 input wire [1:0] frame_page,frame_speed,input wire frame_playing,frame_recording,frame_selected,
 input wire [7:0] frame_count,frame_a,frame_b,input wire [15:0] frame_delta,input wire [11:0] wb_qr,wb_qg,wb_qb,
 input wire aux_visible,osd_detail,fps_show,input wire [9:0] fps_cam,fps_vid,input wire fps_valid,
 input wire activity,input wire [2:0] context_code,input wire image_valid,
 output reg [47:0] rgb_out,output reg de_out,hs_out,vs_out
);
 `include "rtl/final/menu55.vh"
 `include "rtl/final/final_font.vh"
 localparam RX=((W-768)/8)*4,RY=((H-768)/8)*4,CARD_X=W-424,CARD_Y=160;
 reg [2:0] app,ma,mb;reg sel,same,la,lb,lg,wblock,shlock,opened,edit,confirm,aux,detail,showfps;
 reg [7:0] hi,lo;reg dn,fvalid;reg [9:0] fc,fv;reg [4:0] cursor,scroll;reg [1:0] fp,speed;reg playing,recording;reg [7:0] nframes,fa,fb;reg [15:0] dt;reg [11:0] qr,qg,qb;
 reg oldvs,oldde;reg [11:0] x,y;wire [11:0] px=oldde?x:12'd0;
 reg seen,pending;reg [2:0] ctx,ctx_pending;reg [8:0] hint_left;
 wire edge_style=app==FULL?uses_edges(ma):app==SPLIT?(uses_edges(ma)||uses_edges(mb)):app==SHAPE;
 wire run=same?lg:sel?lb:la;
 wire sof=vs_in&&!oldvs;
 function [255:0] padded(input [255:0] t);padded=t;endfunction
 function [39:0] sty(input [2:0] m);begin case(m)0:sty="WB   ";1:sty="RED  ";2:sty="BAL  ";3:sty="GRAY ";default:sty="CLEAN";endcase end endfunction
 function [255:0] app_title(input [2:0] a);
 begin case(a)
 0:app_title="FULL 1/5                        ";1:app_title="FRAME 2/5                       ";2:app_title="SHAPE 3/5                       ";3:app_title="NUMBER 4/5                      ";default:app_title="EXPR 5/5                        ";
 endcase end endfunction
 function [23:0] dec3(input [9:0] n);dec3={8'(48+n/100),8'(48+(n/10)%10),8'(48+n%10)};endfunction
 function [39:0] dec5(input [15:0] n);dec5={8'(48+n/10000),8'(48+(n/1000)%10),8'(48+(n/100)%10),8'(48+(n/10)%10),8'(48+n%10)};endfunction
 function [255:0] item_text(input [4:0] id);
 reg [255:0] t;begin t="                                ";
 case(id)
 PAGE:begin t="BUFFER PAGE                     ";t[111-:56]=fp==0?"LIVE   ":fp==1?"REPLAY ":"COMPARE";end
 PLAY:begin t="PLAYBACK                        ";t[111-:56]=playing?"PLAY   ":"PAUSED ";end
 SPEED:begin t="SPEED                           ";t[111-:32]=speed==0?"0.5X":speed==1?"1.0X":"2.0X";end
 FRAME_A:begin t="FRAME A                         ";t[111-:24]=dec3({2'd0,fa});end
 FRAME_B,FRAME_INDEX:begin t="FRAME B                         ";t[111-:24]=dec3({2'd0,fb});end
 NEW_TAKE:t="NEW TAKE...                     ";STOP:t="STOP AND REVIEW                 ";
 WB_R:begin t="EFFECTIVE R Q8                  ";t[111-:24]=dec3(qr);end
 WB_G:begin t="EFFECTIVE G Q8                  ";t[111-:24]=dec3(qg);end
 WB_B:begin t="EFFECTIVE B Q8                  ";t[111-:24]=dec3(qb);end
 OBJECT:begin t="SELECT A/B                      ";t[111-:8]=sel?"B":"A";end
 STYLE:begin t="DISPLAY STYLE                   ";t[111-:40]=sty(sel?mb:ma);end
 STYLE_A:begin t="A STYLE                         ";t[111-:40]=sty(ma);end
 STYLE_B:begin t="B STYLE                         ";t[111-:40]=sty(mb);end
 SYNC:begin t="TIMELINE                        ";t[111-:32]=same?"SYNC":"INDP";end
 RUN:begin t="VIDEO                           ";t[111-:32]=run?"LIVE":"HOLD";end
 UPDATE:begin t="UPDATE HELD FRAME               ";t[111-:32]=run?"LIVE":"ONCE";end
 WB:begin t="GLOBAL WB                       ";t[111-:32]=wblock?"LOCK":"AUTO";end
 HIGH:begin t="GLOBAL H                        ";t[111-:24]=dec3({2'd0,hi});end
 LOW:begin t="GLOBAL L                        ";t[111-:24]=dec3({2'd0,lo});end
 DENOISE:begin t="GLOBAL DENOISE                  ";t[111-:24]=dn?"ON ":"OFF";end
 OSD:begin t="OSD                             ";t[111-:48]=detail?"DETAIL":"SIMPLE";end
 FPS:begin t="FPS DISPLAY                     ";t[111-:24]=showfps?"ON ":"OFF";end
 RESET_VIEW:t="RESTORE VIEW...                 ";RESET_DETECT:t="RESTORE DETECT...               ";
 AUX:begin t="AUXILIARY                       ";t[111-:24]=aux?"ON ":"OFF";end
 RESULT:begin t="RESULT                          ";t[111-:32]=shlock?"LOCK":"LIVE";end
 endcase item_text=t;end endfunction
 function [255:0] notice_text;
 reg [255:0] t;begin t=app_title(app);
 case(ctx)
 1:begin t=app==SPLIT?"SELECTED                        ":"DISPLAY STYLE                   ";t[111-:40]=app==SPLIT?{sel?8'd66:8'd65,32'h20202020}:sty(sel?mb:ma);end
 2:t=aux?"AUX ON                          ":"AUX OFF                         ";
 3:t="NO RESULT                       ";
 4:t=run?"LIVE                            ":"HOLD                            ";
 5:t="UPDATE REQUESTED                ";
 7:t="DEFAULTS RESTORED               ";
 endcase notice_text=t;end endfunction
 always @(posedge clk)begin
 if(!rst_n)begin
 app<=FULL;ma<=0;mb<=2;sel<=0;same<=0;la<=1;lb<=1;lg<=1;wblock<=0;shlock<=0;
 opened<=0;edit<=0;confirm<=0;aux<=1;detail<=0;showfps<=0;hi<=6;lo<=3;dn<=1;fc<=0;fv<=0;fvalid<=0;cursor<=0;scroll<=0;
 fp<=0;speed<=1;playing<=0;recording<=1;nframes<=0;fa<=0;fb<=0;dt<=0;qr<=320;qg<=158;qb<=329;oldvs<=0;oldde<=0;x<=0;y<=0;seen<=0;pending<=0;ctx<=0;ctx_pending<=0;hint_left<=HINT_FRAMES;
 end else begin
 oldvs<=vs_in;oldde<=de_in;
 if(activity!=seen)begin seen<=activity;pending<=1;ctx_pending<=context_code;end
 if(sof)begin
 fp<=frame_page;speed<=frame_speed;playing<=frame_playing;recording<=frame_recording;nframes<=frame_count;fa<=frame_a;fb<=frame_b;dt<=frame_delta;qr<=wb_qr;qg<=wb_qg;qb<=wb_qb;
 x<=0;y<=0;app<=app_mode;ma<=mode_a;mb<=mode_b;sel<=selected_b;same<=same_frame;
 la<=live_a;lb<=live_b;lg<=live_group;wblock<=wb_locked;shlock<=shape_locked;
 opened<=settings_open;edit<=editing;confirm<=confirm_reset;aux<=aux_visible;detail<=osd_detail;showfps<=fps_show;
 hi<=effective_high;lo<=effective_low;dn<=denoise_active;fc<=fps_cam;fv<=fps_vid;fvalid<=fps_valid;cursor<=menu_cursor;
 scroll<=menu_cursor>=6?menu_cursor-5:0;
 if(activity!=seen||pending)begin hint_left<=HINT_FRAMES;ctx<=activity!=seen?context_code:ctx_pending;pending<=0;end
 else if(hint_left!=0)hint_left<=hint_left-1'b1;
 end else if(de_in)x<=px+2;else if(oldde)begin x<=0;y<=y+1'b1;end
 end end
 // One text cell per 2-pixel pair; every glyph and border is pair aligned.
 reg [47:0] base;reg [7:0] ch;reg [2:0] gr,col;reg ink_region;reg [23:0] ink_color;
 reg [255:0] txt;integer dx,dy,row,ci;reg text_region,large_text;reg [4:0] id;
 always @*begin
 base=rgb_in;txt="                                ";ch=32;gr=0;col=0;ink_region=0;ink_color=24'hffffff;
 dx=0;dy=0;row=0;ci=0;text_region=0;large_text=0;id=0;
 if(de_in&&W>=1280)begin
  // Search geometry matches the real 34 front end. No fabricated character boxes.
  if((app==NUMBER||app==EXPR)&&aux)begin
   if(px>=RX&&px<RX+768&&y>=RY&&y<RY+768&&(px<RX+2||px>=RX+766||y<RY+2||y>=RY+766))base={2{24'hffffff}};
   if((px>=RX+376&&px<RX+392&&y==RY+384)||(y>=RY+376&&y<RY+392&&px==RX+384))base={2{24'hffffff}};
   if(app==NUMBER&&px>=32&&px<144&&y>=96&&y<208)base={2{24'h000000}};
  end
  // NUMBER and EXPR result headings use the original 34 scale and coordinates.
  if(app==NUMBER&&px>=32&&px<224&&y>=32&&y<64)begin txt="NUMBER ?                        ";dx=px-32;dy=y-32;text_region=1;large_text=1;end
  if(app==EXPR&&px>=32&&px<800&&y>=32&&y<64)begin txt="EXPR LIVE WAIT                  ";dx=px-32;dy=y-32;text_region=1;large_text=1;end
  if(app==EXPR&&px>=32&&px<800&&y>=80&&y<112)begin txt="EXPR ?                          ";dx=px-32;dy=y-80;text_region=1;large_text=1;end
  if(app==FULL&&!run&&px>=32&&px<224&&y>=32&&y<52)begin txt="HOLD                            ";dx=px-32;dy=y-32;text_region=1;end
  if(app==SHAPE&&shlock&&px>=32&&px<224&&y>=112&&y<132)begin txt="LOCK                            ";dx=px-32;dy=y-112;text_region=1;end
  if(app==SPLIT)begin
   if(y>=H/4-2&&y<H*3/4+2&&((sel&&px>=W/2)||(!sel&&px<W/2))&&
     (y<H/4||y>=H*3/4||px% (W/2)<2||px%(W/2)>=W/2-2))base={2{24'hffff00}};
   if(y>=H/4-24&&y<H/4-4&&((px>=12&&px<396)||(px>=W/2+12&&px<W/2+396)))begin
    txt="A LIVE WB                       ";txt[255-:8]=px>=W/2?"B":"A";txt[239-:32]=fp==0||(fp==1&&px<W/2)?"LIVE":"HIST";
    txt[199-:40]=sty(px>=W/2?mb:ma);dx=px>=W/2?px-W/2-12:px-12;dy=y-H/4+24;text_region=1;
    ink_color=(px>=W/2)==sel?24'hffff00:24'hffffff;
   end
  end
  // 52 frame number/count/time and both cursors remain visible below panes.
  if(app==SPLIT&&y>=H-176&&y<H-162&&px>=120&&px<1800)begin
   base={2{px<120+nframes*14?24'h28566e:24'h1b2c41}};
   if(fp==1&&fb!=0&&px>=120+(fb-1)*14&&px<130+(fb-1)*14)base={2{24'hffff00}};
   if(fp==2&&fa!=0&&px>=120+(fa-1)*14&&px<130+(fa-1)*14)base={2{sel?24'h00ffff:24'hffff00}};
   if(fp==2&&fb!=0&&px>=120+(fb-1)*14&&px<130+(fb-1)*14)base={2{sel?24'hffff00:24'h00ffff}};
  end
  if(app==SPLIT&&px>=32&&px<416&&y>=H-144&&y<H-124)begin
   txt="LIVE REC  000/120               ";txt[175-:24]=dec3({2'd0,nframes});
   if(fp!=0)begin txt="A000 B000 N000 DT00000MS        ";txt[247-:24]=dec3({2'd0,fa});txt[207-:24]=dec3({2'd0,fb});txt[167-:24]=dec3({2'd0,nframes});txt[119-:40]=dec5(dt);end
   else txt[215-:40]=recording?"REC  ":"DONE ";
   dx=px-32;dy=y-H+144;text_region=1;
  end
  if(app==SPLIT&&px>=32&&px<416&&y>=H-112&&y<H-92)begin
   txt=fp==0?"LIVE                            ":fp==1?(playing?"REPLAY PLAY                     ":"REPLAY PAUSED                   "):"COMPARE A/B                     ";
   if(fp==1)txt[111-:32]=speed==0?"0.5X":speed==1?"1.0X":"2.0X";
   dx=px-32;dy=y-H+112;text_region=1;
  end
  if(detail&&px>=32&&px<416&&y>=H-96&&y<H-76)begin txt="WB AUTO  FILTER FIXED ON        ";txt[231-:32]=wblock?"LOCK":"AUTO";dx=px-32;dy=y-H+96;text_region=1;end
  if(showfps&&px>=W-408&&px<W-24&&y>=H-48&&y<H-28)begin
   txt="FPS 000/000                     ";txt[223-:24]=fvalid?dec3(fc):"---";txt[191-:24]=fvalid?dec3(fv):"---";dx=px-W+408;dy=y-H+48;text_region=1;
  end
  if(!opened&&hint_left!=0&&px>=32&&px<416&&y>=H-64&&y<H-44)begin txt=notice_text();dx=px-32;dy=y-H+64;text_region=1;end
  if(!image_valid&&app!=SPLIT&&px>=32&&px<416&&y>=H-128&&y<H-108)begin txt="WAIT FRAME                      ";dx=px-32;dy=y-H+128;text_region=1;end
  if(opened&&px>=CARD_X&&px<CARD_X+400&&y>=CARD_Y&&y<CARD_Y+272)begin
   base={2{24'h20242a}};text_region=0;large_text=0;dx=px-CARD_X-8;dy=y-CARD_Y-8;
   if(dx>=0&&dx<384&&dy>=0)begin
    if(dy<24)begin txt=app_title(app);text_region=1;end
    else if(confirm)begin
     if(dy>=48&&dy<72)begin txt=menu_item(app,cursor,edge_style,fp)==RESET_DETECT?"RESET GLOBAL H6 L3 DN ON?       ":(menu_item(app,cursor,edge_style,fp)==NEW_TAKE?"START NEW 120 FRAME TAKE?       ":"RESTORE THIS VIEW?              ");dy=dy-48;text_region=1;end
     else if(dy>=96&&dy<120)begin txt="0 CONFIRM                       ";dy=dy-96;text_region=1;ink_color=24'hffff00;end
     else if(dy>=120&&dy<144)begin txt="1 CANCEL                        ";dy=dy-120;text_region=1;end
    end else if(dy>=24&&dy<168)begin
     row=(dy-24)/24;id=menu_item(app,scroll+row,edge_style,fp);
     if(scroll+row<menu_count(app,edge_style,fp))begin txt=item_text(id);dy=(dy-24)%24;text_region=1;
      if(scroll+row==cursor)ink_color=edit?24'h00ffff:24'hffff00;
     end
    end else if(dy>=184&&dy<208)begin txt=edit?"0 DONE    1 CLOSE               ":"0 EDIT    1 CLOSE               ";dy=dy-184;text_region=1;end
    else if(dy>=208&&dy<232)begin txt=edit?"2 -       3 +                   ":"2 UP      3 DOWN                ";dy=dy-208;text_region=1;end
    else if(dy>=240&&dy<264)begin txt=hint_left!=0&&ctx==3?"NO RESULT                       ":app<=SPLIT&&!run?"FROZEN OLD FRAME                ":"WB FILTER FIXED ON              ";dy=dy-240;text_region=1;end
   end
  end
  if(text_region)begin
   ci=large_text?dx/24:dx/12;col=large_text?(dx%24)/4:(dx%12)/2;gr=large_text?dy/4:dy/2;
   if(ci>=0&&ci<32)ch=txt[255-ci*8-:8];
   ink_region=dy<(large_text?28:14)&&col<5;
   base={2{opened&&px>=CARD_X&&px<CARD_X+400&&y>=CARD_Y&&y<CARD_Y+272?24'h20242a:24'h000000}};
  end
 end end
 reg [47:0] base_d;reg [7:0] ch_d;reg [2:0] gr_d,col_d;reg region_d;reg [23:0] color_d;
 reg dd,hd,vd;reg [34:0] bits;
 always @*bits=glyph(ch_d);
 always @(posedge clk)begin
 if(!rst_n)begin base_d<=0;ch_d<=32;gr_d<=0;col_d<=0;region_d<=0;color_d<=0;dd<=0;hd<=0;vd<=0;rgb_out<=0;de_out<=0;hs_out<=0;vs_out<=0;end
 else begin
 base_d<=base;ch_d<=ch;gr_d<=gr;col_d<=col;region_d<=ink_region;color_d<=ink_color;dd<=de_in;hd<=hs_in;vd<=vs_in;
 rgb_out<=region_d&&bits[34-(gr_d*5+col_d)]?{2{color_d}}:base_d;
 de_out<=dd;hs_out<=hd;vs_out<=vd;
 end end
endmodule
