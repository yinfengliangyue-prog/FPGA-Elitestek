// Conservative shape checks on the SAME normalized edge input as the digit MLP.
// Codes: 10 +, 11 -, 12 x, 13 /, 15 unknown. This is not a trained operator model.
module expression_operator #(parameter PADDED_INPUT=1'b0)(
 input wire clk,rst_n,pixel_we,input wire [9:0] pixel_addr,input wire pixel_bit,
 input wire [7:0] x0,x1,y0,y1,output reg [3:0] symbol
);
 wire [4:0] x=pixel_addr%28,y=pixel_addr/28;
 wire signed [6:0] dx=$signed({2'b0,x})-7'sd14,dy=$signed({2'b0,y})-7'sd14;
 wire cross_hit=(x>=10&&x<=17)||(y>=10&&y<=17);
 wire main_hit=dx-dy>=-4&&dx-dy<=4;
 wire anti_hit=dx+dy>=-5&&dx+dy<=3;
 reg [8:0] total,cross_count,diag_count,main_count,anti_count;
 reg [7:0] left_arm,right_arm,top_arm,bottom_arm,tl,tr,bl,br;
 reg [7:0] padded_left,padded_right,padded_top,padded_bottom;
 wire [8:0] w={1'b0,x1}-{1'b0,x0}+1,h={1'b0,y1}-{1'b0,y0}+1;
 wire is_minus=w>=8&&w>=h*3;
 wire compact=w>=8&&h>=8&&w<=h*2&&h<=w*2;
 wire original_arms=left_arm>=2&&right_arm>=2&&top_arm>=2&&bottom_arm>=2;
 // A small crop border can move a narrow plus arm inward by one normalized
 // pixel. Only a pure cross may use that tolerance; keep the original rule
 // for all other shapes to avoid admitting more digit-like operators.
 wire padded_arms=PADDED_INPUT&&cross_count==total&&padded_left>=2&&padded_right>=2&&padded_top>=2&&padded_bottom>=2;
 wire is_plus=compact&&total>=12&&cross_count*4>=total*3&&(original_arms||padded_arms)&&diag_count*8<total*7;
 wire is_times=compact&&total>=12&&diag_count*4>=total*3&&tl>=2&&tr>=2&&bl>=2&&br>=2&&cross_count*8<total*7;
 wire is_slash=w>=6&&h>=8&&w*3>=h&&w<=h*2&&total>=8&&anti_count*4>=total*3&&main_count*2<total&&tr>=2&&bl>=2&&tl<2&&br<2;
 always @*begin
  symbol=15;
  case({is_minus,is_plus,is_times,is_slash})
   4'b1000:symbol=11;4'b0100:symbol=10;4'b0010:symbol=12;4'b0001:symbol=13;
   default:symbol=15;
  endcase
 end
 always @(posedge clk)begin
  if(!rst_n||(pixel_we&&pixel_addr==0))begin total<=0;cross_count<=0;diag_count<=0;main_count<=0;anti_count<=0;left_arm<=0;right_arm<=0;top_arm<=0;bottom_arm<=0;padded_left<=0;padded_right<=0;padded_top<=0;padded_bottom<=0;tl<=0;tr<=0;bl<=0;br<=0;end
  else if(pixel_we&&pixel_bit)begin
   total<=total+1'b1;
   if(cross_hit)cross_count<=cross_count+1'b1;
   if(main_hit||anti_hit)diag_count<=diag_count+1'b1;
   if(main_hit)main_count<=main_count+1'b1;
   if(anti_hit)anti_count<=anti_count+1'b1;
   if(x<=8&&y>=10&&y<=17)left_arm<=left_arm+1'b1;
   if(x>=19&&y>=10&&y<=17)right_arm<=right_arm+1'b1;
   if(y<=8&&x>=10&&x<=17)top_arm<=top_arm+1'b1;
   if(y>=19&&x>=10&&x<=17)bottom_arm<=bottom_arm+1'b1;
   if(x<=9&&y>=10&&y<=17)padded_left<=padded_left+1'b1;
   if(x>=18&&y>=10&&y<=17)padded_right<=padded_right+1'b1;
   if(y<=9&&x>=10&&x<=17)padded_top<=padded_top+1'b1;
   if(y>=18&&x>=10&&x<=17)padded_bottom<=padded_bottom+1'b1;
   if(x<=10&&y<=10)tl<=tl+1'b1;
   if(x>=17&&y<=10)tr<=tr+1'b1;
   if(x<=10&&y>=17)bl<=bl+1'b1;
   if(x>=17&&y>=17)br<=br+1'b1;
  end
 end
endmodule
