
// Serialized AXI writer: one AW/W/B transaction outstanding. Publish only after
// every expected word and the final B handshake. No early last-burst bank switch.
module replay_writer52 #(
    parameter AXI_DATA_WIDTH=128, AXI_ADDR_WIDTH=32, WR_FIFO_DEPTH=1024,
    parameter AXI_STRB_WIDTH=AXI_DATA_WIDTH/8, BURST_LEN=127
)(
    input wire axi_clk,rst_n,wr_start,allow_start,
    output wire busy,begin_frame,output reg fault,
    input wire [AXI_ADDR_WIDTH-1:0] start_addr,
    input wire [24:0] total_burst_len,
    input wire bank_sw_ack,
    output reg bank_sw,
    output reg [7:0] test_cnt,
    input wire wr_fifo_rst_p,wr_fifo_wrclk,wr_fifo_wren,
    output wire wr_fifo_wrfull,
    input wire [AXI_DATA_WIDTH-1:0] wr_fifo_wrdata,
    output wire [5:0] awid,
    output reg [AXI_ADDR_WIDTH-1:0] awaddr,
    output wire [7:0] awlen,
    output wire [2:0] awsize,
    output wire [1:0] awburst,
    output wire awlock,
    output wire awvalid,awcobuf,awapcmd,awallstrb,awqos,
    output wire [3:0] awcache,
    output wire [2:0] awprot,
    input wire awready,
    output wire [AXI_DATA_WIDTH-1:0] wdata,
    output wire [AXI_STRB_WIDTH-1:0] wstrb,
    output wire wlast,wvalid,
    input wire wready,
    input wire [5:0] bid,
    input wire bvalid,
    input wire [1:0] bresp,
    output wire bready,
    output wire [33:0] addr_width_test,
    output wire [7:0] test_BURST_LEN
);
    localparam SHIFT=$clog2(AXI_STRB_WIDTH), CW=$clog2(WR_FIFO_DEPTH);
    localparam IDLE=0, WAIT_FIFO=1, ADDR=2, DATA=3, RESP=4;
    reg [2:0] state;
    (* async_reg="true" *) reg start_meta,start_sync;
    reg start_d;
    wire new_frame=start_sync && !start_d;
    assign busy=state!=IDLE;
    assign begin_frame=new_frame && state==IDLE && allow_start;
    reg [24:0] remaining;
    reg bad_frame;
    reg overflow_capture;
    (* async_reg="true" *) reg overflow_meta,overflow_sync;
    always @(posedge wr_fifo_wrclk or posedge wr_fifo_rst_p or negedge rst_n) begin
        if(!rst_n || wr_fifo_rst_p) overflow_capture<=0;
        else if(wr_fifo_wren && wr_fifo_wrfull) overflow_capture<=1;
    end
    always @(posedge axi_clk or negedge rst_n) begin
        if(!rst_n) begin overflow_meta<=0;overflow_sync<=0;end
        else begin overflow_meta<=overflow_capture;overflow_sync<=overflow_meta;end
    end
    reg [8:0] words, sent;
    wire [CW:0] usedw;
    wire [AXI_DATA_WIDTH-1:0] fifo_data;
    wire fifo_empty;
    wire pop=(state==ADDR && awready) ||
             (state==DATA && wready && !wlast);
    reg [24:0] next_words;
    wire [12:0] bytes_to_4k=13'd4096-{1'b0,awaddr[11:0]};
    wire [12:0] words_to_4k=bytes_to_4k >> SHIFT;
    always @* begin
        next_words=remaining;
        if(next_words>BURST_LEN+1) next_words=BURST_LEN+1;
        if(next_words>words_to_4k) next_words=words_to_4k;
    end
    DC_FIFO #(.FIFO_MODE("Normal"),.DATA_WIDTH(AXI_DATA_WIDTH),.FIFO_DEPTH(WR_FIFO_DEPTH)) u_wr_fifo(
        .Reset(wr_fifo_rst_p || !rst_n),.WrClk(wr_fifo_wrclk),.WrEn(wr_fifo_wren),
        .WrDNum(),.WrFull(wr_fifo_wrfull),.WrData(wr_fifo_wrdata),
        .RdClk(axi_clk),.RdEn(pop),.RdDNum(usedw),.RdEmpty(fifo_empty),.RdData(fifo_data),.DataVal());
    always @(posedge axi_clk or negedge rst_n) begin
        if(!rst_n) begin start_meta<=0;start_sync<=0;start_d<=0;end
        else begin start_meta<=wr_start;start_sync<=start_meta;start_d<=start_sync;end
    end
    always @(posedge axi_clk or negedge rst_n) begin
        if(!rst_n) begin
            state<=IDLE;remaining<=0;words<=0;sent<=0;awaddr<=0;
            bank_sw<=0;test_cnt<=0;bad_frame<=0;fault<=0;
        end else begin
            bank_sw<=0;
            if(new_frame && state!=IDLE)begin bad_frame<=1;fault<=1;end
            if(overflow_sync && state!=IDLE)begin bad_frame<=1;fault<=1;end
            case(state)
                IDLE: if(new_frame && allow_start && total_burst_len!=0) begin
                    awaddr<=start_addr;remaining<=total_burst_len;state<=WAIT_FIFO;bad_frame<=0;
                end
                WAIT_FIFO: if(new_frame || bad_frame) state<=IDLE;
                else if(usedw>=next_words && next_words!=0) begin
                    words<=next_words[8:0];sent<=0;state<=ADDR;
                end
                ADDR: if(awready) state<=DATA;
                DATA: if(wready) begin
                    if(wlast) state<=RESP;
                    else sent<=sent+1'b1;
                end
                RESP: if(bvalid) begin
                    if(bad_frame || new_frame || overflow_sync || bresp!=0)begin state<=IDLE;fault<=1;end
                    else if(remaining==words) begin
                        bank_sw<=1;state<=IDLE;test_cnt<=test_cnt+1'b1;
                    end else begin
                        remaining<=remaining-words;
                        awaddr<=awaddr+(words << SHIFT);state<=WAIT_FIFO;
                    end
                end
                default: state<=IDLE;
            endcase
        end
    end
    assign awvalid=state==ADDR;
    assign awlen=words-1'b1;
    assign wvalid=state==DATA;
    assign wlast=sent==words-1'b1;
    assign wdata=fifo_data;
    assign bready=state==RESP;
    assign awid=0;assign awsize=SHIFT;assign awburst=1;
    assign awlock=0;assign awcobuf=0;assign awapcmd=0;
    assign awallstrb=0;assign awqos=0;assign awcache=3;assign awprot=2;
    assign wstrb={AXI_STRB_WIDTH{1'b1}};
    assign addr_width_test=AXI_ADDR_WIDTH;assign test_BURST_LEN=BURST_LEN;
endmodule
