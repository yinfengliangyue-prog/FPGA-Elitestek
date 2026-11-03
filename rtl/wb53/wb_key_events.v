// KEY[3:0] = SW3..SW0, active low. All logic runs in the video clock domain.
// Execute once on complete release; no auto-repeat. Unknown chords are ignored.
module wb_key_events #(
    parameter integer DEBOUNCE_CYCLES = 1400000 // 20 ms at 70 MHz
)(
    input wire clk, rst_n,
    input wire [3:0] key_n,
    output reg [3:0] command,
    output reg command_valid
);
    localparam integer CW = $clog2(DEBOUNCE_CYCLES+1);
    (* async_reg = "true" *) reg [3:0] key_meta, key_sync;
    reg [3:0] down;
    reg [CW-1:0] count [0:3];
    reg [CW-1:0] startup_count;
    reg ready, gesture;
    reg [3:0] seen;
    integer k;
    always @(posedge clk) begin
        if (!rst_n) begin
            key_meta<=4'hf; key_sync<=4'hf; down<=0;
            for(k=0;k<4;k=k+1) count[k]<=0;
            startup_count<=0; ready<=0; gesture<=0; seen<=0;
            command<=0;command_valid<=0;
        end else begin
            key_meta<=key_n; key_sync<=key_meta;command_valid<=0;
            for(k=0;k<4;k=k+1) begin
                if ((~key_sync[k]) == down[k]) count[k]<=0;
                else if(count[k]==DEBOUNCE_CYCLES-1) begin
                    down[k]<=~key_sync[k]; count[k]<=0;
                end else count[k]<=count[k]+1'b1;
            end
            // A key held during initialization must first be released.
            if(!ready) begin
                if(key_sync!=4'hf || down!=0) startup_count<=0;
                else if(startup_count==DEBOUNCE_CYCLES-1) ready<=1;
                else startup_count<=startup_count+1'b1;
            end else if(down!=0) begin
                gesture<=1; seen<=seen | down;
            end else if(gesture) begin
                gesture<=0; seen<=0;
                command<=seen;command_valid<=1;
            end
        end
    end
endmodule
