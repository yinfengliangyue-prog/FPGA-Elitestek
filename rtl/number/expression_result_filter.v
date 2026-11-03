// Three consecutive WHOLE expressions, with a stable box for EVERY symbol.
// A conflicting or invalid observation hides the previous answer immediately.
module expression_result_filter(
 input wire clk,rst_n,enable,observation,valid,input wire [39:0] tokens,
 input wire [159:0] boxes,input wire [2:0] count,
 output reg updated,confirmed
);
 reg [39:0] previous;reg [159:0] previous_boxes;reg [2:0] previous_count;
 reg [1:0] repeats;reg same;integer i,j;
 always @*begin
  same=tokens==previous&&count==previous_count;
  for(integer k=0;k<5;k=k+1)if(k<count)for(integer l=0;l<4;l=l+1)begin
   if({1'b0,boxes[k*32+l*8+:8]}+9'd8<{1'b0,previous_boxes[k*32+l*8+:8]}||{1'b0,previous_boxes[k*32+l*8+:8]}+9'd8<{1'b0,boxes[k*32+l*8+:8]})same=0;
  end
 end
 always @(posedge clk)begin
  if(!rst_n)begin updated<=0;confirmed<=0;previous<={40{1'b1}};previous_boxes<=0;previous_count<=0;repeats<=0;end
  else begin
   updated<=0;
   if(!enable)begin confirmed<=0;repeats<=0;end
   else if(observation)begin
    updated<=1;previous<=tokens;previous_boxes<=boxes;previous_count<=count;
    if(!valid)begin confirmed<=0;repeats<=0;end
    else if(!same)begin confirmed<=0;repeats<=1;end
    else begin if(repeats<3)repeats<=repeats+1'b1;confirmed<=repeats>=2;end
   end
  end
 end
endmodule
