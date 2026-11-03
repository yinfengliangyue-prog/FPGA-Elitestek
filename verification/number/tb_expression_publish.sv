`timescale 1ns/1ps
module tb_expression_publish;
 reg clk=0;always #5 clk=~clk;
 reg rst_n=0,en=1,sof=0,update=0,confirmed=0,valid=1,lp=0;
 reg [39:0] tokens=40'hff_ff_03_0a_02;reg [159:0] boxes=160'h0;reg [2:0] n=3;
 reg [13:0] mag=5;reg [6:0] remn=0;reg neg=0,dz=0;reg [3:0] op=10;
 wire pending,locked,cf;wire [47:0] rgb;
 reg [5:0] candidates=5;reg [7:0] dropped=2;reg [3:0] reason=0;
 expression_overlay dut(.ui_text(),.ui_boxes(),.ui_count(),.ui_holding(),.clk(clk),.rst_n(rst_n),.enable(en),.sof(sof),.de(1'b0),.valid(1'b0),.px(12'd0),.y(12'd0),.rgb_in(48'd0),.update(update),.confirmed(confirmed),.candidate_valid(valid),.tokens(tokens),.boxes(boxes),.count(n),.magnitude(mag),.remainder(remn),.negative(neg),.divide_zero(dz),.operation(op),.lock_pulse(lp),.diag_candidates(candidates),.diag_noise(dropped),.diag_tokens(n),.diag_reason(reason),.pending(pending),.locked(locked),.confirmed_frame(cf),.rgb_out(rgb));
 task frame;begin @(negedge clk);sof=1;@(negedge clk);sof=0;end endtask
 task publish;begin @(negedge clk);update=1;@(negedge clk);update=0;end endtask
 task lock;begin @(negedge clk);lp=1;@(negedge clk);lp=0;frame;end endtask
 reg [255:0] oldtext,olddiag;reg [159:0] oldboxes;
 initial begin
  repeat(4)@(negedge clk);rst_n=1;
  lock;if(locked)$fatal(1,"unknown result locked");
  publish;oldtext=dut.text_frame;if(cf||dut.count_frame!=0)$fatal(1,"midframe text/box publication");frame;
  if(cf||dut.text_frame!=="2+3=?                           ")$fatal(1,"pending expression should have unknown answer");
  if(dut.diag_frame!=="TOK 3 CAND 05 DROP 02 CODE 0    ")$fatal(1,"diagnostic formatting or atomic publication");
  confirmed=1;boxes=160'h123456789a;publish;
  if(dut.text_frame!=="2+3=?                           "||dut.boxes_frame!=0)$fatal(1,"torn box/text publication");frame;
  if(!cf||dut.text_frame!=="2+3=5                           "||dut.boxes_frame!==boxes)$fatal(1,"confirmed publication");
  oldtext=dut.text_frame;oldboxes=dut.boxes_frame;olddiag=dut.diag_frame;lock;if(!locked)$fatal(1,"lock failed");
  tokens=40'hff_ff_07_0a_02;mag=9;dropped=9;reason=6;publish;frame;if(dut.text_frame!==oldtext||dut.boxes_frame!==oldboxes||dut.diag_frame!==olddiag)$fatal(1,"locked output changed");
  lock;if(locked||cf||dut.count_frame!=0)$fatal(1,"unlock did not clear");
  tokens=40'hff_ff_00_0d_07;dz=1;op=13;publish;frame;if(dut.text_frame!=="7/0=DIV0                        ")$fatal(1,"DIV0 text");
  en=0;frame;if(locked||cf||pending)$fatal(1,"OFF did not cancel");
  $display("PASS EXPRESSION_PUBLISH: pending vs confirmed, frame-atomic text+boxes, unknown lock rejected, lock isolation, unlock/OFF clearing, DIV0 formatting");$finish;
 end
endmodule
