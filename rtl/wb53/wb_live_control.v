// Events are debounced in this same clock domain. 0=AUTO,1=LOCK,2=MANUAL.
module wb_live_control #(parameter RGB_AUTO=0)(input clk,rst,sof,input [3:0] command,input command_valid,
 input [11:0] auto_r,auto_b,input rejected,
 output reg [1:0] mode,output reg [1:0] channel,
 output [11:0] gain_r,gain_g,gain_b,output hold_gain,output reg fine_step,input [11:0] auto_g);
 reg [11:0] manual_r,manual_g,manual_b;
 reg [11:0] applied_r,applied_g,applied_b;
 reg [1:0] brightness,preset;
 wire [11:0] base_r=mode==0?auto_r:manual_r;
 wire [11:0] base_g=mode==0?(RGB_AUTO?auto_g:12'd256):manual_g;
 wire [11:0] base_b=mode==0?auto_b:manual_b;
 function [11:0] lift;
  input [11:0] n;input [1:0] level;reg [13:0] value;
  begin value={2'b0,n}+(({2'b0,n}*level)>>2);lift=value>1024?12'd1024:value[11:0];end
 endfunction
 assign gain_r=lift(base_r,brightness);
 assign gain_g=lift(base_g,brightness);
 assign gain_b=lift(base_b,brightness);
 assign hold_gain=mode!=0;
 function [11:0] adjust;
  input [11:0] n;input up;reg [11:0] step;
  begin step=fine_step?12'd4:12'd32;
   if(up)adjust=n>=1024-step?1024:n+step;else adjust=n<=128+step?128:n-step;end
 endfunction
 always @(posedge clk)begin
  if(rst)begin
   mode<=0;channel<=0;brightness<=0;preset<=0;fine_step<=0;
   manual_r<=256;manual_g<=256;manual_b<=256;
   applied_r<=256;applied_g<=256;applied_b<=256;
  end else begin
   // Mirror the gains actually sampled by both color lanes at their SOF.
   if(sof)begin applied_r<=gain_r;applied_g<=gain_g;applied_b<=gain_b;end
   if(command_valid)case(command)
    4'b0001:begin
     if(mode==0)begin
      mode<=1;manual_r<=sof?gain_r:applied_r;manual_g<=sof?gain_g:applied_g;manual_b<=sof?gain_b:applied_b;brightness<=0;
     end else if(mode==1)mode<=2;
     else begin mode<=0;brightness<=0;end
    end
    4'b1100:fine_step<=~fine_step; // SW3+SW2: coarse 32/256 or fine 4/256.
    4'b1000:channel<=channel+1'b1;
    4'b0010,4'b0100:begin
     // Edits require MANUAL; LOCK remains immutable.
     if(mode==2)case(channel)
      0:manual_r<=adjust(manual_r,command==2);
      1:manual_b<=adjust(manual_b,command==2);
      2:manual_g<=adjust(manual_g,command==2);
      3:if(command==2)begin if(brightness<3)brightness<=brightness+1'b1;end
        else if(brightness>0)brightness<=brightness-1'b1;
     endcase
    end
    4'b1010:begin
     // Illustrative starting points, not sensor colorimetric calibration.
     mode<=2;brightness<=0;preset<=preset+1'b1;channel<=2;
     case(preset)
      0:begin manual_r<=320;manual_g<=256;manual_b<=320;end
      1:begin manual_r<=384;manual_g<=256;manual_b<=384;end
      2:begin manual_r<=320;manual_g<=320;manual_b<=320;channel<=3;end
      3:begin manual_r<=256;manual_g<=256;manual_b<=256;end
     endcase
    end
    4'b1001:begin mode<=0;channel<=0;brightness<=0;preset<=0;fine_step<=0;end
    default:begin end
   endcase
  end
 end
endmodule
