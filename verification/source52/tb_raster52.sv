`timescale 1ns/1ps
module tb_raster52;
reg clk=0;always #6.734 clk=~clk;
reg rst=0,ack=0,empty=0;wire ft,reset,pop,de,hs,vs,underflow;wire [47:0] rgb;
reg [95:0] ui={29'd0,2'd2,1'b0,1'b0,1'b0,2'd1,8'd120,8'd100,8'd120,2'd0,2'd0,8'd2,8'd2,16'd1990};
replay_raster52 #(.W(64),.H(64),.HT(48),.VT(72),.HB(6),.VB(4),.HS(2),.VS(2)) dut(
 clk,rst,1'b1,ack,ui,ft,reset,empty,{4{{8'd7,1'b0,8'h12,8'h34,7'h2b}}},pop,rgb,de,hs,vs,underflow,8'd6,8'd3);
reg seen=0;integer ackdelay=0,frames=0;bit injected=0,recovered=0,starved=0;
always @(negedge clk)if(rst)begin
 if(ft!=seen)begin seen=ft;ackdelay=40;frames++;end
 if(ackdelay>0)begin ackdelay--;if(ackdelay==0)ack=~ack;end
 if(frames==2 && dut.image_area && dut.xbeat==10 && !injected)begin empty=1;injected=1;end
 else empty=0;
 if(injected && underflow)starved=1;
 if(starved && frames>=3 && dut.image_area && rgb==48'h123456123456)recovered=1;
end
initial begin
 repeat(8)@(negedge clk);rst=1;wait(frames==2);repeat(80)@(negedge clk);
 if(dut.decimal_bcd[0]!=20'h00120 || dut.decimal_bcd[1]!=20'h00100 || dut.decimal_bcd[2]!=20'h00120 || dut.decimal_bcd[3]!=20'h01990)$fatal(1,"serial decimal / timestamp");
 if(dut.character(3,2)!="F" || dut.character(3,6)!="E" || dut.character(3,8)!="1" || dut.character(3,9)!="0" || dut.character(3,10)!="0")$fatal(1,"label character placement");
 ui={29'd0,2'd0,1'b0,1'b0,1'b0,2'd1,8'd120,8'd0,8'd0,2'd0,2'd2,8'd2,8'd2,16'd0};
 wait(frames==4);repeat(80)@(negedge clk);
 if(dut.character(7,0)!="H" || dut.character(7,1)!="O")$fatal(1,"LIVE shortcut prefix truncated");
 if(dut.decimal_bcd[4]!=20'h00006 || dut.decimal_bcd[5]!=20'h00003)$fatal(1,"LIVE H6/L3 decimal");
 if(dut.character(5,39)!="H" || dut.character(5,42)!="6" || dut.character(5,44)!="L" || dut.character(5,47)!="3")$fatal(1,"LIVE H/L label placement");
 if(dut.mode_char(0,0)!="A" || dut.mode_char(0,5)!="W" || dut.mode_char(1,0)!="R" || dut.mode_char(2,0)!="B")$fatal(1,"AUTO WB/RED/BAL labels");
 if(!injected || !starved || !recovered)$fatal(1,"starvation frame drop/recovery");
 $display("PASS RASTER52 decimal 120/100/120/1990ms, label placement, underflow blanks remainder, next-frame recovery");$finish;
end
initial begin #1000000;$fatal(1,"timeout");end
endmodule
