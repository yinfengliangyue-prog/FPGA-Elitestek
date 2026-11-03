// Keep the verified SW0 pin. Short release: OFF -> NUMBER -> EXPR -> OFF.
// Long release (one second): request result lock/unlock in EXPR mode.
module expression_key_control #(
 parameter integer DEBOUNCE_CYCLES=1400000,LONG_CYCLES=70000000
)(input wire clk,rst_n,key_n,inhibit,output wire enabled,output wire expression_mode,output reg lock_pulse);
 (* ASYNC_REG="TRUE" *) reg [1:0] key_sync;
 localparam CW=$clog2(DEBOUNCE_CYCLES+1),LW=$clog2(LONG_CYCLES+1);
 reg [CW-1:0] debounce;reg [LW-1:0] held;
 reg candidate,stable,armed,pressed,cancelled;reg [1:0] mode;
 assign enabled=mode!=0;assign expression_mode=mode==2;
 always @(posedge clk)begin
  if(!rst_n)begin key_sync<=3;debounce<=0;held<=0;candidate<=1;stable<=1;armed<=0;pressed<=0;cancelled<=0;mode<=0;lock_pulse<=0;end
  else begin
   key_sync<={key_sync[0],key_n};lock_pulse<=0;
   if(pressed&&held<LONG_CYCLES)held<=held+1'b1;
   if(key_sync[1]!=candidate)begin candidate<=key_sync[1];debounce<=0;end
   else if(debounce<DEBOUNCE_CYCLES)begin
    debounce<=debounce+1'b1;
    if(debounce==DEBOUNCE_CYCLES-1)begin
     stable<=candidate;
     if(!candidate&&stable&&armed)begin pressed<=1;held<=0;cancelled<=inhibit;end
     if(candidate)begin
      armed<=1;pressed<=0;cancelled<=0;
      if(pressed&&!cancelled&&!inhibit)begin
       if(held>=LONG_CYCLES)begin if(mode==2)lock_pulse<=1;end
       else mode<=mode==2?0:mode+1'b1;
      end
     end
    end
   end
   // Once another key joins SW0, cancel that whole SW0 gesture.
   // This survives staggered release; only a later standalone press can act.
   if(inhibit)begin cancelled<=1;pressed<=0;held<=0;lock_pulse<=0;end
  end
 end
endmodule

