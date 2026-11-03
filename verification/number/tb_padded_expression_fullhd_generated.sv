`timescale 1ns/1ps
module tb_expression_fullhd;
 reg clk=0;always #5 clk=~clk;
 reg rst_n=0,de=0,valid=0,hs=0,vs=0;reg [47:0] rgb=0;
 wire [47:0] out_rgb;wire od,ov,oh,os,on_frame,detected;
 number_video_pipeline dut(.clk(clk),.rst_n(rst_n),.enable(1'b1),.expression_mode(1'b1),.lock_pulse(1'b0),.rgb_in(rgb),.de_in(de),.valid_in(valid),.hs_in(hs),.vs_in(vs),.threshold_in(8'd2),.rgb_out(out_rgb),.de_out(od),.valid_out(ov),.hs_out(oh),.vs_out(os),.enabled_frame(on_frame),.detected_frame(detected),.ui_expression_locked());
 reg [7:0] images[0:1920*1080-1],expected[0:5*784-1],boxes[0:19];
 integer x,y,f,i,checks=0,starts=0,observations=0,hd_pixels=0,fd;
 reg capture=0;
 always @(posedge clk)if(rst_n)begin
  if(dut.we)begin
   if(dut.bit_in!==(expected[dut.token_index*784+dut.addr]!=0))$fatal(1,"HD normalization token%0d addr%0d",dut.token_index,dut.addr);checks=checks+1;
  end
  if(dut.start)begin i=dut.token_index*4;if({dut.sel_x0,dut.sel_x1,dut.sel_y0,dut.sel_y1}!=={boxes[i],boxes[i+1],boxes[i+2],boxes[i+3]})$fatal(1,"HD bbox");starts=starts+1;end
  if(dut.expr_done)observations=observations+1;
  if(capture&&od&&ov)begin
   $fwrite(fd,"%06x\n%06x\n",out_rgb[23:0],out_rgb[47:24]);hd_pixels=hd_pixels+2;
  end
 end
 function [23:0] pixel;input integer xx,yy;reg [7:0] v;begin v=images[yy*1920+xx];pixel={v,v,v};end endfunction
 task frame;begin
  @(negedge clk);de=0;valid=0;vs=1;repeat(5)@(negedge clk);vs=0;repeat(5)@(negedge clk);
  for(y=0;y<1080;y=y+1)begin
   for(x=0;x<1920;x=x+2)begin @(negedge clk);de=1;valid=1;rgb={pixel(x+1,y),pixel(x,y)};end
   @(negedge clk);de=0;valid=0;hs=1;repeat(105)@(negedge clk);hs=0;
  end
  repeat(42000)@(negedge clk);
 end endtask
 initial begin
  $readmemh("verification/number/expression_hd_images.mem",images);$readmemh("verification/number/expression_hd_padding_expected.mem",expected);$readmemh("verification/number/expression_hd_boxes.mem",boxes);
  repeat(5)@(negedge clk);rst_n=1;
  for(f=0;f<14&&(f<4||!dut.expr_confirmed_frame);f=f+1)frame;
  if(!dut.expr_confirmed_frame||dut.expression_hud.text_frame!=="12+34=46                        ")$fatal(1,"full-HD expression not confirmed");
  fd=$fopen("verification/number/expression_padding_fullhd_pixels.hex","w");capture=1;frame;capture=0;$fclose(fd);
  if(hd_pixels!=1920*1080||checks<3*5*784||starts<15||observations<3)$fatal(1,"HD incomplete coverage or frame %0d",hd_pixels);
  $display("PASS EXPRESSION_FULLHD: production 1920x1080 2ppc, 768-square search, %0d normalized bits, %0d symbols, %0d whole expressions, %0d OSD output pixels",checks,starts,observations,hd_pixels);$finish;
 end
 initial begin #300000000;$fatal(1,"timeout");end
endmodule
