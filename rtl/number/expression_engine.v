// One line, 1-2 digits per unsigned operand, exactly one operator.
// Enumerate both possible operator positions; reject ambiguous parses.
// No labels are changed to make an expression legal.
module expression_engine #(parameter integer MARGIN_MIN=300)(
 input wire clk,rst_n,enable,sequence_start,sequence_done,blank,token_start,nn_done,
 input wire [2:0] token_index,token_count,input wire [3:0] digit,operator_symbol,
 input wire signed [31:0] margin,input wire [7:0] x0,x1,y0,y1,
 output wire busy,output reg done,valid,divide_zero,negative,
 output reg [39:0] tokens,output reg [159:0] boxes,output reg [2:0] count,
 output reg [13:0] magnitude,output reg [6:0] remainder,output reg [3:0] operation
);
 reg [3:0] digits[0:4],ops[0:4];reg good[0:4];
 reg [7:0] bx0[0:4],bx1[0:4],by0[0:4],by1[0:4];
 reg [2:0] state;reg [1:0] parse_count,position;reg [6:0] a,b;reg [3:0] op;
 reg [6:0] ca,cb;reg candidate_ok;reg [7:0] low_y,high_y;
 integer i,j;reg [3:0] d;
 assign busy=state!=0;
 // No variable divider: division uses bounded repeated subtraction (<=99 cycles).
 always @*begin
  ca=0;cb=0;candidate_ok=token_count>=3&&token_count<=5&&position>=1&&position<=2&&token_count-position-1>=1&&token_count-position-1<=2;
  low_y=0;high_y=255;d=15;
  for(integer k=0;k<5;k=k+1)if(k<token_count)begin
   if(k==position)begin
    if(ops[k]<10||ops[k]>13)candidate_ok=0;
   end else begin
    if(!good[k]||by1[k]-by0[k]+1<8)candidate_ok=0;
    if(by0[k]>low_y)low_y=by0[k];if(by1[k]<high_y)high_y=by1[k];
    if(k<position)ca=ca*10+digits[k];else cb=cb*10+digits[k];
   end
  end
  // Digits must share a vertical interval; the operator centre must be on that line.
  if(low_y>high_y)candidate_ok=0;
  if(position<5&&({1'b0,by0[position]}+{1'b0,by1[position]}<2*low_y||{1'b0,by0[position]}+{1'b0,by1[position]}>2*high_y))candidate_ok=0;
 end
 always @(posedge clk)begin
  if(!rst_n)begin
   state<=0;done<=0;valid<=0;divide_zero<=0;negative<=0;tokens<={40{1'b1}};boxes<=0;count<=0;magnitude<=0;remainder<=0;operation<=15;parse_count<=0;position<=1;a<=0;b<=0;op<=15;
   for(i=0;i<5;i=i+1)begin digits[i]<=15;ops[i]<=15;good[i]<=0;bx0[i]<=0;bx1[i]<=0;by0[i]<=0;by1[i]<=0;end
  end else begin
   done<=0;
   if(!enable)begin state<=0;valid<=0;end
   else if(blank)begin state<=0;valid<=0;divide_zero<=0;done<=1;tokens<={40{1'b1}};boxes<=0;count<=0;end
   else begin
    if(sequence_start)begin for(i=0;i<5;i=i+1)begin good[i]<=0;digits[i]<=15;ops[i]<=15;end end
    if(token_start&&token_index<5)begin bx0[token_index]<=x0;bx1[token_index]<=x1;by0[token_index]<=y0;by1[token_index]<=y1;end
    if(nn_done&&token_index<5)begin digits[token_index]<=digit;ops[token_index]<=operator_symbol;good[token_index]<=digit<10&&margin>=MARGIN_MIN;end
    case(state)
     0:if(sequence_done)begin state<=1;position<=1;parse_count<=0;valid<=0;divide_zero<=0;negative<=0;remainder<=0;end
     1:begin
      if(candidate_ok)begin parse_count<=parse_count+1'b1;a<=ca;b<=cb;op<=ops[position];
       for(j=0;j<5;j=j+1)begin
        tokens[j*8+:8]<=j<token_count?{4'd0,(j==position?ops[j]:digits[j])}:8'hff;
        boxes[j*32+:32]<={bx0[j],bx1[j],by0[j],by1[j]};
       end
      end
      if(position==2)state<=2;else position<=position+1'b1;
     end
     2:begin
      count<=token_count;operation<=op;
      if(parse_count!=1)begin valid<=0;tokens<={40{1'b1}};done<=1;state<=0;end
      else begin
       valid<=1;
       case(op)
        10:begin magnitude<={7'd0,a}+{7'd0,b};done<=1;state<=0;end
        11:begin magnitude<=a>=b?a-b:b-a;negative<=a<b;done<=1;state<=0;end
        12:begin magnitude<=a*b;done<=1;state<=0;end
        13:begin if(b==0)begin divide_zero<=1;magnitude<=0;remainder<=0;done<=1;state<=0;end else begin magnitude<=0;remainder<=a;state<=3;end end
        default:begin valid<=0;done<=1;state<=0;end
       endcase
      end
     end
     3:if(remainder>=b)begin remainder<=remainder-b;magnitude<=magnitude+1'b1;end else begin done<=1;state<=0;end
     default:state<=0;
    endcase
   end
  end
 end
endmodule

