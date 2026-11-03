// Text only: incoming red-edge pixels pass through outside the status HUD.
module final_shape_overlay #(
 parameter integer LOCK_SUPPORT=0,IMG_W=1920,IMG_H=1080,TEXT_SCALE=2
)(
 input wire clk,rst_n,enable,input wire lock_request,output reg locked,input wire [47:0] rgb_in,
 input wire de,valid,vs,input wire result_ready,input wire [2:0] pending_types,
 output wire result_ack,output wire [47:0] rgb_out,
 output wire enabled_frame,detected_frame,output reg [2:0] visible_types
);
 reg vs_d,de_d,on_frame;reg [11:0] x,y;
 wire [11:0] px=de_d?x:12'd0;
 wire sof=vs_d&&!vs;
 wire holding=LOCK_SUPPORT&&lock_request&&(locked||(|visible_types));
 assign result_ack=sof&&enable&&result_ready&&!holding;
 assign enabled_frame=on_frame;
 assign detected_frame=on_frame&&|visible_types;
 always @(posedge clk) begin
  if(!rst_n) begin vs_d<=0;de_d<=0;on_frame<=0;x<=0;y<=0;visible_types<=0;locked<=0;end
  else begin
   vs_d<=vs;de_d<=de;
   if(sof) begin
    x<=0;y<=0;on_frame<=enable;
    locked<=enable&&holding;
    if(!enable)visible_types<=0;
    else if(result_ready&&!holding)visible_types<=pending_types;
   end else if(de&&valid) x<=px+2;
   else if(de_d&&!de) begin x<=0;y<=y+1'b1;end
  end
 end
 function [34:0] glyph;
  input [7:0] c;
  begin case(c)
   "C":glyph=35'b01111_10000_10000_10000_10000_10000_01111;
   "E":glyph=35'b11111_10000_10000_11110_10000_10000_11111;
   "I":glyph=35'b11111_00100_00100_00100_00100_00100_11111;
   "L":glyph=35'b10000_10000_10000_10000_10000_10000_11111;
   "N":glyph=35'b10001_11001_11001_10101_10011_10011_10001;
   "O":glyph=35'b01110_10001_10001_10001_10001_10001_01110;
   "R":glyph=35'b11110_10001_10001_11110_10100_10010_10001;
   "S":glyph=35'b01111_10000_10000_01110_00001_00001_11110;
   "T":glyph=35'b11111_00100_00100_00100_00100_00100_00100;
   "Y":glyph=35'b10001_10001_01010_00100_00100_00100_00100;
   default:glyph=0;
  endcase end
 endfunction
 function [23:0] paint;
  input [23:0] p;input [11:0] xx,yy;
  reg [79:0] label;reg [34:0] bits;reg ink;
  integer row,tx,ty,ci,cc;
  begin
   paint=p;label=0;bits=0;ink=0;row=0;tx=0;ty=0;ci=0;cc=0;
   if(on_frame&&de&&valid&&xx>=300&&xx<300+60*TEXT_SCALE&&yy>=32&&yy<32+30*TEXT_SCALE) begin
    row=(yy-32)/(10*TEXT_SCALE);tx=(xx-300)/TEXT_SCALE;ty=((yy-32)/TEXT_SCALE)%10;
    case(row)
     0:label=visible_types[0]?"RECT   YES":"RECT   NO ";
     1:label=visible_types[1]?"CIRCLE YES":"CIRCLE NO ";
     default:label=visible_types[2]?"TRI    YES":"TRI    NO ";
    endcase
    ci=tx/6;cc=tx%6;bits=glyph(label[79-ci*8 -:8]);
    if(ty>=1&&ty<=7&&cc<5) ink=bits[34-(ty-1)*5-cc];
    paint=ink?24'hffffff:24'h000000;
   end
  end
 endfunction
 assign rgb_out={paint(rgb_in[47:24],px+12'd1,y),paint(rgb_in[23:0],px,y)};
endmodule
