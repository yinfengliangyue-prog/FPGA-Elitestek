
`timescale 1ns/1ps
// Keep ownership until last R handshake. Address latch follows bank arbitration
// by one clock; changing mode/freeze never stops the display timing generator.
module ddr_rd_buffer #(
    parameter AXI_DATA_WIDTH=128,AXI_ADDR_WIDTH=32,RD_FIFO_DEPTH=1024,BURST_LEN=127
)(
    input wire axi_clk,axi_clk_rst_n,start,
    input wire [AXI_ADDR_WIDTH-1:0] start_addr,
    input wire [24:0] burst_len,
    input wire bank_sw_ack,
    output reg bank_sw,
    output wire frame_busy,
    input wire rd_fifo_rdclk,rd_fifo_rst_p,
    output wire rd_fifo_rdvalid,
    output wire [AXI_DATA_WIDTH-1:0] rd_fifo_rddata,
    output wire rd_fifo_rdempty,
    input wire rd_fifo_rden,
    output wire [5:0] arid,
    output reg [AXI_ADDR_WIDTH-1:0] araddr,
    output wire [7:0] arlen,
    output wire [2:0] arsize,
    output wire [1:0] arburst,
    output wire arlock,arvalid,arapcmd,arqos,
    input wire arready,
    output wire [3:0] arcache,
    output wire [2:0] arprot,
    input wire [5:0] rid,
    input wire [AXI_DATA_WIDTH-1:0] rdata,
    input wire rlast,rvalid,
    output wire rready,
    input wire [1:0] rresp,
    output wire [31:0] wr_fifo_rd_data_test,
    output wire [7:0] test_BURST_LEN
);
    localparam SHIFT=$clog2(AXI_DATA_WIDTH/8),CW=$clog2(RD_FIFO_DEPTH);
    localparam IDLE=0,CAPTURE=1,SPACE=2,ADDR=3,DATA=4;
    reg [2:0] state;
    (* async_reg="true" *) reg start_meta,start_sync;
    reg start_d;
    wire new_frame=start_sync && !start_d;
    reg [24:0] remaining;
    reg [8:0] words;
    reg [24:0] next_words;
    wire [CW:0] usedw;
    wire full;
    wire [12:0] bytes_to_4k=13'd4096-{1'b0,araddr[11:0]};
    wire [12:0] words_to_4k=bytes_to_4k >> SHIFT;
    always @* begin
        next_words=remaining;
        if(next_words>BURST_LEN+1) next_words=BURST_LEN+1;
        if(next_words>words_to_4k) next_words=words_to_4k;
    end
    always @(posedge axi_clk or negedge axi_clk_rst_n) begin
        if(!axi_clk_rst_n) begin start_meta<=0;start_sync<=0;start_d<=0;end
        else begin start_meta<=start;start_sync<=start_meta;start_d<=start_sync;end
    end
    always @(posedge axi_clk or negedge axi_clk_rst_n) begin
        if(!axi_clk_rst_n) begin
            state<=IDLE;remaining<=0;araddr<=0;words<=0;bank_sw<=0;
        end else begin
            bank_sw<=0;
            case(state)
                IDLE: if(new_frame && burst_len!=0) state<=CAPTURE;
                CAPTURE: begin
                    araddr<=start_addr;remaining<=burst_len;state<=SPACE;
                end
                SPACE: if(usedw+next_words+4<RD_FIFO_DEPTH && next_words!=0) begin
                    words<=next_words[8:0];state<=ADDR;
                end
                ADDR: if(arready) state<=DATA;
                DATA: if(rvalid && rready && rlast) begin
                    if(remaining==words) begin state<=IDLE;bank_sw<=1;end
                    else begin
                        araddr<=araddr+(words << SHIFT);remaining<=remaining-words;state<=SPACE;
                    end
                end
                default: state<=IDLE;
            endcase
        end
    end
    assign frame_busy=state!=IDLE;
    assign arvalid=state==ADDR;
    assign rready=state==DATA && !full;
    assign arlen=words-1'b1;
    assign arsize=SHIFT;assign arid=0;assign arburst=1;
    assign arlock=0;assign arapcmd=0;assign arqos=0;assign arcache=3;assign arprot=2;
    DC_FIFO #(.FIFO_MODE("Normal"),.DATA_WIDTH(AXI_DATA_WIDTH),.FIFO_DEPTH(RD_FIFO_DEPTH)) u_rd_fifo(
        .Reset(!axi_clk_rst_n || rd_fifo_rst_p),.WrClk(axi_clk),
        .WrEn(rvalid && rready),.WrDNum(usedw),.WrFull(full),.WrData(rdata),
        .RdClk(rd_fifo_rdclk),.RdEn(rd_fifo_rden),.RdDNum(),
        .RdEmpty(rd_fifo_rdempty),.RdData(rd_fifo_rddata),.DataVal(rd_fifo_rdvalid));
    assign wr_fifo_rd_data_test=rd_fifo_rddata[31:0];
    assign test_BURST_LEN=BURST_LEN;
endmodule
