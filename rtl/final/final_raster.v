
// Constant-rate 2ppc panel raster, with two 960x540 thumbnails centered in 1080p.
// All per-object UI values and placement are latched on the SAME frame boundary.
module final_raster #(
 parameter UI_V2=0,W=1920,H=1080, HT=1066,VT=1122, HB=46,VB=22,HS=2,VS=2,
 parameter PANEL_SWAP_RB_ON_EDGE=1,
 parameter integer OSD_TIMEOUT_FRAMES=480
)(
 input wire clk,rst_n,ready,ack_toggle,input wire image_compatible,output wire display_valid,output wire frame_tick,
 input wire [2:0] mode_a,mode_b,
 input wire [7:0] low_a,low_b,analysis_high,analysis_low,
 input wire shape_enable,number_enable,edit_low,fullscreen,denoise_enable,input wire [1:0] menu_page,
 input wire [9:0] fps_cam,fps_vid,input wire fps_valid,
 input wire [7:0] ai_min_strength,input wire ai_min_select,
 input wire osd_activity_toggle,osd_help_toggle,input wire [2:0] osd_context,
 output reg fullscreen_frame,
 input wire [7:0] threshold_a,threshold_b,
 input wire selected_b,swap_sides,live_b,capture_a,capture_b,same_frame,
 input wire live_a,live_group,capture_group,wb_locked,
 output reg live_a_frame,live_group_frame,cap_group_frame,
 output reg same_frame_latched,
 output wire source_b_frame,
 output reg frame_toggle,swap_frame,live_frame,cap_a_frame,cap_b_frame,
 output reg fifo_reset,
 input wire empty,
 input wire [127:0] head,
 output wire pop,
 output wire [47:0] rgb,
 output wire de,hs,vs,
 output reg underflow
);
 localparam TOP=H/4, TH=H/2, HALF_BEATS=W/4;
 reg [11:0] h,v;
 reg [4:0] reset_count;
 reg [1:0] phase;reg frame_ok,ack_seen,selected_frame,wb_lock_frame;
 assign frame_tick=h==0&&v==0;
 assign display_valid=frame_ok&&(!UI_V2||image_compatible);
 reg [2:0] ma,mb;
 reg [7:0] la,lb,aihi,ailo;reg [9:0] fc,fv;reg fvalid,dn,min_select;reg [7:0] min_strength;reg ai_num,ai_shape,edit_l;reg [1:0] page;
 reg [127:0] raw_pixels;reg [5:0] raw_modes;reg [3:0] raw_classes;reg raw_de,raw_hs,raw_vs;
 reg [7:0] ta,tb;
 wire active=h>=HB && h<HB+W/2 && v>=VB && v<VB+H;
 wire [11:0] xbeat=h-HB,y=v-VB;
 wire image_area=active && (fullscreen_frame || (y>=TOP && y<TOP+TH));
 wire edge_side=(xbeat>=HALF_BEATS)^swap_frame;
 wire obj_b=fullscreen_frame ? selected_frame : edge_side;
 wire [2:0] mode=obj_b ? mb : ma;
 assign source_b_frame=selected_frame;
 wire [7:0] threshold=obj_b ? tb : ta,low=obj_b?lb:la;
 wire [127:0] pair=head;
 reg [63:0] single_pixel;
 always @* single_pixel=phase[0]?head[63:0]:head[127:64];
 wire [127:0] display_pair=fullscreen_frame?{single_pixel,single_pixel}:pair;
 function [13:0] pack554(input [23:0] p);pack554={p[23:19],p[15:11],p[7:4]};endfunction
 function [63:0] bgpixel(input [11:0] xx,yy);bgpixel={49'd0,1'b1,pack554(background(xx,yy))};endfunction
 function [1:0] classify(input [63:0] p,input [11:0] xx,yy);
 reg border;
 begin
 border=xx==0||xx==W-1||yy==0||yy==H-1;
 if(!fullscreen_frame)border=border||xx==W/2-1||xx==W/2||yy==TOP||yy==TOP+TH-1;
 classify=border?2'd0:{p[47:40]>=threshold,p[47:40]>=low};
 end endfunction
 localparam [23:0] MARK=PANEL_SWAP_RB_ON_EDGE ? 24'h0000ff : 24'hff0000;
 // Compact 5x7 text. 7 rows, MSB is the top-left pixel.
 function [34:0] glyph(input [7:0] c);
   begin
     case(c)
       "A": glyph=35'b01110_10001_10001_11111_10001_10001_10001;
       "B": glyph=35'b11110_10001_10001_11110_10001_10001_11110;
       "R": glyph=35'b11110_10001_10001_11110_10100_10010_10001;
       "W": glyph=35'b10001_10001_10001_10101_10101_10101_01010;
       "E": glyph=35'b11111_10000_10000_11110_10000_10000_11111;
       "D": glyph=35'b11110_10001_10001_10001_10001_10001_11110;
       "L": glyph=35'b10000_10000_10000_10000_10000_10000_11111;
       "I": glyph=35'b11111_00100_00100_00100_00100_00100_11111;
       "V": glyph=35'b10001_10001_10001_10001_10001_01010_00100;
       "H": glyph=35'b10001_10001_10001_11111_10001_10001_10001;
       "O": glyph=35'b01110_10001_10001_10001_10001_10001_01110;
       "T": glyph=35'b11111_00100_00100_00100_00100_00100_00100;
       "1": glyph=35'b00100_01100_00100_00100_00100_00100_01110;
       "2": glyph=35'b01110_10001_00001_00010_00100_01000_11111;
       "3": glyph=35'b11110_00001_00001_01110_00001_00001_11110;
       "4": glyph=35'b00010_00110_01010_10010_11111_00010_00010;
       "5": glyph=35'b11111_10000_10000_11110_00001_00001_11110;
       "6": glyph=35'b01110_10000_10000_11110_10001_10001_01110;
       "0": glyph=35'b01110_10001_10011_10101_11001_10001_01110;
       "7": glyph=35'b11111_00001_00010_00100_01000_01000_01000;
       "8": glyph=35'b01110_10001_10001_01110_10001_10001_01110;
       "9": glyph=35'b01110_10001_10001_01111_00001_00001_01110;
       "G": glyph=35'b01110_10001_10000_10111_10001_10001_01110;
       "Y": glyph=35'b10001_10001_01010_00100_00100_00100_00100;
       "S": glyph=35'b01111_10000_10000_01110_00001_00001_11110;
       "M": glyph=35'b10001_11011_10101_10101_10001_10001_10001;
       "N": glyph=35'b10001_11001_11001_10101_10011_10011_10001;
       "C": glyph=35'b01110_10001_10000_10000_10000_10001_01110;
       "P": glyph=35'b11110_10001_10001_11110_10000_10000_10000;
       "K": glyph=35'b10001_10010_10100_11000_10100_10010_10001;
       "U": glyph=35'b10001_10001_10001_10001_10001_10001_01110;
       "F": glyph=35'b11111_10000_10000_11110_10000_10000_10000;
       "/": glyph=35'b00001_00010_00010_00100_01000_01000_10000;
       "+": glyph=35'b00000_00100_00100_11111_00100_00100_00000;
       "-": glyph=35'b00000_00000_00000_11111_00000_00000_00000;
       default: glyph=0;
     endcase
   end
 endfunction
 // BEGIN SLIM OSD -- 5x7 glyphs, 2x scale, 12-pixel pitch, 24-pixel rows.
 localparam OSD_TW=OSD_TIMEOUT_FRAMES>1?$clog2(OSD_TIMEOUT_FRAMES+1):1;
 reg [OSD_TW-1:0] osd_idle;
 reg osd_seen,osd_pending,osd_help_frame,osd_awake;
 reg [2:0] osd_pending_context,osd_context_frame;
 wire osd_event=osd_activity_toggle!=osd_seen;
 wire osd_frame_start=h==0&&v==0;
 // Event capture runs every video clock; rendering changes only at frame start.
 // This keeps even a press and release between two frames from being missed.
 always @(posedge clk)begin
  if(!rst_n)begin
   osd_idle<=OSD_TIMEOUT_FRAMES;osd_seen<=0;osd_pending<=0;
   osd_help_frame<=0;osd_awake<=0;osd_pending_context<=0;osd_context_frame<=0;
  end else begin
   if(osd_event)begin
    osd_seen<=osd_activity_toggle;osd_pending<=1;osd_pending_context<=osd_context;
   end
   if(osd_frame_start)begin
    osd_help_frame<=osd_help_toggle;
    if(osd_event||osd_pending||osd_help_frame!=osd_help_toggle)begin
     osd_idle<=0;osd_awake<=1;osd_pending<=0;
     osd_context_frame<=osd_event?osd_context:osd_pending?osd_pending_context:3'd0;
    end else if(osd_idle<OSD_TIMEOUT_FRAMES)begin
     osd_idle<=osd_idle+1'b1;
     if(osd_idle==OSD_TIMEOUT_FRAMES-1)begin osd_awake<=0;osd_context_frame<=0;end
    end
   end
  end
 end
 function integer decimal_length(input [9:0] value);
  decimal_length=value>=100?3:value>=10?2:1;
 endfunction
 function [7:0] decimal_character(input integer index,input [9:0] value);
  begin
   decimal_character=" ";
   if(index>=0&&index<decimal_length(value))begin
    if(value>=100&&index==0)decimal_character="0"+value/100;
    else if((value>=100&&index==1)||(value>=10&&value<100&&index==0))decimal_character="0"+(value/10)%10;
    else decimal_character="0"+value%10;
   end
  end
 endfunction
 function integer mode_length(input [2:0] m);
  mode_length=m==0?2:m==3?4:m==4?5:3;
 endfunction
 function [7:0] character(input [5:0] i,input b,input live,input [2:0] m,input [7:0] hi,lo,input same);
  reg [39:0] name;integer pos;
  begin
   character=" ";name=m==0?"WB   ":m==1?"RED  ":m==2?"BAL  ":m==3?"GRAY ":"CLEAN";
   if(i==0)character=b?"B":"A";
   else if(i>=2&&i<6)case(i)
    2:character=live?"L":"H";3:character=live?"I":"O";4:character=live?"V":"L";5:character=live?"E":"D";
   endcase
   else if(i>=7&&i<7+mode_length(m))character=name[39-(i-7)*8-:8];
   // H/L are parameters: they appear only during a window-threshold adjustment.
   else if(osd_awake&&osd_context_frame==1)begin
    pos=8+mode_length(m);
    if(i==pos)character="H";
    else if(i>pos&&i<=pos+decimal_length({2'b0,hi}))character=decimal_character(i-pos-1,{2'b0,hi});
    else begin
     pos=pos+decimal_length({2'b0,hi})+2;
     if(i==pos)character="L";
     else character=decimal_character(i-pos-1,{2'b0,lo});
    end
   end
  end
 endfunction
 function osd_row_visible(input integer row);
  begin case(row)
   0:osd_row_visible=ai_num||ai_shape;
   1:osd_row_visible=1;
   2:osd_row_visible=osd_awake&&osd_context_frame!=0;
   default:osd_row_visible=osd_help_frame&&osd_awake;
  endcase end
 endfunction
 function [7:0] menu_character(input integer row,input integer i);
  reg [383:0] text;integer pos,j;reg [7:0] hi,lo;
  begin
   text={48{8'd32}};menu_character=" ";pos=0;j=0;hi=selected_frame?tb:ta;lo=selected_frame?lb:la;
   case(row)
    0:begin
     text="AI NUM0 SHAPE0 INDP WB AUTO FPS                 ";
     text[383-6*8-:8]=ai_num?"1":"0";text[383-13*8-:8]=ai_shape?"1":"0";
     text[383-15*8-:32]=same_frame_latched?"SYNC":"INDP";
     text[383-23*8-:32]=wb_lock_frame?"LOCK":"AUTO";
     menu_character=text[383-i*8-:8];
     if(i>=19&&!(osd_help_frame&&osd_awake))menu_character=" ";
     else if(i>=31)begin
      j=i-31;
      if(!fvalid)begin text="---/---                                         ";menu_character=j<7?text[383-j*8-:8]:8'd32;end
      else if(j<decimal_length(fc))menu_character=decimal_character(j,fc);
      else if(j==decimal_length(fc))menu_character="/";
      else menu_character=decimal_character(j-decimal_length(fc)-1,fv);
     end
    end
    1:begin
     case(page)
      0:text="VIEW                                            ";1:text="CANNY                                           ";2:text="AI                                              ";3:text="AI EDGE                                         ";
     endcase
     menu_character=text[383-i*8-:8];
    end
    2:begin
     case(osd_context_frame)
      1,2:begin
       if(osd_context_frame==2)begin hi=aihi;lo=ailo;text="AI H                                            ";pos=4;end
       else begin text="B H                                             ";text[383-:8]=selected_frame?"B":"A";pos=3;end
       menu_character=i<pos?text[383-i*8-:8]:decimal_character(i-pos,{2'b0,hi});
       j=pos+decimal_length({2'b0,hi});
       if(i==j+1)menu_character="L";
       else if(i>j+1)menu_character=decimal_character(i-j-2,{2'b0,lo});
       pos=j+2+decimal_length({2'b0,lo});
       if(osd_context_frame==2)begin
        text=" MIN                                            ";
        if(i>=pos&&i<pos+4)menu_character=text[383-(i-pos)*8-:8];
        else if(i>=pos+4)menu_character=decimal_character(i-pos-4,{2'b0,min_strength});
        pos=pos+4+decimal_length({2'b0,min_strength});
       end
       text=" EDIT H                                         ";
       if(osd_context_frame==2&&min_select)text=" EDIT MIN                                       ";
       else if(edit_l)text=" EDIT L                                         ";
       if(i>=pos&&i<pos+9)menu_character=text[383-(i-pos)*8-:8];
      end
      3:begin text=dn?"DENOISE ON                                      ":"DENOISE OFF                                     ";menu_character=text[383-i*8-:8];end
      4:begin text=wb_lock_frame?"WB LOCK                                         ":"WB AUTO                                         ";menu_character=text[383-i*8-:8];end
     endcase
    end
    3:begin
     case(page)
      0:text="0 MODE 2 A/B 3 HOLD                             ";1:text="0 H/L 1 A/B 2+ 3-                               ";2:text="0 NUM 1 SHAPE 2 WB 3 FULL                       ";3:text="0 H/L/MIN 1 A/B 2+ 3-                           ";
     endcase
     menu_character=text[383-i*8-:8];
    end
    4:begin text="1+2 PAGE 0+1 SYNC 2+3 LIVE                      ";menu_character=text[383-i*8-:8];end
    5:begin text=page==2?"0+1+2 HELP 0+2 WB 0+3 DN                        ":"0+1+2 HELP 0+2 WB                               ";menu_character=text[383-i*8-:8];end
   endcase
  end
 endfunction
 function osd_top_area(input [11:0] px,py);
  integer row;
  begin row=(py-20)/24;osd_top_area=px>=12&&px<588&&py>=20&&py<164&&osd_row_visible(row);end
 endfunction
 // Text stays in the letterbox in split view. Fullscreen covers only visible rows.
 function [23:0] background(input [11:0] px,input [11:0] py);
  reg b,sel;reg [11:0] lx;reg [2:0] m;reg [7:0] hi,lo,c;
  reg [34:0] bits;integer dx,dy,ci,col,gr,row;
  begin
   b=fullscreen_frame?selected_frame:(px>=W/2)^swap_frame;sel=b==selected_frame;
   lx=fullscreen_frame?px:px>=W/2?px-W/2:px;
   m=b?mb:ma;hi=b?tb:ta;lo=b?lb:la;background=24'h101010;
   if(!fullscreen_frame&&(py==TOP-2||py==TOP+TH+1)&&sel)background=24'hffff00;
   dx=lx-12;dy=py-(TOP-22);
   if(dx>=0&&dx<336&&dy>=0&&dy<14)begin
    ci=dx/12;col=(dx%12)/2;gr=dy/2;
    c=character(ci,b,same_frame_latched?live_group_frame:(b?live_frame:live_a_frame),m,hi,lo,same_frame_latched);
    bits=glyph(c);if(col<5&&bits[34-(gr*5+col)])background=sel?24'hffff00:24'hffffff;
   end
   dx=px-12;dy=py-20;
   if(dx>=0&&dx<576&&dy>=0&&dy<144)begin
    row=dy/24;ci=dx/12;col=(dx%12)/2;gr=(dy%24)/2;
    if(osd_row_visible(row))begin
     c=menu_character(row,ci);bits=glyph(c);
     if(gr<7&&col<5&&bits[34-(gr*5+col)])background=24'hffffff;
    end
   end
   if(UI_V2)background=24'h101010;
  end
 endfunction
 // END SLIM OSD
 assign pop=image_area&&frame_ok&&(fullscreen_frame?phase[0]:1'b1)&&!empty;
 final_replay #(.W(W),.H(H),.HT(HT),.PANEL_SWAP_RB_ON_EDGE(PANEL_SWAP_RB_ON_EDGE),.COMMON_MODE(1)) replay(
 .clk(clk),.rst_n(rst_n),.pixels(raw_pixels),.modes(raw_modes),.classes(raw_classes),.de(raw_de),.hs(raw_hs),.vs(raw_vs),
 .rgb_out(rgb),.de_out(de),.hs_out(hs),.vs_out(vs));
 always @(posedge clk) begin
   if(!rst_n) begin
     h<=0;v<=0;reset_count<=0;phase<=0;frame_ok<=0;ack_seen<=0;
     frame_toggle<=0;swap_frame<=0;live_frame<=1;cap_a_frame<=0;cap_b_frame<=0;
     live_a_frame<=1;live_group_frame<=1;cap_group_frame<=0;
     wb_lock_frame<=0;same_frame_latched<=0;selected_frame<=1;ma<=0;mb<=2;ta<=6;tb<=6;la<=3;lb<=3;aihi<=6;ailo<=3;fc<=0;fv<=0;fvalid<=0;dn<=1;min_select<=0;min_strength<=0;ai_num<=0;ai_shape<=0;edit_l<=0;page<=0;fullscreen_frame<=0;
     fifo_reset<=1;raw_pixels<=0;raw_modes<=0;raw_classes<=0;raw_de<=0;raw_hs<=0;raw_vs<=0;underflow<=0;
   end else begin
     h<=h==HT-1 ? 0 : h+1'b1;
     if(h==HT-1) v<=v==VT-1 ? 0 : v+1'b1;
     raw_hs<=h<HS;raw_vs<=v<VS;raw_de<=active;
     raw_pixels<=active?{bgpixel(xbeat*2+1,y),bgpixel(xbeat*2,y)}:128'd0;raw_modes<=0;raw_classes<=0;
     if(ack_toggle!=ack_seen) begin ack_seen<=ack_toggle;frame_ok<=1;end
     if(h==0 && v==0) begin
       frame_toggle<=~frame_toggle;fifo_reset<=1;reset_count<=0;frame_ok<=0;
       ma<=mode_a;mb<=mode_b;ta<=threshold_a;tb<=threshold_b;la<=low_a;lb<=low_b;
       aihi<=analysis_high;ailo<=analysis_low;fc<=fps_cam;fv<=fps_vid;fvalid<=fps_valid;dn<=denoise_enable;min_select<=ai_min_select;min_strength<=ai_min_strength;ai_num<=number_enable;ai_shape<=shape_enable;
       edit_l<=edit_low;page<=menu_page;fullscreen_frame<=fullscreen;
       wb_lock_frame<=wb_locked;same_frame_latched<=same_frame;selected_frame<=selected_b;swap_frame<=0;live_frame<=live_b;
       cap_a_frame<=capture_a;cap_b_frame<=capture_b;
       live_a_frame<=live_a;live_group_frame<=live_group;cap_group_frame<=capture_group;
     end else if(reset_count<16) begin reset_count<=reset_count+1'b1;fifo_reset<=1;end
     else fifo_reset<=0;
     if(!image_area) phase<=0;
     else if(frame_ok) begin
       // Drop the rest of this display frame on starvation. A later response
       // must not resume at x=0 halfway across the current raster line.
       if(empty) begin raw_pixels<=0;underflow<=1;frame_ok<=0;end
       else begin
         raw_pixels<={display_pair[63:16],display_pair[15]&&threshold==6&&low==3,display_pair[14:0],
                       display_pair[127:80],display_pair[79]&&threshold==6&&low==3,display_pair[78:64]};raw_modes<={mode,mode};
         raw_classes<={classify(display_pair[63:0],xbeat*2+1,y),classify(display_pair[127:64],xbeat*2,y)};
         phase<=fullscreen_frame?{1'b0,~phase[0]}:2'd0;
         // Keep controls visible in full-screen view; consume image data normally.
         if(!UI_V2&&W>=640&&fullscreen_frame&&
            (osd_top_area(xbeat*2,y)||(y>=TOP-22&&y<TOP-8&&xbeat<174)))
          raw_pixels<={bgpixel(xbeat*2+1,y),bgpixel(xbeat*2,y)};
         if(UI_V2&&!image_compatible)raw_pixels<=0;
       end
     end else raw_pixels<=0;
   end
 end
 // synthesis translate_off
 initial begin
   if(W%8 || H%4 || W<32 || H<32 || HT<W/2+HB || VT<H+VB)
     $fatal(1,"Unsupported compare raster format");
 end
 // synthesis translate_on
endmodule
