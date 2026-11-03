// Continuous raster gearbox. pixel_clk MUST be exactly 2 * pair_clk.
// Stores blank clocks as well as active pixels; no DE-dependent phase toggling.
// Gray pointers protect startup/reset phase; steady clocks remain STA-timed.
module hdmi_gearbox40 #(
    parameter AW=5,START_PAIRS=4
)(
    input pair_clk,pixel_clk,arst_n,
    input [47:0] rgb_pair,input de_pair,hs_pair,vs_pair,
    output reg [23:0] rgb,output reg de,hs,vs,output fault
);
    localparam PW=AW+1,DEPTH=1<<AW;
    reg [50:0] memory[0:DEPTH-1];
    (* async_reg="true" *) reg [1:0] pair_reset,pixel_reset;
    always @(posedge pair_clk or negedge arst_n)
        if(!arst_n)pair_reset<=0;else pair_reset<={pair_reset[0],1'b1};
    always @(posedge pixel_clk or negedge arst_n)
        if(!arst_n)pixel_reset<=0;else pixel_reset<={pixel_reset[0],1'b1};
    reg [PW-1:0] wbin,wgray,rbin,rgray;
    (* async_reg="true" *) reg [PW-1:0] rmeta,rsync,wmeta,wsync;
    reg write_fault,read_fault;
    (* async_reg="true" *) reg [1:0] write_fault_sync;
    wire full=wgray=={~rsync[PW-1:PW-2],rsync[PW-3:0]};
    wire empty=rgray==wsync;
    wire [PW-1:0] wnext=wbin+1'b1,rnext=rbin+1'b1;
    function [PW-1:0] ungray;
        input [PW-1:0] g;integer i;
        begin
            ungray[PW-1]=g[PW-1];
            for(i=PW-2;i>=0;i=i-1)ungray[i]=ungray[i+1]^g[i];
        end
    endfunction
    wire [PW-1:0] available=ungray(wsync)-rbin;
    always @(posedge pair_clk) begin
        if(!pair_reset[1])begin wbin<=0;wgray<=0;rmeta<=0;rsync<=0;write_fault<=0;end
        else begin
            rmeta<=rgray;rsync<=rmeta;
            if(!full)begin
                memory[wbin[AW-1:0]]<={rgb_pair,de_pair,hs_pair,vs_pair};
                wbin<=wnext;wgray<=wnext^(wnext>>1);
            end else write_fault<=1;
        end
    end
    reg started,upper;
    reg [26:0] held_upper;
    wire [50:0] front=memory[rbin[AW-1:0]];
    assign fault=read_fault | write_fault_sync[1];
    always @(posedge pixel_clk) begin
        if(!pixel_reset[1])begin
            rbin<=0;rgray<=0;wmeta<=0;wsync<=0;
            started<=0;upper<=0;held_upper<=0;read_fault<=0;write_fault_sync<=0;
            rgb<=0;de<=0;hs<=0;vs<=0;
        end else begin
            wmeta<=wgray;wsync<=wmeta;
            write_fault_sync<={write_fault_sync[0],write_fault};
            if(!started)begin
                rgb<=0;de<=0;hs<=0;vs<=0;
                if(available>=START_PAIRS)started<=1;
            end else if(upper)begin
                {rgb,de,hs,vs}<=held_upper;upper<=0;
            end else if(!empty)begin
                // Low 24 bits are the earlier pixel, high 24 bits the next pixel.
                {rgb,de,hs,vs}<={front[26:3],front[2:0]};
                held_upper<={front[50:27],front[2:0]};upper<=1;
                rbin<=rnext;rgray<=rnext^(rnext>>1);
            end else begin
                read_fault<=1;started<=0;rgb<=0;de<=0;hs<=0;vs<=0;
            end
        end
    end
endmodule
