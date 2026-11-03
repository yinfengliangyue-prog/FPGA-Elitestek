`timescale 1ns/1ps
module tb_config52;
reg clk=0;always #5 clk=~clk;reg rn=0,t=0,review=0;reg [3:0] cmd=0;wire [7:0] h,l;
replay_config52 dut(clk,rn,t,cmd,review,h,l);
task event_key(input [3:0] action);begin @(negedge clk);cmd=action;t=~t;repeat(3)@(negedge clk);end endtask
integer i;
initial begin
 repeat(4)@(negedge clk);rn=1;repeat(3)@(negedge clk);
 if(h!=6 || l!=3)$fatal(1,"H6/L3 defaults");
 for(i=0;i<10;i++)event_key(2);if(h!=1 || l!=1)$fatal(1,"lower clamp / L<=H");
 for(i=0;i<260;i++)event_key(4);if(h!=255 || l!=3)$fatal(1,"upper clamp");
 review=1;for(i=0;i<20;i++)event_key(2);if(h!=255)$fatal(1,"review step changed detector");
 review=0;for(i=0;i<16;i++)if(i!=2&&i!=4)event_key(i[3:0]);
 if(h!=255)$fatal(1,"reserved action changed threshold");
 rn=0;@(negedge clk);rn=1;repeat(3)@(negedge clk);if(h!=6 || l!=3)$fatal(1,"reset defaults");
 $display("PASS CONFIG52 LIVE manual H 1..255, default/reset H6/L3, L<=H, review and reserved-action isolation");$finish;
end
endmodule
