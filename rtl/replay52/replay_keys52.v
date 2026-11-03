// Semantic events, not raw chord masks. Hold SW0=VIEW, SW3=SPEED;
// SW1/SW2 repeat +/-1. Only SW0+SW3 is owned here; other chords are reserved.
// scope_enable is synchronous to clk. Scope changes cancel the active gesture.
module replay_keys52 #(
 parameter DEBOUNCE_CYCLES=1485000,HOLD_CYCLES=44550000,REPEAT_CYCLES=11137500
)(
 input wire clk,rst_n,input wire [3:0] key_n,input wire scope_enable,
 output reg command_toggle,output reg [3:0] command
);
 localparam CW=$clog2(DEBOUNCE_CYCLES+1),HW=$clog2(HOLD_CYCLES+1),RW=$clog2(REPEAT_CYCLES+1);
 (* async_reg="true" *) reg [3:0] key_meta,key_sync;
 reg [3:0] down,seen;reg [CW-1:0] counters[0:3];
 reg [CW-1:0] startup;reg ready,gesture,held;
 reg [HW-1:0] hold_count;reg [RW-1:0] repeat_count;integer k;
 task emit(input [3:0] action);begin command<=action;command_toggle<=~command_toggle;end endtask
 always @(posedge clk) begin
  if(!rst_n) begin
   key_meta<=15;key_sync<=15;down<=0;seen<=0;startup<=0;ready<=0;gesture<=0;
   held<=0;hold_count<=0;repeat_count<=0;command_toggle<=0;command<=0;
   for(k=0;k<4;k=k+1)counters[k]<=0;
  end else begin
   key_meta<=key_n;key_sync<=key_meta;
   for(k=0;k<4;k=k+1) begin
    if((~key_sync[k])==down[k])counters[k]<=0;
    else if(counters[k]==DEBOUNCE_CYCLES-1)begin down[k]<=~key_sync[k];counters[k]<=0;end
    else counters[k]<=counters[k]+1'b1;
   end
   if(!scope_enable)begin ready<=0;startup<=0;seen<=0;gesture<=0;held<=0;hold_count<=0;repeat_count<=0;end
   else if(!ready)begin
    if(key_sync!=15 || down!=0)startup<=0;
    else if(startup==DEBOUNCE_CYCLES-1)ready<=1;
    else startup<=startup+1'b1;
   end else if(down!=0)begin
    gesture<=1;seen<=seen|down;
    if(key_sync==~down && (seen==0 || seen==down) && (down==1 || down==2 || down==4 || down==8))begin
     if(!held)begin
      if(hold_count==HOLD_CYCLES-1)begin
       held<=1;repeat_count<=0;
       case(down)1:emit(6);2:emit(2);4:emit(4);8:emit(3);default:begin end endcase
      end else hold_count<=hold_count+1'b1;
     end else if(down==2 || down==4)begin
      if(repeat_count==REPEAT_CYCLES-1)begin repeat_count<=0;emit(down);end
      else repeat_count<=repeat_count+1'b1;
     end
    end else begin hold_count<=0;repeat_count<=0;end
   end else if(gesture)begin
    gesture<=0;seen<=0;hold_count<=0;repeat_count<=0;held<=0;
    if(!held)case(seen)1:emit(1);2:emit(2);4:emit(4);8:emit(8);9:emit(9);default:begin end endcase
   end
  end
 end
endmodule
