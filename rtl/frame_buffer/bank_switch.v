
// Three exclusive owners: reader, writer, optional completed/pending frame.
// wr_sw is a one-cycle COMMIT after the final AXI B response, not WLAST intent.
// rd_sw is a one-cycle event at the NEXT display fetch boundary (before AR).
module bank_switch #(
    parameter FB_NUM=3, MAX_VID_WIDTH=1920, MAX_VID_HIGHT=1080,
    parameter START_ADDR=0, VID_DATA_WIDTH=16, AXI_DATA_WIDTH=128
)(
    input wire ddr_clk, rst_n, wr_sw, rd_sw, freeze_req,
    output reg [1:0] wr_bank, rd_bank,
    output wire rd_sw_ack, wr_sw_ack,
    output wire [31:0] rd_start_addr, wr_start_addr,
    output reg rd_valid, frozen
);
    localparam FRAME_LEN=MAX_VID_WIDTH*MAX_VID_HIGHT*VID_DATA_WIDTH/8+512;
    reg [1:0] pending_bank, nw, nr, np;
    reg pending_valid, nv, pv, nf;
    function [1:0] spare;
        input [1:0] a,b;
        begin
            if(a!=0 && b!=0) spare=0;
            else if(a!=1 && b!=1) spare=1;
            else spare=2;
        end
    endfunction
    function [31:0] address;
        input [1:0] bank;
        begin
            case(bank)
                0: address=START_ADDR;
                1: address=START_ADDR+FRAME_LEN;
                default: address=START_ADDR+2*FRAME_LEN;
            endcase
        end
    endfunction
    assign rd_start_addr=address(rd_bank);
    assign wr_start_addr=address(wr_bank);
    assign rd_sw_ack=rd_sw;
    assign wr_sw_ack=wr_sw;
    always @* begin
        nw=wr_bank; nr=rd_bank; np=pending_bank;
        nv=rd_valid; pv=pending_valid; nf=frozen;
        // Commit first: simultaneous read can consume this fully written frame.
        if(wr_sw) begin
            if(!rd_valid) begin
                nr=wr_bank;nv=1;
                nw=spare(wr_bank,wr_bank);pv=0;
            end else begin
                np=wr_bank;pv=1;
                // The old pending frame may be discarded; the reader is protected.
                nw=spare(rd_bank,wr_bank);
            end
        end
        if(rd_sw && nv) begin
            nf=freeze_req;
            if(!freeze_req && pv) begin
                nr=np;pv=0;
                // nw is already distinct from both old reader and pending.
            end
        end
    end
    always @(posedge ddr_clk or negedge rst_n) begin
        if(!rst_n) begin
            wr_bank<=0;rd_bank<=1;pending_bank<=2;
            pending_valid<=0;rd_valid<=0;frozen<=0;
        end else begin
            wr_bank<=nw;rd_bank<=nr;pending_bank<=np;
            pending_valid<=pv;rd_valid<=nv;frozen<=nf;
        end
    end
endmodule
