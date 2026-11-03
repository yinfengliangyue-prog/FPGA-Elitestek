// Two-second integer FPS meter. Counts the FIRST valid pixel following VS,
// not every VS pulse, and does not claim complete-frame/data integrity.
module fps_meter60 #(
 parameter integer REF_CLK_HZ=100000000,WINDOW_SECONDS=2
)(
 input wire ref_clk,cam_clk,vid_clk,rst_n,
 input wire cam_vs,cam_de,vid_vs,vid_de,
 output reg [9:0] fps_cam,fps_vid,output reg fps_valid
);
 localparam integer WINDOW=REF_CLK_HZ*WINDOW_SECONDS;
 localparam integer TW=$clog2(WINDOW)<1?1:$clog2(WINDOW);
 (* async_reg="true" *) reg [1:0] rr,cr,vr;
 always @(posedge ref_clk or negedge rst_n)if(!rst_n)rr<=0;else rr<={rr[0],1'b1};
 always @(posedge cam_clk or negedge rst_n)if(!rst_n)cr<=0;else cr<={cr[0],1'b1};
 always @(posedge vid_clk or negedge rst_n)if(!rst_n)vr<=0;else vr<={vr[0],1'b1};
 reg cam_old_vs,cam_pending,cam_toggle;
 reg vid_old_vs,vid_pending,vid_toggle;
 always @(posedge cam_clk or negedge cr[1])begin
  if(!cr[1])begin cam_old_vs<=0;cam_pending<=0;cam_toggle<=0;end
  else begin
   cam_old_vs<=cam_vs;
   if(cam_vs && !cam_old_vs)cam_pending<=1;
   if(cam_de && (cam_pending || (cam_vs && !cam_old_vs)))begin
    cam_toggle<=~cam_toggle;cam_pending<=0;
   end
  end
 end
 always @(posedge vid_clk or negedge vr[1])begin
  if(!vr[1])begin vid_old_vs<=0;vid_pending<=0;vid_toggle<=0;end
  else begin
   vid_old_vs<=vid_vs;
   if(vid_vs && !vid_old_vs)vid_pending<=1;
   if(vid_de && (vid_pending || (vid_vs && !vid_old_vs)))begin
    vid_toggle<=~vid_toggle;vid_pending<=0;
   end
  end
 end
 (* async_reg="true" *) reg cam_meta,cam_sync,vid_meta,vid_sync;
 reg cam_d,vid_d;
 wire cam_event=cam_sync^cam_d,vid_event=vid_sync^vid_d;
 reg [TW-1:0] ticks;
 reg [11:0] cam_count,vid_count;
 reg [20:0] published;
 reg request_toggle,ack_toggle;
 (* async_reg="true" *) reg ack_meta,ack_sync;
 function [9:0] integer_fps(input [12:0] n);
  integer rate;
  begin rate=(n+WINDOW_SECONDS/2)/WINDOW_SECONDS;
   integer_fps=rate>999?10'd999:rate[9:0];
  end
 endfunction
 always @(posedge ref_clk or negedge rr[1])begin
  if(!rr[1])begin
   cam_meta<=0;cam_sync<=0;cam_d<=0;vid_meta<=0;vid_sync<=0;vid_d<=0;
   ack_meta<=0;ack_sync<=0;ticks<=0;cam_count<=0;vid_count<=0;
   published<=0;request_toggle<=0;
  end else begin
   cam_meta<=cam_toggle;cam_sync<=cam_meta;cam_d<=cam_sync;
   vid_meta<=vid_toggle;vid_sync<=vid_meta;vid_d<=vid_sync;
   ack_meta<=ack_toggle;ack_sync<=ack_meta;
   if(ticks==WINDOW-1)begin
    ticks<=0;cam_count<=0;vid_count<=0;
    // Hold the bundled data until the video-domain acknowledgement returns.
    if(request_toggle==ack_sync)begin
     published<={1'b1,integer_fps({1'b0,cam_count}+cam_event),integer_fps({1'b0,vid_count}+vid_event)};
     request_toggle<=~request_toggle;
    end
   end else begin
    ticks<=ticks+1'b1;
    if(cam_event && cam_count<4095)cam_count<=cam_count+1'b1;
    if(vid_event && vid_count<4095)vid_count<=vid_count+1'b1;
   end
  end
 end
 (* async_reg="true" *) reg request_meta,request_sync;
 (* async_reg="true" *) reg [20:0] data_meta,data_sync;
 always @(posedge vid_clk or negedge vr[1])begin
  if(!vr[1])begin
   request_meta<=0;request_sync<=0;data_meta<=0;data_sync<=0;ack_toggle<=0;
   fps_cam<=0;fps_vid<=0;fps_valid<=0;
  end else begin
   request_meta<=request_toggle;request_sync<=request_meta;
   data_meta<=published;data_sync<=data_meta;
   if(request_sync!=ack_toggle)begin
    {fps_valid,fps_cam,fps_vid}<=data_sync;ack_toggle<=request_sync;
   end
  end
 end
endmodule
