// Five observations: acquire 3 votes + repeated last label, switch 4 strong votes.
// Blank clears immediately. Four misses expire a previous result; no permanent hold.
module number_result_filter #(
 parameter integer MARGIN_MIN=300,STABLE_RESULTS=3,HOLD_ANALYSES=3,
 parameter integer SWITCH_MARGIN_MIN=600,SWITCH_VOTES=4
)(
 input wire clk,rst_n,enable,observation,blank,
 input wire [3:0] digit,input wire signed [31:0] margin,
 output reg updated,output reg [3:0] result
);
 reg [3:0] history[0:3];reg confident[0:3];reg [7:0] misses;
 integer j,votes,strong_votes;
 wire qualified=digit<10&&margin>=MARGIN_MIN;
 always @*begin
  votes=qualified?1:0;strong_votes=qualified&&margin>=SWITCH_MARGIN_MIN?1:0;
  for(integer k=0;k<4;k=k+1)if(qualified&&history[k]==digit)begin votes=votes+1;if(confident[k])strong_votes=strong_votes+1;end
 end
 always @(posedge clk)begin
  if(!rst_n)begin updated<=0;result<=15;misses<=0;for(j=0;j<4;j=j+1)begin history[j]<=15;confident[j]<=0;end end
  else begin
   updated<=0;
   if(!enable||blank)begin
    updated<=enable&&blank;result<=15;misses<=0;
    for(j=0;j<4;j=j+1)begin history[j]<=15;confident[j]<=0;end
   end else if(observation)begin
    updated<=1;
    for(j=3;j>0;j=j-1)begin history[j]<=history[j-1];confident[j]<=confident[j-1];end
    history[0]<=qualified?digit:4'd15;confident[0]<=qualified&&margin>=SWITCH_MARGIN_MIN;
    if(result==15)begin
     misses<=0;
     if(qualified&&history[0]==digit&&votes>=STABLE_RESULTS)result<=digit;
    end else if(qualified&&digit==result)misses<=0;
    else if(qualified&&history[0]==digit&&strong_votes>=SWITCH_VOTES)begin result<=digit;misses<=0;end
    else if(misses>=HOLD_ANALYSES)begin result<=15;misses<=0;end
    else misses<=misses+1;
   end
  end
 end
endmodule
