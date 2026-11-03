`timescale 1ns/1ps
module tb_keys52;
reg clk=0;always #5 clk=~clk;
reg rst=0,scope=1;reg [3:0] keys=15;wire toggle;wire [3:0] code;
replay_keys52 #(.DEBOUNCE_CYCLES(4),.HOLD_CYCLES(40),.REPEAT_CYCLES(12)) dut(clk,rst,keys,scope,toggle,code);
integer events=0;reg seen=0;
always @(negedge clk)if(toggle!=seen)begin events++;seen=toggle;end
task press(input [3:0] mask,input integer expected);integer prior;begin
 prior=events;keys=~mask;repeat(16)@(negedge clk);
 if(events!=prior)$fatal(1,"gesture executed before release");
 keys=15;repeat(20)@(negedge clk);
 if(expected==0)begin if(events!=prior)$fatal(1,"reserved chord emitted action");end
 else if(events!=prior+1 || code!=expected)$fatal(1,"release gesture lost/duplicated");
end endtask
integer i,prior;
initial begin
 keys=7;repeat(5)@(negedge clk);rst=1;repeat(40)@(negedge clk);keys=15;repeat(20)@(negedge clk);
 if(events!=0)$fatal(1,"startup held key");
 keys=14;@(negedge clk);keys=15;repeat(20)@(negedge clk);
 if(events!=0)$fatal(1,"debounce");
 for(i=1;i<16;i++)press(i[3:0],(i==1||i==2||i==4||i==8||i==9)?i:0);
 prior=events;keys=~4'b1001;repeat(24)@(negedge clk);
 keys=~4'b1000;repeat(24)@(negedge clk);
 if(events!=prior)$fatal(1,"staggered chord release");
 keys=15;repeat(20)@(negedge clk);
 if(events!=prior+1 || code!=9)$fatal(1,"chord isolation");
 // Continuous frame steps, no extra release step and no +/-10 action.
 prior=events;keys=~4'b0010;repeat(100)@(negedge clk);
 if(events<prior+4 || code!=2)$fatal(1,"held previous did not repeat");
 prior=events;keys=15;repeat(20)@(negedge clk);if(events!=prior)$fatal(1,"hold release duplicated");
 keys=~4'b0100;repeat(100)@(negedge clk);
 if(events<prior+4 || code!=4)$fatal(1,"held next did not repeat");
 prior=events;keys=15;repeat(20)@(negedge clk);if(events!=prior)$fatal(1,"next release duplicated");
 keys=14;repeat(100)@(negedge clk);
 if(events!=prior+1 || code!=6)$fatal(1,"hold SW0 must change view once");
 prior=events;keys=15;repeat(20)@(negedge clk);if(events!=prior)$fatal(1,"hold SW0 also changed page");
 keys=7;repeat(100)@(negedge clk);
 if(events!=prior+1 || code!=3)$fatal(1,"hold SW3 must change speed once");
 prior=events;scope=0;repeat(20)@(negedge clk);scope=1;repeat(100)@(negedge clk);
 if(events!=prior)$fatal(1,"scope enter with key held");
 keys=15;repeat(20)@(negedge clk);press(4,4);
 prior=events;keys=13;repeat(60)@(negedge clk);scope=0;repeat(30)@(negedge clk);
 prior=events;keys=15;repeat(30)@(negedge clk);if(events!=prior)$fatal(1,"scope exit leaked release");
 $display("PASS KEYS52 all masks, 10 reserved chords, +/-1 hold repeat, no release duplicate, long view/speed, debounce/startup/scope isolation");$finish;
end
endmodule
