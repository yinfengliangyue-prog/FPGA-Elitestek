// One immutable take: 120 history frames + three live buffers. Only successful
// complete AXI writes become visible. Review never writes a history slot.
module replay_control52 #(
 parameter FRAMES=120,BASE=32'h00c00000,STRIDE=32'h001fb000,MS_CYCLES=100000
)(
 input wire clk,rst_n,command_toggle,input wire [3:0] command,
 input wire boundary,reader_busy,writer_busy,writer_begin,commit,
 output wire [31:0] write_addr,output wire allow_start,
 output reg [31:0] addr_a,addr_b,output reg [95:0] ui_data,
 output wire ready,output wire fetch_start,output reg acknowledge,
 output wire recording_out,selected_out,
 output reg [7:0] display_bank_a,display_bank_b,
 output wire [7:0] write_bank_out,output wire review_out
);
 (* async_reg="true" *)reg [1:0] cmd_sync;
 reg cmd_seen,restart_pending;
 reg [1:0] page,speed,mode_a,mode_b;
 reg selected,recording,playing,half_phase;
 reg [7:0] count,index_a,index_b,play_index,threshold_a,threshold_b;
 reg [7:0] latest_bank,inflight_bank;
 reg latest_valid,inflight_history;
 reg [15:0] stamps[0:FRAMES-1];
 reg [15:0] milliseconds;reg [$clog2(MS_CYCLES+1)-1:0] ms_counter;
 reg [7:0] live_candidate,candidate,chosen_a,chosen_b,shown_a,shown_b;
 reg live_free;reg [15:0] delta;integer k;
 wire event_cmd=cmd_sync[1]!=cmd_seen;
 wire accepted=boundary && !reader_busy && latest_valid && !restart_pending;
 assign fetch_start=accepted;
 function [31:0] address(input [7:0] bank);address=BASE+bank*STRIDE;endfunction
 function [7:0] move_index(input [7:0] old,input forward);
  reg [8:0] sum;
  begin
   sum={1'b0,old}+1'b1;
   if(count==0)move_index=0;
   else if(forward)move_index=sum>=count ? count-1'b1 : sum[7:0];
   else move_index=old==0 ? 0 : old-1'b1;
  end
 endfunction
 always @* begin
  live_candidate=FRAMES;live_free=0;
  for(k=FRAMES+2;k>=FRAMES;k=k-1)
   if((!latest_valid || latest_bank!=k) &&
      (!reader_busy || (display_bank_a!=k && display_bank_b!=k))) begin
    live_candidate=k;live_free=1;
   end
  candidate=recording && count<FRAMES ? count : live_candidate;
  chosen_a=latest_bank;chosen_b=latest_bank;shown_a=0;shown_b=0;delta=0;
  if(page==1 && count!=0)begin chosen_b=play_index;shown_b=play_index+1'b1;end
  if(page==2 && count!=0)begin
   chosen_a=index_a;chosen_b=index_b;shown_a=index_a+1'b1;shown_b=index_b+1'b1;
   delta=index_a>index_b ? stamps[index_a]-stamps[index_b] : stamps[index_b]-stamps[index_a];
  end
 end
 assign write_addr=address(candidate);assign write_bank_out=candidate;
 assign allow_start=!restart_pending && (recording || live_free) &&
   (!reader_busy || (candidate!=display_bank_a && candidate!=display_bank_b)) &&
   (!latest_valid || candidate!=latest_bank);
 assign ready=latest_valid;assign recording_out=recording;assign selected_out=selected;
 assign review_out=page!=0;
 always @(posedge clk) begin
  if(!rst_n)begin
   cmd_sync<=0;cmd_seen<=0;restart_pending<=0;page<=0;speed<=1;
   selected<=1;recording<=1;playing<=0;half_phase<=0;
   mode_a<=0;mode_b<=2;threshold_a<=6;threshold_b<=3;
   count<=0;index_a<=0;index_b<=0;play_index<=0;
   latest_valid<=0;latest_bank<=FRAMES;inflight_bank<=0;inflight_history<=0;
   display_bank_a<=FRAMES;display_bank_b<=FRAMES;addr_a<=BASE;addr_b<=BASE;
   acknowledge<=0;ui_data<=0;milliseconds<=0;ms_counter<=0;
  end else begin
   cmd_sync<={cmd_sync[0],command_toggle};
   if(ms_counter==MS_CYCLES-1)begin ms_counter<=0;milliseconds<=milliseconds+1'b1;end
   else ms_counter<=ms_counter+1'b1;
   if(writer_begin)begin inflight_bank<=candidate;inflight_history<=recording && count<FRAMES;end
   if(commit)begin
    latest_bank<=inflight_bank;latest_valid<=1;
    if(inflight_history)begin
     stamps[inflight_bank]<=milliseconds;count<=count+1'b1;
     if(count==FRAMES-1)recording<=0;
    end
   end
   if(accepted)begin
    addr_a<=address(chosen_a);addr_b<=address(chosen_b);
    display_bank_a<=chosen_a;display_bank_b<=chosen_b;acknowledge<=~acknowledge;
    // 29 reserved + 67 documented status bits; held for this entire fetch.
    ui_data<={29'd0,page,selected,recording,playing,speed,count,shown_a,shown_b,
              mode_a,mode_b,threshold_a,threshold_b,delta};
    if(page==1 && playing && count!=0)begin
     half_phase<=~half_phase;
     if(speed!=0 || half_phase)begin
      if({1'b0,play_index}+(speed==2?9'd2:9'd1)>=count)play_index<=0;
      else play_index<=play_index+(speed==2?8'd2:8'd1);
     end
    end
   end
   if(event_cmd)begin
    cmd_seen<=cmd_sync[1];
    case(command)
     4'b0001:begin
      page<=page==2?0:page+1'b1;playing<=0;half_phase<=0;
      if(page==0)begin recording<=0;play_index<=0;mode_a<=0;mode_b<=0;end
      if(page==1)begin index_a<=0;index_b<=count==0?0:count-1'b1;mode_a<=2;mode_b<=2;end
      if(page==2)begin mode_a<=0;mode_b<=2;end
     end
     4'b0010,4'b0100:begin
      playing<=0;
      if(page==1)play_index<=move_index(play_index,command[2]);
      if(page==2)begin
       if(selected)index_b<=move_index(index_b,command[2]);
       else index_a<=move_index(index_a,command[2]);
      end
     end
     4'b1000:begin
      if(page==0)begin recording<=0;page<=1;playing<=0;play_index<=0;mode_a<=0;mode_b<=0;end
      if(page==1 && count!=0)playing<=~playing;
      if(page==2)selected<=~selected;
     end
     4'b0011:if(page==1)begin speed<=speed==2?0:speed+1'b1;half_phase<=0;end
     4'b0110:begin
      if(page==2 && !selected)mode_a<=mode_a==2?0:mode_a+1'b1;
      else mode_b<=mode_b==2?0:mode_b+1'b1;
     end
     4'b1001:restart_pending<=1;
     default:begin end
    endcase
   end
   // Drain any write before restarting. Invalidate old display eligibility;
   // active reads remain protected until their FIFO has fetched the old frame.
   if(restart_pending && !writer_busy && !reader_busy && !commit && !writer_begin)begin
    restart_pending<=0;count<=0;recording<=1;latest_valid<=0;page<=0;
    playing<=0;play_index<=0;index_a<=0;index_b<=0;mode_a<=0;mode_b<=2;
   end
  end
 end
 // synthesis translate_off
 initial begin
  if(FRAMES>120 || FRAMES<2 || BASE+STRIDE*(FRAMES+3)>32'h10000000)
   $fatal(1,"Replay memory exceeds physical 256MiB DDR");
 end
 always @(posedge clk)if(rst_n)begin
  if(count>FRAMES)$fatal(1,"History count overflow");
  if(writer_begin && reader_busy && (candidate==display_bank_a || candidate==display_bank_b))
   $fatal(1,"Writer reserved an active reader slot");
 end
 // synthesis translate_on
endmodule
