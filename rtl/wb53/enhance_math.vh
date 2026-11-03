// Functions local to the including module. Widen before shifts and additions.
function [7:0] luminance;
 input [23:0] rgb;reg [15:0] r,g,b,sum;
 begin
  r={8'd0,rgb[23:16]};g={8'd0,rgb[15:8]};b={8'd0,rgb[7:0]};
  sum=(r<<6)+(r<<3)+(r<<2)+r+(g<<7)+(g<<4)+(g<<2)+(g<<1)
     +(b<<4)+(b<<3)+(b<<2)+b+16'd128;
  luminance=sum[15:8];
 end
endfunction
function [7:0] clip8;
 input integer value;
 begin
  if(value<0)clip8=0;else if(value>255)clip8=255;else clip8=value[7:0];
 end
endfunction
