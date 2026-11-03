// Native 1080p HDMI 2ppc. Two full-view 960x540 panes, no overlay on image.
module replay_raster52 #(
 parameter W=1920,H=1080,HT=1100,VT=1125,HB=96,VB=41,HS=22,VS=5
)(
 input wire clk,rst_n,ready,ack_toggle,input wire [95:0] ui_data,
 output reg frame_toggle,fifo_reset,input wire empty,input wire [127:0] head,
 output wire pop,output reg [47:0] rgb,output reg de,hs,vs,underflow,input wire [7:0] analysis_high,analysis_low
);
 localparam TOP=H/4,TH=H/2,HALF_BEATS=W/4;
 reg [11:0] h,v;reg [4:0] reset_count;reg phase,frame_ok,ack_seen;
 reg [95:0] status;
 wire [28:0] reserved;wire [1:0] page,speed,ma,mb;
 wire selected,recording,playing;wire [7:0] count,ia,ib,ta,tb;wire [15:0] delta;
 assign {reserved,page,selected,recording,playing,speed,count,ia,ib,ma,mb,ta,tb,delta}=status;
 wire active=h>=HB && h<HB+W/2 && v>=VB && v<VB+H;
 wire [11:0] xbeat=h-HB,y=v-VB;
 wire image_area=active && y>=TOP && y<TOP+TH;
 wire right_side=xbeat>=HALF_BEATS;
 wire [63:0] pair=phase ? head[63:0] : head[127:64];
 wire [1:0] mode=right_side?mb:ma;
 wire [7:0] threshold=right_side?tb:ta;
 // Serial decimal conversion finishes in blanking, outside the pixel path.
 reg convert_start;reg [4:0] digits_left;
 reg [35:0] shift_bcd[0:5];reg [19:0] decimal_bcd[0:5];integer n;
 function [35:0] adjusted(input [35:0] data);
  integer i;reg [35:0] q;
  begin q=data;for(i=4;i<9;i=i+1)if(q[i*4+:4]>=5)q[i*4+:4]=q[i*4+:4]+3;adjusted=q;end
 endfunction
 always @(posedge clk)begin
  if(!rst_n)begin
   convert_start<=0;digits_left<=0;
   for(n=0;n<6;n=n+1)begin shift_bcd[n]<=0;decimal_bcd[n]<=0;end
  end else begin
   convert_start<=ack_toggle!=ack_seen;
   if(convert_start)begin
    shift_bcd[0]<={20'd0,8'd0,count};shift_bcd[1]<={20'd0,8'd0,ia};
    shift_bcd[2]<={20'd0,8'd0,ib};shift_bcd[3]<={20'd0,delta};
    shift_bcd[4]<={20'd0,8'd0,analysis_high};shift_bcd[5]<={20'd0,8'd0,analysis_low};digits_left<=16;
   end else if(digits_left!=0)begin
    digits_left<=digits_left-1'b1;
    for(n=0;n<6;n=n+1)begin
     shift_bcd[n]<=adjusted(shift_bcd[n])<<1;
     if(digits_left==1)decimal_bcd[n]<=adjusted(shift_bcd[n])>>15;
    end
   end
  end
 end
 function [23:0] render(input [31:0] p,input [1:0] m,input [7:0] t);
  reg [23:0] color;
  begin
   color={p[22:15],p[14:7],p[6:0],p[6]};
   case(m)
    1:render=p[23]?24'hff0000:color;
    2:render={3{p[31:24]}};
    default:render=color;
   endcase
  end
 endfunction
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
       "C": glyph=35'b01110_10001_10000_10000_10000_10001_01110;
       "F": glyph=35'b11111_10000_10000_11110_10000_10000_10000;
       "J": glyph=35'b00111_00010_00010_00010_10010_10010_01100;
       "K": glyph=35'b10001_10010_10100_11000_10100_10010_10001;
       "N": glyph=35'b10001_11001_10101_10011_10001_10001_10001;
       "P": glyph=35'b11110_10001_10001_11110_10000_10000_10000;
       "Q": glyph=35'b01110_10001_10001_10001_10101_10010_01101;
       "U": glyph=35'b10001_10001_10001_10001_10001_10001_01110;
       "X": glyph=35'b10001_10001_01010_00100_01010_10001_10001;
       "Z": glyph=35'b11111_00001_00010_00100_01000_10000_11111;
       "/": glyph=35'b00001_00010_00010_00100_01000_01000_10000;
       "+": glyph=35'b00000_00100_00100_11111_00100_00100_00000;
       "-": glyph=35'b00000_00000_00000_11111_00000_00000_00000;
       ".": glyph=35'b00000_00000_00000_00000_00000_00100_00100;
       default: glyph=0;
     endcase
   end
 endfunction

 function [7:0] digit(input [19:0] b,input integer position);
  digit="0"+((b>>(position*4))&15);
 endfunction
 function [7:0] mode_char(input [1:0] m,input integer i);
  reg [63:0] text;
  begin
   case(m)1:text="RED     ";2:text="BAL     ";default:text="AUTO WB ";endcase
   mode_char=text[(7-i)*8+:8];
  end
 endfunction
 function [7:0] character(input integer line_id,input integer i);
  reg [8*64-1:0] text;reg [1:0] m;reg [7:0] t;reg [19:0] bcd;
  begin
   text={64{8'h20}};character=" ";m=ma;t=ta;bcd=decimal_bcd[1];
   case(line_id)
    0:text="FRAME LAB / 120                                                 ";
    1:text="LIVE      REPLAY      COMPARE                                   ";
    2:begin
     text=recording ? "RECORDING 000/120     SW0+3 NEW TAKE                            " :
                      "READY     000/120     SW0+3 NEW TAKE                            ";
     text[(63-10)*8+:8]=digit(decimal_bcd[0],2);
     text[(63-11)*8+:8]=digit(decimal_bcd[0],1);
     text[(63-12)*8+:8]=digit(decimal_bcd[0],0);
    end
    3,4:begin
     if(line_id==4)begin m=mb;t=tb;bcd=decimal_bcd[2];end
     text="A LIVE       AUTO WB                                            ";
     if(line_id==4)text[(63-0)*8+:8]="B";
     if((page==1 && line_id==4) || page==2)begin
      text[(63-6)*8+:40]="FRAME";
      text[(63-8)*8+:8]=digit(bcd,2);text[(63-9)*8+:8]=digit(bcd,1);text[(63-10)*8+:8]=digit(bcd,0);
     end
     text[(63-13)*8+:8]=mode_char(m,0);text[(63-14)*8+:8]=mode_char(m,1);
     text[(63-15)*8+:8]=mode_char(m,2);text[(63-16)*8+:8]=mode_char(m,3);
     text[(63-17)*8+:8]=mode_char(m,4);text[(63-18)*8+:8]=mode_char(m,5);
     text[(63-19)*8+:8]=mode_char(m,6);text[(63-20)*8+:8]=mode_char(m,7);
    end
    5:begin
     if(page==0)begin
      text="120 FRAMES  AUTO WB / RED / BAL  CANNY H000 L000                ";
      text[(63-40)*8+:8]=digit(decimal_bcd[4],2);text[(63-41)*8+:8]=digit(decimal_bcd[4],1);text[(63-42)*8+:8]=digit(decimal_bcd[4],0);
      text[(63-45)*8+:8]=digit(decimal_bcd[5],2);text[(63-46)*8+:8]=digit(decimal_bcd[5],1);text[(63-47)*8+:8]=digit(decimal_bcd[5],0);
     end
     if(page==1)begin
      text=playing ? "FRAME 000/000   PLAY    1X   HOLD SW3 SPEED                     " :
                     "FRAME 000/000   PAUSED  1X   HOLD SW3 SPEED                     ";
      text[(63-6)*8+:8]=digit(decimal_bcd[2],2);text[(63-7)*8+:8]=digit(decimal_bcd[2],1);text[(63-8)*8+:8]=digit(decimal_bcd[2],0);
      text[(63-10)*8+:8]=digit(decimal_bcd[0],2);text[(63-11)*8+:8]=digit(decimal_bcd[0],1);text[(63-12)*8+:8]=digit(decimal_bcd[0],0);
      text[(63-27)*8+:32]=speed==0?"0.5X":speed==2?"2X  ":"1X  ";
     end
     if(page==2)begin
      text="A 000   B 000   DELTA 00000 MS                                  ";
      text[(63-2)*8+:8]=digit(decimal_bcd[1],2);text[(63-3)*8+:8]=digit(decimal_bcd[1],1);text[(63-4)*8+:8]=digit(decimal_bcd[1],0);
      text[(63-10)*8+:8]=digit(decimal_bcd[2],2);text[(63-11)*8+:8]=digit(decimal_bcd[2],1);text[(63-12)*8+:8]=digit(decimal_bcd[2],0);
      text[(63-22)*8+:8]=digit(decimal_bcd[3],4);text[(63-23)*8+:8]=digit(decimal_bcd[3],3);text[(63-24)*8+:8]=digit(decimal_bcd[3],2);
      text[(63-25)*8+:8]=digit(decimal_bcd[3],1);text[(63-26)*8+:8]=digit(decimal_bcd[3],0);
     end
    end
    6:begin
     text="SW0 PAGE   SW1 PREV   SW2 NEXT   SW3 PLAY                       ";
     if(page==0)text="SW0 PAGE   SW1/2 H-/+   SW3 STOP   SW0+3 NEW TAKE               ";
     if(page==2)text="SW0 PAGE   SW1 PREV   SW2 NEXT   SW3 SELECT A/B                 ";
    end
    7:begin
     if(page==0)text="HOLD SW0 VIEW   SW0+3 NEW TAKE                                  ";
     else if(page==1)text="HOLD SW1/2 REPEAT   HOLD SW0 VIEW   HOLD SW3 SPEED              ";
     else text="HOLD SW1/2 REPEAT   HOLD SW0 VIEW                               ";
    end
    default:begin end
   endcase
   if(i>=0 && i<64)character=text[(63-i)*8+:8];
  end
 endfunction
 function text_on(input integer px,py,ox,oy,line_id,scale);
  integer dx,dy,ci,col,row;reg [34:0] bits;
  begin
   dx=px-ox;dy=py-oy;text_on=0;
   if(dx>=0 && dy>=0 && dy<(7<<scale) && dx<(64<<(3+scale)))begin
    ci=dx>>(3+scale);col=(dx>>scale)&7;row=dy>>scale;
    bits=glyph(character(line_id,ci));
    if(col<5)text_on=bits[34-(row*5+col)];
   end
  end
 endfunction
 function [23:0] background(input integer px,py);
  reg b,sel;integer lx,marker_a,marker_b,fill;
  begin
   b=px>=W/2;lx=b?px-W/2:px;sel=page==2 ? b==selected : (page==1 && b);
   background=24'h0b1321;
   if(py<112)background=24'h14243a;
   if(text_on(px,py,64,44,0,2))background=24'hffffff;
   if(text_on(px,py,64,140,1,2))begin
    if((page==0 && px<320)||(page==1 && px>=384 && px<704)||(page==2 && px>=768))background=24'h5de4ff;
    else background=24'h728399;
   end
   if(text_on(px,py,64,198,2,1))background=recording?24'hff796e:24'h68e1b3;
   if((py==TOP-3 || py==TOP+TH+2))background=sel?24'hffc857:24'h31465d;
   if(text_on(lx,py,24,TOP-30,b?4:3,1))background=sel?24'hffc857:24'he3edf6;
   if(text_on(px,py,64,TOP+TH+30,5,1))background=24'h5de4ff;
   if(text_on(px,py,64,H-118,6,1))background=24'he3edf6;
   if(text_on(px,py,64,H-76,7,1))background=24'h9cacc0;
   marker_a=120+(ia==0?0:ia-1)*14;marker_b=120+(ib==0?0:ib-1)*14;fill=120+count*14;
   if(py>=H-186 && py<H-172 && px>=120 && px<120+120*14)begin
    background=px<fill?24'h28566e:24'h1b2c41;
    if(page==1 && px>=marker_b && px<marker_b+10)background=24'hffc857;
    if(page==2 && px>=marker_a && px<marker_a+10)background=selected?24'h5de4ff:24'hffc857;
    if(page==2 && px>=marker_b && px<marker_b+10)background=selected?24'hffc857:24'h5de4ff;
   end
  end
 endfunction
 assign pop=image_area && frame_ok && phase && !empty;
 always @(posedge clk)begin
  if(!rst_n)begin
   h<=0;v<=0;reset_count<=0;phase<=0;frame_ok<=0;ack_seen<=0;status<=0;
   frame_toggle<=0;fifo_reset<=1;rgb<=0;de<=0;hs<=0;vs<=0;underflow<=0;
  end else begin
   h<=h==HT-1?0:h+1'b1;if(h==HT-1)v<=v==VT-1?0:v+1'b1;
   hs<=h<HS;vs<=v<VS;de<=active;
   rgb<=(active && !image_area)?{background(xbeat*2+1,y),background(xbeat*2,y)}:48'd0;
   if(ack_toggle!=ack_seen)begin ack_seen<=ack_toggle;frame_ok<=1;status<=ui_data;end
   if(h==0 && v==0)begin frame_toggle<=~frame_toggle;fifo_reset<=1;reset_count<=0;frame_ok<=0;end
   else if(reset_count<16)begin reset_count<=reset_count+1'b1;fifo_reset<=1;end
   else fifo_reset<=0;
   if(!image_area)phase<=0;
   else if(frame_ok)begin
    if(empty)begin rgb<=0;underflow<=1;frame_ok<=0;end
    else begin
     rgb<=((page==1 && right_side && count==0)||(page==2 && count==0)) ? 48'd0 :
       {render(pair[31:0],mode,threshold),render(pair[63:32],mode,threshold)};phase<=~phase;end
   end else rgb<=0;
  end
 end
endmodule
