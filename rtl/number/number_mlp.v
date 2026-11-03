`include "rtl/number/model_config.vh"
// 64 hidden neurons. Pack three signed 6-bit W1 weights per 18-bit ROM word.
// One shared multiplier, synchronous weight ROMs, bit-exact integer inference.
module number_mlp #(
 parameter B1_FILE="model/b1.mem",
 parameter W2_FILE="model/w2.mem",B2_FILE="model/b2.mem",
 parameter integer HIDDEN_SHIFT=`NUMBER_HIDDEN_SHIFT
)(
 input wire clk,rst_n,input wire pixel_we,input wire [9:0] pixel_addr,
 input wire pixel_bit,input wire start,
 output wire busy,output reg done,output reg [3:0] digit,
 output reg signed [31:0] margin,
 output reg score_valid,output reg [3:0] score_class,output reg signed [31:0] score_value
);
 reg [3:0] state;reg [14:0] wa;
 reg pixels[0:399];reg [7:0] hidden[0:63];
 reg [17:0] bank_word[0:16];reg [4:0] bank_sel;
 (* syn_romstyle = "block_ram" *) reg [17:0] w1_b00[0:511];
 initial $readmemh("model/w1_bank00.mem",w1_b00);
 always @(posedge clk)if(state==2&&wa[14:9]==0)bank_word[0]<=w1_b00[wa[8:0]];
 (* syn_romstyle = "block_ram" *) reg [17:0] w1_b01[0:511];
 initial $readmemh("model/w1_bank01.mem",w1_b01);
 always @(posedge clk)if(state==2&&wa[14:9]==1)bank_word[1]<=w1_b01[wa[8:0]];
 (* syn_romstyle = "block_ram" *) reg [17:0] w1_b02[0:511];
 initial $readmemh("model/w1_bank02.mem",w1_b02);
 always @(posedge clk)if(state==2&&wa[14:9]==2)bank_word[2]<=w1_b02[wa[8:0]];
 (* syn_romstyle = "block_ram" *) reg [17:0] w1_b03[0:511];
 initial $readmemh("model/w1_bank03.mem",w1_b03);
 always @(posedge clk)if(state==2&&wa[14:9]==3)bank_word[3]<=w1_b03[wa[8:0]];
 (* syn_romstyle = "block_ram" *) reg [17:0] w1_b04[0:511];
 initial $readmemh("model/w1_bank04.mem",w1_b04);
 always @(posedge clk)if(state==2&&wa[14:9]==4)bank_word[4]<=w1_b04[wa[8:0]];
 (* syn_romstyle = "block_ram" *) reg [17:0] w1_b05[0:511];
 initial $readmemh("model/w1_bank05.mem",w1_b05);
 always @(posedge clk)if(state==2&&wa[14:9]==5)bank_word[5]<=w1_b05[wa[8:0]];
 (* syn_romstyle = "block_ram" *) reg [17:0] w1_b06[0:511];
 initial $readmemh("model/w1_bank06.mem",w1_b06);
 always @(posedge clk)if(state==2&&wa[14:9]==6)bank_word[6]<=w1_b06[wa[8:0]];
 (* syn_romstyle = "block_ram" *) reg [17:0] w1_b07[0:511];
 initial $readmemh("model/w1_bank07.mem",w1_b07);
 always @(posedge clk)if(state==2&&wa[14:9]==7)bank_word[7]<=w1_b07[wa[8:0]];
 (* syn_romstyle = "block_ram" *) reg [17:0] w1_b08[0:511];
 initial $readmemh("model/w1_bank08.mem",w1_b08);
 always @(posedge clk)if(state==2&&wa[14:9]==8)bank_word[8]<=w1_b08[wa[8:0]];
 (* syn_romstyle = "block_ram" *) reg [17:0] w1_b09[0:511];
 initial $readmemh("model/w1_bank09.mem",w1_b09);
 always @(posedge clk)if(state==2&&wa[14:9]==9)bank_word[9]<=w1_b09[wa[8:0]];
 (* syn_romstyle = "block_ram" *) reg [17:0] w1_b10[0:511];
 initial $readmemh("model/w1_bank10.mem",w1_b10);
 always @(posedge clk)if(state==2&&wa[14:9]==10)bank_word[10]<=w1_b10[wa[8:0]];
 (* syn_romstyle = "block_ram" *) reg [17:0] w1_b11[0:511];
 initial $readmemh("model/w1_bank11.mem",w1_b11);
 always @(posedge clk)if(state==2&&wa[14:9]==11)bank_word[11]<=w1_b11[wa[8:0]];
 (* syn_romstyle = "block_ram" *) reg [17:0] w1_b12[0:511];
 initial $readmemh("model/w1_bank12.mem",w1_b12);
 always @(posedge clk)if(state==2&&wa[14:9]==12)bank_word[12]<=w1_b12[wa[8:0]];
 (* syn_romstyle = "block_ram" *) reg [17:0] w1_b13[0:511];
 initial $readmemh("model/w1_bank13.mem",w1_b13);
 always @(posedge clk)if(state==2&&wa[14:9]==13)bank_word[13]<=w1_b13[wa[8:0]];
 (* syn_romstyle = "block_ram" *) reg [17:0] w1_b14[0:511];
 initial $readmemh("model/w1_bank14.mem",w1_b14);
 always @(posedge clk)if(state==2&&wa[14:9]==14)bank_word[14]<=w1_b14[wa[8:0]];
 (* syn_romstyle = "block_ram" *) reg [17:0] w1_b15[0:511];
 initial $readmemh("model/w1_bank15.mem",w1_b15);
 always @(posedge clk)if(state==2&&wa[14:9]==15)bank_word[15]<=w1_b15[wa[8:0]];
 (* syn_romstyle = "block_ram" *) reg [17:0] w1_b16[0:511];
 initial $readmemh("model/w1_bank16.mem",w1_b16);
 always @(posedge clk)if(state==2&&wa[14:9]==16)bank_word[16]<=w1_b16[wa[8:0]];
 reg signed [7:0] w2[0:639];
 (* syn_romstyle="logic" *) reg signed [31:0] b1[0:63],b2[0:9];
 initial begin $readmemh(B1_FILE,b1);$readmemh(W2_FILE,w2);$readmemh(B2_FILE,b2);end
 localparam IDLE=0,INIT1=1,READ1=2,MAC1=3,END1=4,INIT2=5,READ2=6,MAC2=7,END2=8,FINISH=9,UNPACK1=10;
 reg [5:0] neuron;reg [9:0] idx;
 reg [9:0] wb;
 reg [1:0] lane;
 wire [17:0] packed_weight=bank_word[bank_sel];
 reg pb;reg signed [7:0] weight;reg [7:0] hv;
 reg signed [31:0] acc,best,second;
 wire signed [31:0] shifted=acc>>>HIDDEN_SHIFT;
 wire signed [16:0] product=$signed({1'b0,hv})*weight;
 assign busy=state!=IDLE;
 always @(posedge clk) begin
  if(pixel_we&&!busy&&pixel_addr%28>=4&&pixel_addr%28<24&&pixel_addr/28>=4&&pixel_addr/28<24)
   pixels[(pixel_addr/28-4)*20+(pixel_addr%28-4)]<=pixel_bit;
  if(!rst_n) begin state<=IDLE;done<=0;digit<=0;margin<=0;score_valid<=0;score_class<=0;score_value<=0;neuron<=0;idx<=0;wa<=0;wb<=0;lane<=0;bank_sel<=0;acc<=0;best<=0;second<=0;pb<=0;weight<=0;hv<=0;end
  else begin
   done<=0;score_valid<=0;
   case(state)
    IDLE:if(start) begin neuron<=0;wa<=0;lane<=0;state<=INIT1;end
    INIT1:begin acc<=b1[neuron];idx<=0;state<=READ1;end
    READ1:begin
     pb<=pixels[idx];bank_sel<=wa[14:9];state<=UNPACK1;
    end
    UNPACK1:begin
     case(lane)
      0:weight<={{2{packed_weight[5]}},packed_weight[5:0]};
      1:weight<={{2{packed_weight[11]}},packed_weight[11:6]};
      default:weight<={{2{packed_weight[17]}},packed_weight[17:12]};
     endcase
     state<=MAC1;
    end
    MAC1:begin
     acc<=acc+(pb?{{24{weight[7]}},weight}:32'sd0);
     if(lane==2)begin lane<=0;wa<=wa+1'b1;end else lane<=lane+1'b1;
     if(idx==399)state<=END1;else begin idx<=idx+1'b1;state<=READ1;end
    end
    END1:begin hidden[neuron]<=acc<=0?8'd0:(shifted>255?8'd255:shifted[7:0]);if(neuron==63)begin neuron<=0;wb<=0;best<=32'sh80000000;second<=32'sh80000000;state<=INIT2;end else begin neuron<=neuron+1'b1;state<=INIT1;end end
    INIT2:begin acc<=b2[neuron];idx<=0;state<=READ2;end
    READ2:begin hv<=hidden[idx[5:0]];weight<=w2[wb];state<=MAC2;end
    MAC2:begin acc<=acc+{{15{product[16]}},product};wb<=wb+1'b1;if(idx==63)state<=END2;else begin idx<=idx+1'b1;state<=READ2;end end
    END2:begin
     score_valid<=1;score_class<=neuron[3:0];score_value<=acc;
     if(acc>best)begin second<=best;best<=acc;digit<=neuron[3:0];end else if(acc>second)second<=acc;
     if(neuron==9)state<=FINISH;else begin neuron<=neuron+1'b1;state<=INIT2;end
    end
    FINISH:begin margin<=best-second;done<=1;state<=IDLE;end
    default:state<=IDLE;
   endcase
  end
 end
endmodule
