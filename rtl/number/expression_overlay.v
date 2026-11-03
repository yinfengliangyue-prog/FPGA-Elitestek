// Frame-atomic publication. A brief miss retains the last confirmed expression
// as WAIT LAST, never READY. The grace timer cannot be restarted by more misses.
// Lock retains the result while video remains live; unlock discards all history.
module expression_overlay #(
 parameter integer ROI_X=576,ROI_Y=156,ROI_SIZE=768,
 parameter PANEL_SWAP_RB=1'b1,
 parameter integer CLK_HZ=74250000,WAIT_MS=200,SLIM_OSD=0
)(
 input wire clk,rst_n,enable,sof,de,valid,input wire [11:0] px,y,
 input wire [47:0] rgb_in,input wire update,confirmed,candidate_valid,
 input wire [39:0] tokens,input wire [159:0] boxes,input wire [2:0] count,
 input wire [13:0] magnitude,input wire [6:0] remainder,
 input wire negative,divide_zero,input wire [3:0] operation,input wire lock_pulse,
 input wire [7:0] diag_noise,input wire [5:0] diag_candidates,
 input wire [2:0] diag_tokens,input wire [3:0] diag_reason,
 output wire [255:0] ui_text,output wire [159:0] ui_boxes,output wire [2:0] ui_count,output wire ui_holding,
 output reg pending,locked,output reg confirmed_frame,output wire [47:0] rgb_out
);
 reg lock_target,confirmed_pending;
 reg [159:0] boxes_pending,boxes_frame;reg [39:0] tokens_pending,tokens_frame;
 reg [2:0] count_pending,count_frame;
 reg [255:0] text_pending,text_frame;
 reg [255:0] diag_pending,diag_frame;
 localparam WAIT_CYCLES=(CLK_HZ/1000)*WAIT_MS;
 localparam TW=WAIT_CYCLES>1?$clog2(WAIT_CYCLES+1):1;
 reg [TW-1:0] wait_ticks;
 reg last_valid,waiting,holding_pending,holding_frame;
 reg [255:0] last_text;reg [159:0] last_boxes;reg [39:0] last_tokens;reg [2:0] last_count;
 reg same_last;
 always @*begin
  same_last=count==last_count&&tokens==last_tokens;
  for(integer k=0;k<5;k=k+1)if(k<count)for(integer j=0;j<4;j=j+1)begin
   if({1'b0,boxes[k*32+j*8+:8]}+9'd8<{1'b0,last_boxes[k*32+j*8+:8]}||
      {1'b0,last_boxes[k*32+j*8+:8]}+9'd8<{1'b0,boxes[k*32+j*8+:8]})same_last=0;
  end
 end
 assign ui_text=text_frame;assign ui_boxes=boxes_frame;assign ui_count=count_frame;assign ui_holding=holding_frame;
 wire fresh_confirmed=update&&candidate_valid&&confirmed;
 wire wait_expired=waiting&&wait_ticks>=WAIT_CYCLES-1&&!fresh_confirmed;
 wire may_hold=WAIT_MS>0&&last_valid&&(!candidate_valid||same_last)&&!(diag_reason>=1&&diag_reason<=4);
 wire publish_event=update||wait_expired;
 function [255:0] make_diag;
  input [2:0] nt;input [5:0] nc;input [7:0] nd;input [3:0] why;
  begin
   make_diag="TOK 0 CAND 00 DROP 00 CODE 0    ";
   make_diag[255-4*8-:8]=8'd48+nt;
   make_diag[255-11*8-:8]=8'd48+nc/10;
   make_diag[255-12*8-:8]=8'd48+nc%10;
   make_diag[255-19*8-:8]=8'd48+(nd>99?9:nd/10);
   make_diag[255-20*8-:8]=8'd48+(nd>99?9:nd%10);
   make_diag[255-27*8-:8]=8'd48+why;
  end
 endfunction
 function [7:0] symbol_char;input [7:0] s;begin
  case(s)10:symbol_char="+";11:symbol_char="-";12:symbol_char="X";13:symbol_char="/";default:symbol_char=s<10?8'd48+s:8'd63;endcase
 end endfunction
 function [255:0] make_text;
  input ok,stable,dz,neg;input [39:0] ts;input [2:0] n;
  input [13:0] mag;input [6:0] remn;input [3:0] op;
  integer j,pos;reg [7:0] c;reg leading;
  begin
   make_text={32{8'd32}};pos=0;leading=0;c=0;
   if(!ok)make_text[255-:48]="EXPR ?";
   else begin
    for(j=0;j<5;j=j+1)if(j<n)begin make_text[255-pos*8-:8]=symbol_char(ts[j*8+:8]);pos=pos+1;end
    make_text[255-pos*8-:8]="=";pos=pos+1;
    if(!stable)make_text[255-pos*8-:8]="?";
    else if(dz)make_text[255-pos*8-:32]="DIV0";
    else begin
     if(neg)begin make_text[255-pos*8-:8]="-";pos=pos+1;end
     if(mag>=1000)begin make_text[255-pos*8-:8]=48+mag/1000;pos=pos+1;end
     if(mag>=100)begin make_text[255-pos*8-:8]=48+(mag/100)%10;pos=pos+1;end
     if(mag>=10)begin make_text[255-pos*8-:8]=48+(mag/10)%10;pos=pos+1;end
     make_text[255-pos*8-:8]=48+mag%10;pos=pos+1;
     if(op==13&&remn!=0)begin
      make_text[255-pos*8-:16]=" R";pos=pos+2;
      if(remn>=10)begin make_text[255-pos*8-:8]=48+remn/10;pos=pos+1;end
      make_text[255-pos*8-:8]=48+remn%10;
     end
    end
   end
  end
 endfunction
 always @(posedge clk)begin
  if(!rst_n)begin pending<=0;locked<=0;lock_target<=0;confirmed_frame<=0;confirmed_pending<=0;boxes_pending<=0;boxes_frame<=0;tokens_pending<={40{1'b1}};tokens_frame<={40{1'b1}};count_pending<=0;count_frame<=0;text_pending<={32{8'd32}};text_frame<=make_text(0,0,0,0,0,0,0,0,0);diag_pending<=make_diag(0,0,0,0);diag_frame<=make_diag(0,0,0,0);last_valid<=0;waiting<=0;wait_ticks<=0;holding_pending<=0;holding_frame<=0;last_text<={32{8'd32}};last_boxes<=0;last_tokens<={40{1'b1}};last_count<=0;end
  else begin
   if(!enable)begin pending<=0;locked<=0;lock_target<=0;confirmed_frame<=0;count_frame<=0;text_frame<=make_text(0,0,0,0,0,0,0,0,0);diag_frame<=make_diag(0,0,0,0);last_valid<=0;waiting<=0;wait_ticks<=0;holding_pending<=0;holding_frame<=0;end
   else begin
    if(lock_pulse)begin if(locked)lock_target<=0;
     else if(confirmed_frame&&!holding_frame&&!waiting&&!(pending&&!confirmed_pending)&&!(update&&(!candidate_valid||!confirmed)))lock_target<=1;
    end
    if(waiting&&!locked&&!lock_target&&!fresh_confirmed&&!wait_expired)wait_ticks<=wait_ticks+1'b1;
    if(update&&!locked&&!lock_target)begin
     pending<=1;confirmed_pending<=candidate_valid&&confirmed;
     diag_pending<=make_diag(diag_tokens,diag_candidates,diag_noise,diag_reason);
     if(candidate_valid&&confirmed)begin
      holding_pending<=0;waiting<=0;wait_ticks<=0;last_valid<=1;
      boxes_pending<=boxes;tokens_pending<=tokens;count_pending<=count;
      text_pending<=make_text(1,1,divide_zero,negative,tokens,count,magnitude,remainder,operation);
      last_text<=make_text(1,1,divide_zero,negative,tokens,count,magnitude,remainder,operation);
      last_boxes<=boxes;last_tokens<=tokens;last_count<=count;
     end else if(may_hold&&!wait_expired)begin
      holding_pending<=1;boxes_pending<=last_boxes;tokens_pending<=last_tokens;count_pending<=last_count;text_pending<=last_text;
      if(!waiting)begin waiting<=1;wait_ticks<=0;end
     end else begin
      holding_pending<=0;last_valid<=0;waiting<=0;wait_ticks<=0;
      boxes_pending<=boxes;tokens_pending<=tokens;count_pending<=candidate_valid?count:0;
      text_pending<=make_text(candidate_valid,0,divide_zero,negative,tokens,count,magnitude,remainder,operation);
     end
    end
    if(wait_expired&&!locked&&!lock_target)begin
     last_valid<=0;waiting<=0;wait_ticks<=0;pending<=1;confirmed_pending<=0;holding_pending<=0;count_pending<=0;
     text_pending<=make_text(0,0,0,0,0,0,0,0,0);
    end
    if(sof)begin
     locked<=lock_target;
     if(locked&&!lock_target)begin pending<=0;confirmed_frame<=0;count_frame<=0;text_frame<=make_text(0,0,0,0,0,0,0,0,0);diag_frame<=make_diag(0,0,0,0);last_valid<=0;waiting<=0;wait_ticks<=0;holding_frame<=0;holding_pending<=0;end
     else if(lock_target)pending<=0;
     else if(pending)begin pending<=publish_event;confirmed_frame<=confirmed_pending;holding_frame<=holding_pending;boxes_frame<=boxes_pending;tokens_frame<=tokens_pending;count_frame<=count_pending;text_frame<=text_pending;diag_frame<=diag_pending;end
    end
   end
  end
 end
 function [34:0] glyph;input [7:0] c;begin case(c)
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
  "C":glyph=35'b01111_10000_10000_10000_10000_10000_01111;
  "D":glyph=35'b11110_10001_10001_10001_10001_10001_11110;
  "E":glyph=35'b11111_10000_10000_11110_10000_10000_11111;
  "H":glyph=35'b10001_10001_10001_11111_10001_10001_10001;
  "I":glyph=35'b11111_00100_00100_00100_00100_00100_11111;
  "K":glyph=35'b10001_10010_10100_11000_10100_10010_10001;
  "L":glyph=35'b10000_10000_10000_10000_10000_10000_11111;
  "M":glyph=35'b10001_11011_10101_10101_10001_10001_10001;
  "N":glyph=35'b10001_11001_11001_10101_10011_10011_10001;
  "O":glyph=35'b01110_10001_10001_10001_10001_10001_01110;
  "P":glyph=35'b11110_10001_10001_11110_10000_10000_10000;
  "R":glyph=35'b11110_10001_10001_11110_10100_10010_10001;
  "S":glyph=35'b01111_10000_10000_01110_00001_00001_11110;
  "T":glyph=35'b11111_00100_00100_00100_00100_00100_00100;
  "U":glyph=35'b10001_10001_10001_10001_10001_10001_01110;
  "V":glyph=35'b10001_10001_10001_10001_10001_01010_00100;
  "W":glyph=35'b10001_10001_10001_10101_10101_10101_01010;
  "X":glyph=35'b10001_10001_01010_00100_01010_10001_10001;
  "Y":glyph=35'b10001_10001_01010_00100_00100_00100_00100;
  "+":glyph=35'b00000_00100_00100_11111_00100_00100_00000;
  "-":glyph=35'b00000_00000_00000_11111_00000_00000_00000;
  "/":glyph=35'b00001_00010_00010_00100_01000_01000_10000;
  "=":glyph=35'b00000_11111_00000_00000_11111_00000_00000;
  "?":glyph=35'b01110_10001_00001_00010_00100_00000_00100;
  default:glyph=0;
 endcase end endfunction
 function [23:0] paint;input [23:0] p;input [11:0] xx,yy;
  reg [255:0] text;reg [34:0] bits;reg [31:0] box;integer i,bx0,bx1,by0,by1,tx,ty,ci,cc;reg hud;
  begin
   paint=p;text={32{8'd32}};bits=0;box=0;bx0=0;bx1=0;by0=0;by1=0;tx=0;ty=0;ci=0;cc=0;hud=0;
   if(enable&&de&&valid)begin
    if(xx>=ROI_X&&xx<ROI_X+ROI_SIZE&&yy>=ROI_Y&&yy<ROI_Y+ROI_SIZE&&(xx<ROI_X+2||xx>=ROI_X+ROI_SIZE-2||yy<ROI_Y+2||yy>=ROI_Y+ROI_SIZE-2))paint=24'hffffff;
    for(i=0;i<5;i=i+1)if(i<count_frame)begin
     box=boxes_frame[i*32+:32];bx0=ROI_X+box[31:24]*4;bx1=ROI_X+(box[23:16]+1)*4;by0=ROI_Y+box[15:8]*4;by1=ROI_Y+(box[7:0]+1)*4;
     if(xx>=bx0&&xx<bx1&&yy>=by0&&yy<by1&&(xx<bx0+2||xx>=bx1-2||yy<by0+2||yy>=by1-2))paint=confirmed_frame?24'h00ff00:(PANEL_SWAP_RB?24'h00ffff:24'hffff00);
    end
    if(!SLIM_OSD&&xx>=32&&xx<800&&yy>=32&&yy<64)begin
     text=locked?"EXPR LOCK READY                 ":(confirmed_frame?"EXPR LIVE READY                 ":(holding_frame?"EXPR LIVE WAIT LAST             ":"EXPR LIVE WAIT                  "));ty=(yy-32)/4;hud=1;
    end
    if(xx>=32&&xx<800&&yy>=(SLIM_OSD?180:80)&&yy<(SLIM_OSD?212:112))begin text=text_frame;ty=(yy-(SLIM_OSD?180:80))/4;hud=1;end
    if(!SLIM_OSD&&xx>=32&&xx<800&&yy>=120&&yy<152)begin text=diag_frame;ty=(yy-120)/4;hud=1;end
    if(!SLIM_OSD&&xx>=32&&xx<800&&yy>=1016&&yy<1048)begin text="SW0 MODE   HOLD 1S LOCK         ";ty=(yy-1016)/4;hud=1;end
    if(hud)begin tx=(xx-32)/4;ci=tx/6;cc=tx%6;bits=glyph(text[255-ci*8-:8]);paint=(ty<7&&cc<5&&bits[34-ty*5-cc])?24'hffffff:24'h000000;end
   end
  end
 endfunction
 assign rgb_out={paint(rgb_in[47:24],px+12'd1,y),paint(rgb_in[23:0],px,y)};
 // synthesis translate_off
 initial if(CLK_HZ<1000||WAIT_MS<0||WAIT_MS>1000)$fatal(1,"unsupported WAIT clock/duration");
 // synthesis translate_on
endmodule
