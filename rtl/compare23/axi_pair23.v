
// Two clients, round-robin arbitration per complete burst. AW/W/B and AR/R
// are separately locked until response completion. All clients use INCR/16 B.
module axi_pair23(
 input wire clk,rst_n,
 input wire [63:0] c_awaddr,c_araddr,
 input wire [15:0] c_awlen,c_arlen,
 input wire [1:0] c_awvalid,c_arvalid,c_wvalid,c_wlast,c_bready,c_rready,
 input wire [255:0] c_wdata,
 input wire [31:0] c_wstrb,
 output wire [1:0] c_awready,c_arready,c_wready,c_bvalid,c_rvalid,c_rlast,
 output wire [3:0] c_bresp,c_rresp,
 output wire [255:0] c_rdata,
 output wire [31:0] awaddr,araddr,
 output wire [7:0] awlen,arlen,
 output wire awvalid,arvalid,wvalid,wlast,bready,rready,
 output wire [127:0] wdata,
 output wire [15:0] wstrb,
 input wire awready,arready,wready,bvalid,rvalid,rlast,
 input wire [1:0] bresp,rresp,
 input wire [127:0] rdata
);
 reg w_busy,r_busy,w_owner,r_owner,w_turn,r_turn;
 // Remember an offered address while READY is low: other requests cannot
 // change the selected client or its address during an AXI VALID stall.
 reg w_offer,r_offer,w_pick,r_pick;
 wire wg=w_offer ? w_pick : (c_awvalid==3 ? w_turn : c_awvalid[1]);
 wire rg=r_offer ? r_pick : (c_arvalid==3 ? r_turn : c_arvalid[1]);
 assign awaddr=wg ? c_awaddr[63:32] : c_awaddr[31:0];
 assign awlen=wg ? c_awlen[15:8] : c_awlen[7:0];
 assign awvalid=!w_busy && c_awvalid[wg];
 assign c_awready={awready && awvalid && wg,awready && awvalid && !wg};
 assign wdata=w_owner ? c_wdata[255:128] : c_wdata[127:0];
 assign wstrb=w_owner ? c_wstrb[31:16] : c_wstrb[15:0];
 assign wvalid=w_busy && c_wvalid[w_owner];
 assign wlast=c_wlast[w_owner];
 assign c_wready={wready && w_busy && w_owner,wready && w_busy && !w_owner};
 assign c_bvalid={bvalid && w_busy && w_owner,bvalid && w_busy && !w_owner};
 assign c_bresp={bresp,bresp};
 assign bready=w_busy && c_bready[w_owner];
 assign araddr=rg ? c_araddr[63:32] : c_araddr[31:0];
 assign arlen=rg ? c_arlen[15:8] : c_arlen[7:0];
 assign arvalid=!r_busy && c_arvalid[rg];
 assign c_arready={arready && arvalid && rg,arready && arvalid && !rg};
 assign c_rdata={rdata,rdata};assign c_rresp={rresp,rresp};
 assign c_rvalid={rvalid && r_busy && r_owner,rvalid && r_busy && !r_owner};
 assign c_rlast={rlast,rlast};
 assign rready=r_busy && c_rready[r_owner];
 always @(posedge clk or negedge rst_n) begin
   if(!rst_n) begin
     w_busy<=0;r_busy<=0;w_owner<=0;r_owner<=0;w_turn<=0;r_turn<=0;
     w_offer<=0;r_offer<=0;w_pick<=0;r_pick<=0;
   end else begin
     if(awvalid) begin
       w_offer<=!awready;w_pick<=wg;
       if(awready) begin w_busy<=1;w_owner<=wg;end
     end
     if(bvalid && bready) begin w_busy<=0;w_turn<=~w_owner;end
     if(arvalid) begin
       r_offer<=!arready;r_pick<=rg;
       if(arready) begin r_busy<=1;r_owner<=rg;end
     end
     if(rvalid && rready && rlast) begin r_busy<=0;r_turn<=~r_owner;end
   end
 end
endmodule
