// 5x7 bitmap font at 3x scale, two pixels per clock. Two pipeline stages.
// Snapshot at source SOF, then transfer to the matching enhanced output SOF.
// Text is applied AFTER gamma/sharpen so the controls cannot recolor the text.
module wb_status_osd(input clk,rst,cfg_sof,input [1:0] cfg_mode,cfg_channel,
 input [11:0] cfg_r,cfg_g,cfg_b,input cfg_rejected,
 input [47:0] in_rgb,input in_de,in_hs,in_vs,
 output reg [47:0] out_rgb,output reg out_de,out_hs,out_vs,input cfg_fine);
 reg pending_fine,fine_step;
 reg [11:0] pending_qr,pending_qg,pending_qb,qr,qg,qb;
 reg [1:0] pending_mode,pending_channel,mode,channel;
 reg pending_rejected,rejected;
 reg [15:0] pending_r,pending_g,pending_b,red,green,blue;
 // Decimal x.xxx, rounded from Q8; configuration path only, not per pixel.
 function [15:0] decimal_gain(input [11:0] gain);
  integer milli;reg [3:0] a,b,c,d;
  begin milli=(gain*1000+128)>>8;
   a=milli/1000;b=(milli/100)%10;c=(milli/10)%10;d=milli%10;
   decimal_gain={a,b,c,d};
  end
 endfunction
 reg old_vs,old_de,frame_pending;reg [11:0] x,y;
 wire first=in_de && (frame_pending || (in_vs && !old_vs));
 wire [11:0] px=first?12'd0:x,py=first?12'd0:y;
 always @(posedge clk)begin
  if(rst)begin
   pending_fine<=0;fine_step<=0;pending_qr<=256;pending_qg<=256;pending_qb<=256;qr<=256;qg<=256;qb<=256;
   pending_mode<=0;pending_channel<=0;pending_rejected<=0;
   pending_r<=16'h1000;pending_g<=16'h1000;pending_b<=16'h1000;
   mode<=0;channel<=0;rejected<=0;red<=16'h1000;green<=16'h1000;blue<=16'h1000;
   old_vs<=0;old_de<=0;frame_pending<=1;x<=0;y<=0;
  end else begin
   if(cfg_sof)begin
    pending_fine<=cfg_fine;pending_qr<=cfg_r;pending_qg<=cfg_g;pending_qb<=cfg_b;
    pending_mode<=cfg_mode;pending_channel<=cfg_channel;pending_rejected<=cfg_rejected;
    pending_r<=decimal_gain(cfg_r);pending_g<=decimal_gain(cfg_g);pending_b<=decimal_gain(cfg_b);
   end
   old_vs<=in_vs;old_de<=in_de;
   if(in_vs && !old_vs)begin frame_pending<=1;y<=0;end
   else if(old_de && !in_de)y<=y+1'b1;
   if(in_de)x<=px+2;else x<=0;
   if(first)begin
    fine_step<=pending_fine;qr<=pending_qr;qg<=pending_qg;qb<=pending_qb;
    frame_pending<=0;y<=0;mode<=pending_mode;channel<=pending_channel;rejected<=pending_rejected;
    red<=pending_r;green<=pending_g;blue<=pending_b;
   end
  end
 end
 function [7:0] digit(input [15:0] n,input integer pos);
  begin case(pos)
   3:digit="0"+n[15:12];4:digit=".";5:digit="0"+n[11:8];
   6:digit="0"+n[7:4];7:digit="0"+n[3:0];8:digit="X";
   default:digit=" ";endcase end
 endfunction
 // 28 columns x 8 rows; cell is 18x24 pixels, panel is 504x192 pixels.
 function [7:0] character(input integer row,col);
  begin character=" ";case(row)
   0:case(col)
    0:character="W";1:character="B";2:character=":";
    4:character=mode==0?"A":(mode==1?"L":"M");
    5:character=mode==0?"U":(mode==1?"O":"A");
    6:character=mode==0?"T":(mode==1?"C":"N");
    7:character=mode==0?"O":(mode==1?"K":"U");
    8:if(mode==2)character="A";9:if(mode==2)character="L";
   endcase
   1,2,3:begin
    if(col==0)begin
     if((row==1&&channel==0)||(row==2&&channel==2)||(row==3&&channel==1))character=">";
    end else if(col==1)character=row==1?"R":(row==2?"G":"B");
    else if(col==2)character=":";
    else if(col<10)character=digit(row==1?red:(row==2?green:blue),col);
    else if(col==10)character="Q";
    else if(col>=11 && col<=14)begin
     case(col)
      11:character="0"+(row==1?qr:(row==2?qg:qb))/1000;
      12:character="0"+((row==1?qr:(row==2?qg:qb))/100)%10;
      13:character="0"+((row==1?qr:(row==2?qg:qb))/10)%10;
      14:character="0"+(row==1?qr:(row==2?qg:qb))%10;
     endcase
    end
   end
   4:case(col)
    0:character="E";1:character="D";2:character="I";3:character="T";4:character=":";
    6:character=channel==0?"R":(channel==1?"B":(channel==2?"G":"L"));
    7:if(channel==3)character="I";8:if(channel==3)character="G";
    9:if(channel==3)character="H";10:if(channel==3)character="T";
   endcase
   5:case(col)
    0:character="S";1:character="T";2:character="E";3:character="P";4:character=":";
    6:character="0";7:character=".";8:character=channel==3?"2":(fine_step?"0":"1");
    9:character=channel==3?"5":(fine_step?"1":"2");10:character=channel==3?"0":(fine_step?"6":"5");11:character="X";
   endcase
   6:case(col)
    0:character="S";1:character="W";2:character="3";4:character="S";5:character="E";
    6:character="L";7:character="E";8:character="C";9:character="T";
    12:character="S";13:character="W";14:character="1";15:character="+";
    18:character="S";19:character="W";20:character="2";21:character="-";
   endcase
   7:if(mode!=0 || !rejected)case(col)
    0:character="S";1:character="W";2:character="0";4:character="M";5:character="O";6:character="D";7:character="E";10:character="S";11:character="W";12:character="3";13:character="+";14:character="2";16:character="S";17:character="T";18:character="E";19:character="P";
   endcase else case(col)
    0:character="L";1:character="O";2:character="W";4:character="S";5:character="A";
    6:character="M";7:character="P";8:character="L";9:character="E";10:character="S";
   endcase
  endcase end
 endfunction
 function [34:0] glyph(input [7:0] c);
  begin case(c)
   "0":glyph=35'b01110_10001_10011_10101_11001_10001_01110;
   "1":glyph=35'b00100_01100_00100_00100_00100_00100_01110;
   "2":glyph=35'b01110_10001_00001_00010_00100_01000_11111;
   "3":glyph=35'b11110_00001_00001_01110_00001_00001_11110;
   "4":glyph=35'b00010_00110_01010_10010_11111_00010_00010;
   "5":glyph=35'b11111_10000_10000_11110_00001_00001_11110;
   "6":glyph=35'b01110_10000_10000_11110_10001_10001_01110;
   "7":glyph=35'b11111_00001_00010_00100_01000_01000_01000;
   "8":glyph=35'b01110_10001_10001_01110_10001_10001_01110;
   "9":glyph=35'b01110_10001_10001_01111_00001_00001_01110;
   "A":glyph=35'b01110_10001_10001_11111_10001_10001_10001;
   "B":glyph=35'b11110_10001_10001_11110_10001_10001_11110;
   "C":glyph=35'b01111_10000_10000_10000_10000_10000_01111;
   "D":glyph=35'b11110_10001_10001_10001_10001_10001_11110;
   "E":glyph=35'b11111_10000_10000_11110_10000_10000_11111;
   "G":glyph=35'b01111_10000_10000_10111_10001_10001_01111;
   "H":glyph=35'b10001_10001_10001_11111_10001_10001_10001;
   "I":glyph=35'b01110_00100_00100_00100_00100_00100_01110;
   "K":glyph=35'b10001_10010_10100_11000_10100_10010_10001;
   "L":glyph=35'b10000_10000_10000_10000_10000_10000_11111;
   "M":glyph=35'b10001_11011_10101_10101_10001_10001_10001;
   "N":glyph=35'b10001_11001_11001_10101_10011_10011_10001;
   "O":glyph=35'b01110_10001_10001_10001_10001_10001_01110;
   "P":glyph=35'b11110_10001_10001_11110_10000_10000_10000;
   "Q":glyph=35'b01110_10001_10001_10001_10101_10010_01101;
   "R":glyph=35'b11110_10001_10001_11110_10100_10010_10001;
   "S":glyph=35'b01111_10000_10000_01110_00001_00001_11110;
   "T":glyph=35'b11111_00100_00100_00100_00100_00100_00100;
   "U":glyph=35'b10001_10001_10001_10001_10001_10001_01110;
   "W":glyph=35'b10001_10001_10001_10101_10101_11011_10001;
   "X":glyph=35'b10001_10001_01010_00100_01010_10001_10001;
   ":":glyph=35'b00000_00100_00100_00000_00100_00100_00000;
   ".":glyph=35'b00000_00000_00000_00000_00000_00100_00100;
   ">":glyph=35'b10000_01000_00100_00010_00100_01000_10000;
   "+":glyph=35'b00000_00100_00100_11111_00100_00100_00000;
   "-":glyph=35'b00000_00000_00000_11111_00000_00000_00000;
   default:glyph=0;
  endcase end
 endfunction
 reg [47:0] rgb1;reg de1,hs1,vs1;
 reg [7:0] char0,char1;reg [2:0] gx0,gx1,gy0,gy1;
 reg box0,box1,highlight0,highlight1;
 reg [9:0] dx;reg [7:0] dy;reg [4:0] col;reg [3:0] row;
 // The first stage calculates cell and character; the second draws the glyph.
 always @(posedge clk)begin
  if(rst)begin
   rgb1<=0;de1<=0;hs1<=0;vs1<=0;out_rgb<=0;out_de<=0;out_hs<=0;out_vs<=0;
   char0<=32;char1<=32;gx0<=0;gx1<=0;gy0<=0;gy1<=0;
   box0<=0;box1<=0;highlight0<=0;highlight1<=0;
  end else begin
   rgb1<=in_rgb;de1<=in_de;hs1<=in_hs;vs1<=in_vs;
   box0<=in_de && px>=32 && px<536 && py>=32 && py<224;
   box1<=in_de && px+1>=32 && px+1<536 && py>=32 && py<224;
   dx=(px>=32 && px<536)?px-32:0;dy=(py>=32 && py<224)?py-32:0;col=dx/18;row=dy/24;
   char0<=character(row,col);gx0<=(dx%18)/3;gy0<=(dy%24)/3;
   highlight0<=mode==2 && ((row==1&&channel==0)||(row==2&&channel==2)||(row==3&&channel==1)||(row==4&&channel==3));
   dx=(px+1>=32 && px+1<536)?px+1-32:0;col=dx/18;
   char1<=character(row,col);gx1<=(dx%18)/3;gy1<=(dy%24)/3;
   highlight1<=mode==2 && ((row==1&&channel==0)||(row==2&&channel==2)||(row==3&&channel==1)||(row==4&&channel==3));
   out_rgb<={draw(rgb1[47:24],box1,char1,gx1,gy1,highlight1),draw(rgb1[23:0],box0,char0,gx0,gy0,highlight0)};
   out_de<=de1;out_hs<=hs1;out_vs<=vs1;
  end
 end
 function [23:0] draw(input [23:0] pixel,input box,input [7:0] c,input [2:0] gx,gy,input highlight);
  reg [34:0] bits;
  begin bits=glyph(c);
   if(!box)draw=pixel;
   else if(gx<5 && gy<7 && bits[(6-gy)*5+4-gx])draw=highlight?24'hffff00:24'hffffff;
   else draw={2'b00,pixel[23:18],2'b00,pixel[15:10],2'b00,pixel[7:2]};
  end
 endfunction
endmodule
