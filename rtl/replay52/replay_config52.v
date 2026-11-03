// Standalone manual H control reuses the otherwise idle LIVE SW1/SW2.
// In an integrated system replace this with the common video-domain H/L bus.
module replay_config52(
 input wire clk,rst_n,command_toggle,input wire [3:0] command,input wire review_active,
 output reg [7:0] high,output wire [7:0] low
);
 reg seen;
 assign low=high<3?high:8'd3;
 always @(posedge clk)begin
  if(!rst_n)begin high<=6;seen<=0;end
  else if(command_toggle!=seen)begin
   seen<=command_toggle;
   if(!review_active)begin
    if(command==2 && high>1)high<=high-1'b1;
    if(command==4 && high<255)high<=high+1'b1;
   end
  end
 end
endmodule
