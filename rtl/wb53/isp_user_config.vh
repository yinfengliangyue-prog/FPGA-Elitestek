// All gains Q8: 256=1.0. Recompile after changing these constants.
// CFA matches the unchanged original sensor register table. RGGB=1, BGGR=0.
localparam CAMERA_CFA_RGGB = 1;
localparam CAMERA_BLACK_LEVEL = 17; // Starting value for this sensor, calibrate with a dark capture.
localparam VIDEO_ENHANCE_ENABLE = 1'b1;
localparam VIDEO_AWB_ENABLE = 1'b1;
localparam VIDEO_AWB_HOLD = 1'b0;
localparam [11:0] VIDEO_GAIN_R = 12'd256;
localparam [11:0] VIDEO_GAIN_G = 12'd256;
localparam [11:0] VIDEO_GAIN_B = 12'd256;
localparam VIDEO_TONE_ENABLE = 1'b1; // Gamma 2.2, half-code input precision.
localparam VIDEO_SHARP_ENABLE = 1'b1;
localparam VIDEO_SHARP_STRENGTH = 4; // Mild 0.25, avoid amplifying gamma-lifted noise.
localparam VIDEO_DETAIL_LIMIT = 16;
