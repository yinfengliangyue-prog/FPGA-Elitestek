`timescale 1ns/1ps
module tb_expression_engine;
 reg clk=0;always #5 clk=~clk;
 reg rst_n=0,en=1,ss=0,sd=0,blank=0,ts=0,nd=0;
 reg [2:0] ti=0,n=3;reg [3:0] digit=0,ops=15;reg signed [31:0] margin=900;
 reg [7:0] x0=10,x1=20,y0=30,y1=60;
 wire busy,done,valid,dz,neg;wire [39:0] tokens;wire [159:0] boxes;wire [2:0] count;
 wire [13:0] mag;wire [6:0] remn;wire [3:0] op;
 expression_engine dut(.clk(clk),.rst_n(rst_n),.enable(en),.sequence_start(ss),.sequence_done(sd),.blank(blank),.token_start(ts),.nn_done(nd),.token_index(ti),.token_count(n),.digit(digit),.operator_symbol(ops),.margin(margin),.x0(x0),.x1(x1),.y0(y0),.y1(y1),.busy(busy),.done(done),.valid(valid),.divide_zero(dz),.negative(neg),.tokens(tokens),.boxes(boxes),.count(count),.magnitude(mag),.remainder(remn),.operation(op));
 integer a,b,operator_code,expected,checks=0,pos,len,oppos,t;
 task token;input integer idx,d,o;begin
  @(negedge clk);ti=idx;digit=d;ops=o;x0=10+idx*30;x1=x0+20;ts=1;
  @(negedge clk);ts=0;nd=1;@(negedge clk);nd=0;
 end endtask
 task begin_seq;begin @(negedge clk);ss=1;@(negedge clk);ss=0;end endtask
 task finish_seq;begin
  @(negedge clk);sd=1;@(negedge clk);sd=0;t=0;
  while(!done&&t<130)begin @(negedge clk);t=t+1;end
  if(!done)$fatal(1,"arithmetic timeout");
 end endtask
 initial begin
  repeat(4)@(negedge clk);rst_n=1;
  for(operator_code=10;operator_code<=13;operator_code=operator_code+1)
   for(a=0;a<100;a=a+1)for(b=0;b<100;b=b+1)begin
    n=(a>=10?2:1)+(b>=10?2:1)+1;begin_seq;pos=0;
    if(a>=10)begin token(pos,a/10,15);pos=pos+1;end
    token(pos,a%10,15);pos=pos+1;oppos=pos;
    token(pos,8,operator_code);pos=pos+1;
    if(b>=10)begin token(pos,b/10,15);pos=pos+1;end
    token(pos,b%10,15);finish_seq;
    if(!valid||dz!==(operator_code==13&&b==0)||op!==operator_code)$fatal(1,"grammar a=%0d op=%0d b=%0d",a,operator_code,b);
    case(operator_code)10:expected=a+b;11:expected=a>=b?a-b:b-a;12:expected=a*b;13:expected=b==0?0:a/b;endcase
    if(mag!==expected||neg!==(operator_code==11&&a<b)||remn!==((operator_code==13&&b!=0)?a%b:0))$fatal(1,"arithmetic %0d op%0d %0d got %0d neg%0d rem%0d",a,operator_code,b,mag,neg,remn);
    if(tokens[oppos*8+:8]!==operator_code||count!==n)$fatal(1,"token publication");
    checks=checks+1;
   end
  n=3;begin_seq;token(0,2,15);token(1,3,15);token(2,4,15);finish_seq;if(valid)$fatal(1,"missing operator accepted");
  begin_seq;token(0,2,15);token(1,3,10);margin=299;token(2,4,15);margin=900;finish_seq;if(valid)$fatal(1,"weak digit accepted");
  begin_seq;token(0,2,15);token(1,3,10);y0=100;y1=130;token(2,4,15);y0=30;y1=60;finish_seq;if(valid)$fatal(1,"multiple lines accepted");
  n=4;begin_seq;token(0,1,15);token(1,2,10);token(2,3,11);token(3,4,15);finish_seq;if(valid)$fatal(1,"ambiguous parse accepted");
  @(negedge clk);blank=1;@(negedge clk);blank=0;if(!done||valid||count!=0)$fatal(1,"blank did not clear");
  $display("PASS EXPRESSION_ENGINE: %0d exhaustive arithmetic expressions incl negative/zero/div0/remainder, weak digit, multiline, unknown and ambiguous operators",checks);$finish;
 end
 initial begin #500000000;$fatal(1,"timeout");end
endmodule
