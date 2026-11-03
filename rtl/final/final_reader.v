
// Fetch each thumbnail row in screen order: left object row, right object row.
// DDR holds a dense stream of 48-bit records; video consumes two decoded64-bit records.
// Abort drains an already offered/accepted AXI burst before freeing the next frame.
module final_reader #(
 parameter W=1920,H=1080, FIFO_DEPTH=1024, BURST=127
)(
 input wire clk,rst_n,start,swap_sides,fullscreen,selected_b,
 input wire [31:0] addr_a,addr_b,
 output wire busy,
 input wire video_clk,fifo_reset,pop,
 output wire empty,
 output wire [127:0] head,
 output reg fault,
 output reg [31:0] araddr,
 output wire [7:0] arlen,
 output wire arvalid,
 input wire arready,
 input wire [127:0] rdata,
 input wire [1:0] rresp,
 input wire rvalid,rlast,
 output wire rready,
 input wire abort
);
 localparam ROW_WORDS=3*W/16, ROW_BYTES=W*3, ROWS=H/2, CW=$clog2(FIFO_DEPTH);
 localparam IDLE=0,RESET_WAIT=1,SPACE=2,ADDR=3,DATA=4;
 reg [2:0] state;
 reg [6:0] reset_count;
 reg [11:0] row;
 reg side;
 reg [31:0] left_base,right_base;
 reg [15:0] row_left;
 reg [8:0] words,received;
 reg [15:0] next_words;
 wire [CW:0] usedw;
 wire full,raw_empty,raw_pop;
 wire [127:0] raw_head;
 reg cancel_pending;
 wire cancel_now=cancel_pending||(abort===1'b1);
 reg [1:0] pair_phase;
 reg [95:0] tail;
 wire [95:0] pair_bits=pair_phase==0?raw_head[127:32]:
   pair_phase==1?{tail[31:0],raw_head[127:64]}:
   pair_phase==2?{tail[63:0],raw_head[127:96]}:tail;
 assign head={16'd0,pair_bits[95:48],16'd0,pair_bits[47:0]};
 assign empty=pair_phase==3?1'b0:raw_empty;
 assign raw_pop=pop&&!empty&&pair_phase!=3;
 always @(posedge video_clk or negedge rst_n)begin
  if(!rst_n)begin pair_phase<=0;tail<=0;end
  else if(fifo_reset)begin pair_phase<=0;tail<=0;end
  else if(pop&&!empty)begin
   pair_phase<=pair_phase+1'b1;
   case(pair_phase)
    0:tail<={64'd0,raw_head[31:0]};
    1:tail<={32'd0,raw_head[63:0]};
    2:tail<=raw_head[95:0];
   endcase
  end
 end
 wire [12:0] to_4k=(13'd4096-{1'b0,araddr[11:0]}) >> 4;
 always @* begin
   next_words=row_left;
   if(next_words>BURST+1) next_words=BURST+1;
   if(next_words>to_4k) next_words=to_4k;
 end
 always @(posedge clk or negedge rst_n) begin
   if(!rst_n) begin
     state<=IDLE;reset_count<=0;row<=0;side<=0;left_base<=0;right_base<=0;
     row_left<=0;words<=0;received<=0;araddr<=0;fault<=0;cancel_pending<=0;
   end else begin
     if(abort===1'b1)cancel_pending<=1;
     if(state==IDLE)cancel_pending<=0;
     case(state)
       IDLE: if(start&&!cancel_now) begin state<=RESET_WAIT;reset_count<=0;end
       RESET_WAIT: if(cancel_now)begin state<=IDLE;cancel_pending<=0;end else begin
         // Request was arbitrated by the pool on the start edge. Delay both
         // address capture and traffic until both FIFO clock domains reset.
         left_base<=fullscreen ? (selected_b?addr_b:addr_a) : (swap_sides ? addr_b : addr_a);
         right_base<=fullscreen ? (selected_b?addr_b:addr_a) : (swap_sides ? addr_a : addr_b);
         if(reset_count==63) begin
           araddr<=fullscreen ? (selected_b?addr_b:addr_a) : (swap_sides ? addr_b : addr_a);
           row<=0;side<=0;row_left<=ROW_WORDS;state<=SPACE;
         end else reset_count<=reset_count+1'b1;
       end
       SPACE: if(cancel_now)begin state<=IDLE;cancel_pending<=0;end else if(next_words!=0 && usedw+next_words+4<FIFO_DEPTH) begin
         words<=next_words[8:0];received<=0;state<=ADDR;
       end
       ADDR: if(arready) state<=DATA;
       DATA: if(rvalid && rready) begin
         received<=received+1'b1;
         if(rresp!=0 || rlast!=(received+1'b1==words)) fault<=1;
         if(rlast) begin
           if(cancel_now)begin state<=IDLE;cancel_pending<=0;end
           else if(row_left==words) begin
             row_left<=ROW_WORDS;
             if(!side) begin side<=1;araddr<=right_base+row*ROW_BYTES;state<=SPACE;end
             else if(row==ROWS-1) state<=IDLE;
             else begin
               row<=row+1'b1;side<=0;
               araddr<=left_base+(row+1'b1)*ROW_BYTES;state<=SPACE;
             end
           end else begin
             row_left<=row_left-words;araddr<=araddr+(words<<4);state<=SPACE;
           end
         end
       end
       default: state<=IDLE;
     endcase
   end
 end
 assign busy=state!=IDLE;
 assign arvalid=state==ADDR;assign arlen=words-1'b1;
 assign rready=state==DATA && (cancel_now||!full);
 DC_FIFO #(.FIFO_MODE("ShowAhead"),.DATA_WIDTH(128),.FIFO_DEPTH(FIFO_DEPTH)) fifo(
   .Reset(!rst_n || fifo_reset),.WrClk(clk),.WrEn(rvalid && rready && !cancel_now),
   .WrDNum(usedw),.WrFull(full),.WrData(rdata),
   .RdClk(video_clk),.RdEn(raw_pop),.RdDNum(),.RdEmpty(raw_empty),.RdData(raw_head),.DataVal());
endmodule
