// Five slots protect three independently retained timelines A/B/group plus latest.
// Independent timelines are suspended while the group mode is displayed.
module compare_pool23 #(parameter SLOT_COUNT=5,LIVE_VIEW_ENABLE=0,BASE=32'h02000000,STRIDE=32'h00200000)(
 input wire clk,rst_n,commit,display_boundary,capture_a,capture_b,live_b,
 input wire live_view,output wire [31:0] addr_view,output reg [2:0] bank_view,
 input wire live_a,live_group,capture_group,sync_mode,
 output wire [31:0] write_addr,addr_a,addr_b,addr_group,
 output reg ready,held_b,held_a,held_group,
 output reg [2:0] write_bank,bank_a,bank_b,bank_group,
 output reg [31:0] generation_a,generation_b,generation_group
);
 reg [2:0] latest,nw,na,nb,ng,nl,nv;
 assign addr_view=address(bank_view);
 reg [31:0] serial,latest_serial,ns,nls,nga,ngb,ngg;
 reg cap_a_seen,cap_b_seen,cap_group_seen,nseen_a,nseen_b,nseen_g,nready,nha,nhb,nhg;
 integer k;
 function [31:0] address(input [2:0] bank);begin address=BASE+bank*STRIDE;end endfunction
 assign write_addr=address(write_bank);assign addr_a=address(bank_a);
 assign addr_b=address(bank_b);assign addr_group=address(bank_group);
 always @* begin
  nv=bank_view;nw=write_bank;na=bank_a;nb=bank_b;ng=bank_group;nl=latest;
  ns=serial;nls=latest_serial;nga=generation_a;ngb=generation_b;ngg=generation_group;
  nready=ready;nha=held_a;nhb=held_b;nhg=held_group;
  nseen_a=cap_a_seen;nseen_b=cap_b_seen;nseen_g=cap_group_seen;
  if(commit) begin
   ns=serial+1;nl=write_bank;nls=ns;
   if(!ready) begin
    na=write_bank;nb=write_bank;ng=write_bank;nga=ns;ngb=ns;ngg=ns;nready=1;
   end
  end
  if(display_boundary && nready) begin
   if(LIVE_VIEW_ENABLE&&live_view)begin nv=nl;end
   else if(sync_mode) begin
    if(capture_group!=cap_group_seen) begin ng=nl;ngg=nls;nseen_g=capture_group;end
    else if(live_group) begin ng=nl;ngg=nls;end
    nhg=!live_group;
   end else begin
    if(capture_a!=cap_a_seen) begin na=nl;nga=nls;nseen_a=capture_a;end
    else if(live_a) begin na=nl;nga=nls;end
    if(capture_b!=cap_b_seen) begin nb=nl;ngb=nls;nseen_b=capture_b;end
    else if(live_b) begin nb=nl;ngb=nls;end
    nha=!live_a;nhb=!live_b;
   end
  end
  if(commit) begin
   for(k=SLOT_COUNT-1;k>=0;k=k-1) if(k!=na && k!=nb && k!=ng && k!=nl && (!LIVE_VIEW_ENABLE||k!=nv)) nw=k;
  end
 end
 always @(posedge clk or negedge rst_n) begin
  if(!rst_n) begin
   write_bank<=0;bank_view<=1;bank_a<=1;bank_b<=1;bank_group<=1;latest<=1;ready<=0;
   held_a<=0;held_b<=0;held_group<=0;serial<=0;latest_serial<=0;
   generation_a<=0;generation_b<=0;generation_group<=0;
   cap_a_seen<=0;cap_b_seen<=0;cap_group_seen<=0;
  end else begin
   write_bank<=nw;bank_view<=nv;bank_a<=na;bank_b<=nb;bank_group<=ng;latest<=nl;ready<=nready;
   held_a<=nha;held_b<=nhb;held_group<=nhg;serial<=ns;latest_serial<=nls;
   generation_a<=nga;generation_b<=ngb;generation_group<=ngg;
   cap_a_seen<=nseen_a;cap_b_seen<=nseen_b;cap_group_seen<=nseen_g;
  end
 end
endmodule
