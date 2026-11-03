
/////////////////////////////////////////////////////////////////////////////
//
// Copyright (C) 2013-2021 Efinix Inc. All rights reserved.
//
// Description:
// Example top file for ti60f225 dev kit OOB design
//
// Language:  Verilog 2001
//
// ------------------------------------------------------------------------------

/////////////////////////////////////////////////////////////////////////////////
//`define SOFT_TAP 1
`include "ddr3_controller/ddr3_parameter.vh"
// `include "define.v"

module ti60f225_oob_top #(

	parameter                       RANK_RATIO         = 1,       // # of unique CS outputs per rank
	parameter                       ASYN_AXI_CLK       = `ASYN_AXI_CLK, 
	parameter                       RANKS              = `RANKS,
	parameter                       CK_WIDTH           = `CK_WIDTH,       // # of CK/CK# outputs to memory   
	parameter                       CKE_WIDTH          = `CKE_WIDTH,       // # of cke outputs
	parameter                       CS_WIDTH           = `CS_WIDTH,       // # of unique CS outputs
	parameter                       BANK_WIDTH         = `BANK_WIDTH,       // # of bank bits
	parameter                       ROW_WIDTH          = `ROW_WIDTH,       // DRAM address bus width
	parameter                       COL_WIDTH          = `COL_WIDTH,      // column address width
	parameter                       DM_WIDTH           = `DM_WIDTH,       // # of DM (data mask)
	parameter                       DQS_WIDTH          = `DQS_WIDTH,       // # of DQS (strobe)
	parameter                       DQ_WIDTH           = `DQ_WIDTH,      // # of DQ (data)
	parameter                       ODT_WIDTH          = `ODT_WIDTH,
	parameter                       DQ_CNT_WIDTH       = `DQ_CNT_WIDTH,       // = ceil(log2(DQ_WIDTH))
	parameter                       DQS_CNT_WIDTH      = `DQS_CNT_WIDTH,       // = ceil(log2(DQS_WIDTH))  
	parameter                       DRAM_WIDTH         = `DRAM_WIDTH,       // # of DQ per DQS   
	parameter                       DATA_WIDTH         = `DATA_WIDTH,
	parameter                       ADDR_WIDTH         = `ADDR_WIDTH,    
	parameter                       AXI_ID_WIDTH       = `AXI_ID_WIDTH,
	parameter                       AXI_ADDR_WIDTH     = `AXI_ADDR_WIDTH,
	parameter                       AXI_DATA_WIDTH     = `AXI_DATA_WIDTH
)
(
  (* syn_peri_port = 0 *) input hdmi_tx_slow_clk,
  (* syn_peri_port = 0 *) output tmds_tx_clk_TX_OE,
  (* syn_peri_port = 0 *) output [9:0] tmds_tx_clk_TX_DATA,
  (* syn_peri_port = 0 *) output tmds_tx_clk_TX_RST,
  (* syn_peri_port = 0 *) output tmds_tx_data0_TX_OE,
  (* syn_peri_port = 0 *) output [9:0] tmds_tx_data0_TX_DATA,
  (* syn_peri_port = 0 *) output tmds_tx_data0_TX_RST,
  (* syn_peri_port = 0 *) output tmds_tx_data1_TX_OE,
  (* syn_peri_port = 0 *) output [9:0] tmds_tx_data1_TX_DATA,
  (* syn_peri_port = 0 *) output tmds_tx_data1_TX_RST,
  (* syn_peri_port = 0 *) output tmds_tx_data2_TX_OE,
  (* syn_peri_port = 0 *) output [9:0] tmds_tx_data2_TX_DATA,
  (* syn_peri_port = 0 *) output tmds_tx_data2_TX_RST,
  (* syn_peri_port = 0 *) input wire [3:0] key_n,
  (* syn_peri_port = 0 *) input io_cam_scl_IN,
  (* syn_peri_port = 0 *) input io_cam_sda_IN,
  (* syn_peri_port = 0 *) input clk_100m,
  (* syn_peri_port = 0 *) input pll_locked,
  (* syn_peri_port = 0 *) input user_pll_locked,
  (* syn_peri_port = 0 *) input i_pll_locked,
  (* syn_peri_port = 0 *) input i_mipi_rx_pclk,
  (* syn_peri_port = 0 *) input fb,
  (* syn_peri_port = 0 *) input vid_clk_dvi2,
  (* syn_peri_port = 0 *) input pll_inst4_CLKOUT0,
  (* syn_peri_port = 0 *) input CLK_5M,
  (* syn_peri_port = 0 *) input i_mipi_tx_pclk,
  (* syn_peri_port = 0 *) input i_mipi_txc_sclk,
  (* syn_peri_port = 0 *) input core_clk,
  (* syn_peri_port = 0 *) input i_mipi_txd_sclk,
  (* syn_peri_port = 0 *) input CLK_25M,
  (* syn_peri_port = 0 *) input sdram_clk,
  (* syn_peri_port = 0 *) input tx_cal_clk_90edge,
  (* syn_peri_port = 0 *) input rx_cal_clk,
  (* syn_peri_port = 0 *) input tx_cal_clk,
  (* syn_peri_port = 0 *) input i_cam_ck_CLKOUT,
  (* syn_peri_port = 0 *) input jtag_inst1_CAPTURE,
  (* syn_peri_port = 0 *) input jtag_inst1_DRCK,
  (* syn_peri_port = 0 *) input jtag_inst1_RESET,
  (* syn_peri_port = 0 *) input jtag_inst1_RUNTEST,
  (* syn_peri_port = 0 *) input jtag_inst1_SEL,
  (* syn_peri_port = 0 *) input jtag_inst1_SHIFT,
  (* syn_peri_port = 0 *) input jtag_inst1_TCK,
  (* syn_peri_port = 0 *) input jtag_inst1_TDI,
  (* syn_peri_port = 0 *) input jtag_inst1_TMS,
  (* syn_peri_port = 0 *) input jtag_inst1_UPDATE,
  (* syn_peri_port = 0 *) input [15:0] ddr_dq_in_hi,
  (* syn_peri_port = 0 *) input [15:0] ddr_dq_in_lo,
  (* syn_peri_port = 0 *) input [1:0] ddr_dqs_in_hi,
  (* syn_peri_port = 0 *) input [1:0] ddr_dqs_in_lo,
  (* syn_peri_port = 0 *) input i_cam_ck_LP_N_IN,
  (* syn_peri_port = 0 *) input i_cam_ck_LP_P_IN,
  (* syn_peri_port = 0 *) input cam_d2_FIFO_EMPTY,
  (* syn_peri_port = 0 *) input [7:0] cam_d2_HS_IN,
  (* syn_peri_port = 0 *) input cam_d2_LP_N_IN,
  (* syn_peri_port = 0 *) input cam_d2_LP_P_IN,
  (* syn_peri_port = 0 *) input cam_d3_FIFO_EMPTY,
  (* syn_peri_port = 0 *) input [7:0] cam_d3_HS_IN,
  (* syn_peri_port = 0 *) input cam_d3_LP_N_IN,
  (* syn_peri_port = 0 *) input cam_d3_LP_P_IN,
  (* syn_peri_port = 0 *) input cam_d0_FIFO_EMPTY,
  (* syn_peri_port = 0 *) input [7:0] cam_d0_HS_IN,
  (* syn_peri_port = 0 *) input cam_d0_LP_N_IN,
  (* syn_peri_port = 0 *) input cam_d0_LP_P_IN,
  (* syn_peri_port = 0 *) input cam_d1_FIFO_EMPTY,
  (* syn_peri_port = 0 *) input [7:0] cam_d1_HS_IN,
  (* syn_peri_port = 0 *) input cam_d1_LP_N_IN,
  (* syn_peri_port = 0 *) input cam_d1_LP_P_IN,
  (* syn_peri_port = 0 *) output io_cam_scl_OUT,
  (* syn_peri_port = 0 *) output io_cam_scl_OE,
  (* syn_peri_port = 0 *) output io_cam_sda_OUT,
  (* syn_peri_port = 0 *) output io_cam_sda_OE,
  (* syn_peri_port = 0 *) output [3:0] led,
  (* syn_peri_port = 0 *) output o_cam_rst_p,
  (* syn_peri_port = 0 *) output DDR3_PLL_RSTN,
  (* syn_peri_port = 0 *) output [2:0] pll_shift,
  (* syn_peri_port = 0 *) output pll_shift_ena,
  (* syn_peri_port = 0 *) output [4:0] pll_shift_sel,
  (* syn_peri_port = 0 *) output USER_PLL_RSTN,
  (* syn_peri_port = 0 *) output pll_inst1_RSTN,
  (* syn_peri_port = 0 *) output jtag_inst1_TDO,
  (* syn_peri_port = 0 *) output [15:0] ddr_addr,
  (* syn_peri_port = 0 *) output [2:0] ddr_ba,
  (* syn_peri_port = 0 *) output ddr_cas_n,
  (* syn_peri_port = 0 *) output ddr_ck_hi,
  (* syn_peri_port = 0 *) output ddr_ck_lo,
  (* syn_peri_port = 0 *) output [0:0] ddr_cke,
  (* syn_peri_port = 0 *) output [0:0] ddr_cs_n,
  (* syn_peri_port = 0 *) output [1:0] ddr_dm_hi,
  (* syn_peri_port = 0 *) output [1:0] ddr_dm_lo,
  (* syn_peri_port = 0 *) output [15:0] ddr_dq_out_hi,
  (* syn_peri_port = 0 *) output [15:0] ddr_dq_out_lo,
  (* syn_peri_port = 0 *) output [15:0] ddr_dq_oe,
  (* syn_peri_port = 0 *) output [1:0] ddr_dqs_out_hi,
  (* syn_peri_port = 0 *) output [1:0] ddr_dqs_out_lo,
  (* syn_peri_port = 0 *) output [1:0] ddr_dqs_oe,
  (* syn_peri_port = 0 *) output [1:0] ddr_dqs_oe_n,
  (* syn_peri_port = 0 *) output [0:0] ddr_odt,
  (* syn_peri_port = 0 *) output ddr_ras_n,
  (* syn_peri_port = 0 *) output ddr_reset_n,
  (* syn_peri_port = 0 *) output ddr_we_n,
  (* syn_peri_port = 0 *) output o_cam_ck_HS_ENA,
  (* syn_peri_port = 0 *) output o_cam_ck_HS_TERM,
  (* syn_peri_port = 0 *) output cam_d2_FIFO_RD,
  (* syn_peri_port = 0 *) output cam_d2_HS_ENA,
  (* syn_peri_port = 0 *) output cam_d2_HS_TERM,
  (* syn_peri_port = 0 *) output cam_d2_RST,
  (* syn_peri_port = 0 *) output cam_d3_FIFO_RD,
  (* syn_peri_port = 0 *) output cam_d3_HS_ENA,
  (* syn_peri_port = 0 *) output cam_d3_HS_TERM,
  (* syn_peri_port = 0 *) output cam_d3_RST,
  (* syn_peri_port = 0 *) output cam_d0_FIFO_RD,
  (* syn_peri_port = 0 *) output cam_d0_HS_ENA,
  (* syn_peri_port = 0 *) output cam_d0_HS_TERM,
  (* syn_peri_port = 0 *) output cam_d0_RST,
  (* syn_peri_port = 0 *) output cam_d1_FIFO_RD,
  (* syn_peri_port = 0 *) output cam_d1_HS_ENA,
  (* syn_peri_port = 0 *) output cam_d1_HS_TERM,
  (* syn_peri_port = 0 *) output cam_d1_RST
);



//===============================================================================
//localparam
//===============================================================================
localparam WR_FIFO_DEPTH  = 1024;
localparam RD_FIFO_DEPTH  = 1024;

// Keep the optional USER-JTAG peripheral pins present when the archived
// debugger core is not included.  Efinity 2026.1 otherwise optimizes TDI
// away before P&R and rejects the peripheral interface.  This loopback is
// inactive during ordinary FPGA configuration and is not used by the design.
assign jtag_inst1_TDO = jtag_inst1_TDI;
wire i_arstn=1'b1;

localparam	MAX_HRES		= 12'd1920;
localparam	MAX_VRES		= 12'd1080;
localparam	HSP			= 8'd44;
localparam	HBP			= 8'd148;
localparam	HFP			= 8'd88;
localparam	VSP			= 8'd5;
localparam	VBP			= 8'd36;
localparam	VFP			= 8'd4;

// Set to 1 only while building the standalone J5 panel diagnostic image.
// The normal camera-to-J5 image is built with this set to 0.

//===============================================================================
//signal
//===============================================================================
   
wire                              app_sr_active;
wire                              app_ref_ack;
wire                              app_zq_ack;
wire                              cal_done;

// Slave Interface Write Address Ports
wire [AXI_ID_WIDTH-1:0]           s_axi_awid;
wire [AXI_ADDR_WIDTH-1:0]         s_axi_awaddr;
wire [7:0]                        s_axi_awlen;
wire [2:0]                        s_axi_awsize;
wire [1:0]                        s_axi_awburst;
wire [0:0]                        s_axi_awlock;
wire [3:0]                        s_axi_awcache;
wire [2:0]                        s_axi_awprot;
wire                              s_axi_awvalid;
wire                              s_axi_awready;
// Slave Interface Write Data Ports
wire [AXI_DATA_WIDTH-1:0]         s_axi_wdata;
wire [(AXI_DATA_WIDTH/8)-1:0]     s_axi_wstrb;
wire                              s_axi_wlast;
wire                              s_axi_wvalid;
wire                              s_axi_wready;
// Slave Interface Write Response Ports
wire                              s_axi_bready;
wire [AXI_ID_WIDTH-1:0]           s_axi_bid;
wire [1:0]                        s_axi_bresp;
wire                              s_axi_bvalid;
// Slave Interface Read Address Ports
wire [AXI_ID_WIDTH-1:0]           s_axi_arid;
wire [AXI_ADDR_WIDTH-1:0]         s_axi_araddr;
wire [7:0]                        s_axi_arlen;
wire [2:0]                        s_axi_arsize;
wire [1:0]                        s_axi_arburst;
wire [0:0]                        s_axi_arlock;
wire [3:0]                        s_axi_arcache;
wire [2:0]                        s_axi_arprot;
wire                              s_axi_arvalid;
wire                              s_axi_arready;
// Slave Interface Read Data Ports
wire                              s_axi_rready;
wire [AXI_ID_WIDTH-1:0]           s_axi_rid;
wire [AXI_DATA_WIDTH-1:0]         s_axi_rdata;
wire [1:0]                        s_axi_rresp;
wire                              s_axi_rlast;
wire                              s_axi_rvalid;
// Independent raw camera client; arbitrated with processed compare storage.
// Slave Interface Write Address Ports
wire [AXI_ID_WIDTH-1:0]           raw_axi_awid;
wire [AXI_ADDR_WIDTH-1:0]         raw_axi_awaddr;
wire [7:0]                        raw_axi_awlen;
wire [2:0]                        raw_axi_awsize;
wire [1:0]                        raw_axi_awburst;
wire [0:0]                        raw_axi_awlock;
wire [3:0]                        raw_axi_awcache;
wire [2:0]                        raw_axi_awprot;
wire                              raw_axi_awvalid;
wire                              raw_axi_awready;
// Slave Interface Write Data Ports
wire [AXI_DATA_WIDTH-1:0]         raw_axi_wdata;
wire [(AXI_DATA_WIDTH/8)-1:0]     raw_axi_wstrb;
wire                              raw_axi_wlast;
wire                              raw_axi_wvalid;
wire                              raw_axi_wready;
// Slave Interface Write Response Ports
wire                              raw_axi_bready;
wire [AXI_ID_WIDTH-1:0]           raw_axi_bid;
wire [1:0]                        raw_axi_bresp;
wire                              raw_axi_bvalid;
// Slave Interface Read Address Ports
wire [AXI_ID_WIDTH-1:0]           raw_axi_arid;
wire [AXI_ADDR_WIDTH-1:0]         raw_axi_araddr;
wire [7:0]                        raw_axi_arlen;
wire [2:0]                        raw_axi_arsize;
wire [1:0]                        raw_axi_arburst;
wire [0:0]                        raw_axi_arlock;
wire [3:0]                        raw_axi_arcache;
wire [2:0]                        raw_axi_arprot;
wire                              raw_axi_arvalid;
wire                              raw_axi_arready;
// Slave Interface Read Data Ports
wire                              raw_axi_rready;
wire [AXI_ID_WIDTH-1:0]           raw_axi_rid;
wire [AXI_DATA_WIDTH-1:0]         raw_axi_rdata;
wire [1:0]                        raw_axi_rresp;
wire                              raw_axi_rlast;
wire                              raw_axi_rvalid;




////////////////////////////////////////////////////////////////
// System & Debugger
wire    w_arstn;
wire	w_sysclk_mcu_arstn;
wire	w_sysclk_mcu_arst;
wire	w_mipi_rx_pclk_arstn;
wire	w_mipi_rx_pclk_arst;

wire		       w_mipi_rx_vs;
wire		       w_mipi_rx_hs;
wire	       w_mipi_rx_de;
wire	[63:0]			w_mipi_rx_data	;

wire					io_systemReset;



//===================================================================================================
//reset module
//===================================================================================================

assign w_arstn  		       = i_pll_locked & pll_locked & user_pll_locked;
assign pll_inst1_RSTN  		= i_arstn;
assign USER_PLL_RSTN      		= i_arstn;
assign DDR3_PLL_RSTN 		= i_arstn;
reset_ctrl
#(
	.NUM_RST		(2),
	.CYCLE			(1),
	.IN_RST_ACTIVE	(4'b00),
	.OUT_RST_ACTIVE	(4'b10)
)
inst_reset_ctrl
(
	.i_arst		({2{w_arstn}}),//({{4{i_pll_locked}},                  {2{i_arstn}}}),
	.i_clk			({2{i_mipi_rx_pclk}}),
	.o_srst		({w_mipi_rx_pclk_arst, w_mipi_rx_pclk_arstn})
);


reset_ctrl
#(
	.NUM_RST		(2),
	.CYCLE			(10),
	.IN_RST_ACTIVE	(2'b00),
	.OUT_RST_ACTIVE	(2'b10)
)
inst_reset_mcu_ctrl
(
	.i_arst		({2{w_arstn}}),
	.i_clk			({2{i_soc_clk}}),
	.o_srst		({w_sysclk_mcu_arst,w_sysclk_mcu_arstn})
);



reg [25:0] cnt = 'd0;
always @( posedge core_clk)
begin 
       cnt <= cnt + 1'b1;
end
assign led[0]  = cal_done ? cnt[24] : 1'b0;

//========================================================================================================
//MIPI RX
//========================================================================================================
wire i_mipi_clk ;
assign i_mipi_clk = core_clk;
assign i_soc_clk  = core_clk;

		assign	cam_d0_RST		= 1'b0;
		assign	cam_d1_RST		= 1'b0;
		assign  cam_d2_RST = 1'b0;
    assign  cam_d3_RST = 1'b0;
	
	
		

		csi_rx_controller inst_efx_csi2_rx
		(
              .reset_n			(i_arstn),
              .clk				(i_mipi_clk),
              .reset_byte_HS_n	(i_arstn),
              .clk_byte_HS		  (i_cam_ck_CLKOUT),
              .reset_pixel_n		(w_mipi_rx_pclk_arstn),
              .clk_pixel			  (i_mipi_rx_pclk),
              
              .Rx_LP_CLK_P		  (i_cam_ck_LP_P_IN),
              .Rx_LP_CLK_N		  (i_cam_ck_LP_N_IN),
              .Rx_HS_enable_C		(o_cam_ck_HS_ENA),
              .LVDS_termen_C		(o_cam_ck_HS_TERM),
              
              .Rx_LP_D_P			({cam_d3_LP_P_IN, cam_d2_LP_P_IN, cam_d1_LP_P_IN, cam_d0_LP_P_IN}),//(r_mipi_rx_data_LP_P_IN_2P),
              .Rx_LP_D_N			({cam_d3_LP_N_IN, cam_d2_LP_N_IN, cam_d1_LP_N_IN, cam_d0_LP_N_IN}),//(r_mipi_rx_data_LP_N_IN_2P),
              .Rx_HS_D_0			(cam_d0_HS_IN),//(r_mipi_rx_data_HS_IN_2P[0*8+:8]),
              .Rx_HS_D_1			(cam_d1_HS_IN),//(r_mipi_rx_data_HS_IN_2P[1*8+:8]),
              .Rx_HS_D_2			(cam_d2_HS_IN),
              .Rx_HS_D_3			(cam_d3_HS_IN),
              .Rx_HS_D_4			(),
              .Rx_HS_D_5			(),
              .Rx_HS_D_6			(),
              .Rx_HS_D_7			(),
              .Rx_HS_enable_D		({cam_d3_HS_ENA    ,cam_d2_HS_ENA    ,cam_d1_HS_ENA    ,cam_d0_HS_ENA    }),//( w_cam_d_HS_ENA),
              .LVDS_termen_D		({cam_d3_HS_TERM   ,cam_d2_HS_TERM   ,cam_d1_HS_TERM   ,cam_d0_HS_TERM   }),
              .fifo_rd_enable		({cam_d3_FIFO_RD   ,cam_d2_FIFO_RD   ,cam_d1_FIFO_RD   ,cam_d0_FIFO_RD   }),
              .fifo_rd_empty		({cam_d3_FIFO_EMPTY,cam_d2_FIFO_EMPTY,cam_d1_FIFO_EMPTY,cam_d0_FIFO_EMPTY}),
              .DLY_enable_D		       (),
              .DLY_inc_D			(),
              .u_dly_enable_D		(),
              .u_dly_inc_D		       (),
              
              .axi_clk			(1'b0),
              .axi_reset_n		       (1'b0),
              .axi_awaddr			(6'b0),
              .axi_awvalid		       (1'b0),
              .axi_awready		       (),
              .axi_wdata			(32'b0),
              .axi_wvalid			(1'b0),
              .axi_wready			(),
              
              .axi_bvalid			(),
              .axi_bready			(1'b0),
              .axi_araddr			(6'b0),
              .axi_arvalid		       (1'b0),
              .axi_arready		       (),
              .axi_rdata			(),
              .axi_rvalid			(),
              .axi_rready			(1'b1),
              
              .hsync_vc0			(w_mipi_rx_hs),
              .hsync_vc1			(),
              .hsync_vc2			(),
              .hsync_vc3			(),
              .vsync_vc0			(w_mipi_rx_vs),
              .vsync_vc1			(),
              .vsync_vc2			(),
              .vsync_vc3			(),
              .vc				(),
              .word_count			(),
              .shortpkt_data_field        (),
              .datatype			(),
              .pixel_per_clk		(),
              .pixel_data			(w_mipi_rx_data),
              .pixel_data_valid	       (w_mipi_rx_de),
              .irq				()
		);

    wire		       w1_mipi_rx_vs;
wire		       w1_mipi_rx_hs;
wire	       w1_mipi_rx_de;
wire	[39:0]			w1_mipi_rx_data	;
sensor_clipper  sensor_clipper_inst (
    .clk(i_mipi_rx_pclk),
    .i_vs(w_mipi_rx_vs),
    .i_hs(w_mipi_rx_hs),
    .i_de(w_mipi_rx_de),
    .i_dat(w_mipi_rx_data[39:0]),

    .o_hs(w1_mipi_rx_hs),
    .o_vs(w1_mipi_rx_vs),
    .o_de(w1_mipi_rx_de),
    .o_dat(w1_mipi_rx_data)
   
  );

//========================================================================================================
//
//========================================================================================================
		

//*************** imx219 config********************/
// mipi_config_imx219_top u_config_imx219(
// 										.i_sys_clk(CLK_5M)    	,    /////48M 
// 										.sys_rstn(vid_rst_n )    ,
// 										.o_sen_rst_n(o_cam_rstn)  	,
										
										// .o_iic_sda_OE(io_cam_sda_OE) ,
										// .i_iic_sda(io_cam_sda_IN)   	,
										// .o_iic_sda(io_cam_sda_OUT)   	,
										// .o_iic_scl(io_cam_scl)    	
										// ); 	

wire scl_padoen_o;
wire sda_padoen_o;


reg [12:0] i2c_rst_cnt = '0;

always @( posedge CLK_5M or negedge w_arstn )
begin
    if( !w_arstn )
       i2c_rst_cnt <= 'd0;
    else 
       i2c_rst_cnt <= i2c_rst_cnt[12] ? i2c_rst_cnt : i2c_rst_cnt + 1'b1;
end
wire i2c_rst_n = i2c_rst_cnt[12];

i2c_master_ctrl_top u2_i2c_master_ctrl_top(
  /*i*/.clk			(CLK_5M		),
  /*i*/.rst_n			(i2c_rst_n		),
  /*i*/.scl_pad_i     (io_cam_scl_IN),//(1'b1),
  /*o*/.scl_pad_o     (io_cam_scl_OUT),
  /*o*/.scl_padoen_o  (scl_padoen_o),
  /*i*/.sda_pad_i     (io_cam_sda_IN),
  /*o*/.sda_pad_o     (io_cam_sda_OUT),
  /*o*/.sda_padoen_o  (sda_padoen_o)
  
  );
assign o_cam_rst_p = ~w_arstn;
assign io_cam_scl_OE = ~scl_padoen_o;
assign io_cam_sda_OE = ~sda_padoen_o;

//=====================================================================================

//frame buffer
//=====================================================================================
wire [7:0] 	ch0_r;
wire [7:0]    ch0_g;
wire [7:0]    ch0_b;
wire ch0_vs;
wire ch0_hs;
wire ch0_de;

wire hs;
wire vs;
wire de;
wire [7:0] rgb_1,rgb_0;
wire [7:0] rgb_2,rgb_3;
(* async_reg="true" *) reg [1:0] cal_ready_sync;
always @(posedge vid_clk_dvi2 or negedge w_arstn) begin
    if(!w_arstn) cal_ready_sync<=0;
    else cal_ready_sync<={cal_ready_sync[0],cal_done};
end
reg [19:0] hdmi_start_count;
always @(posedge vid_clk_dvi2 or negedge w_arstn) begin
    if(!w_arstn) hdmi_start_count<=0;
    else if(!cal_ready_sync[1]) hdmi_start_count<=0;
    else if(!(&hdmi_start_count)) hdmi_start_count<=hdmi_start_count+1'b1;
end
wire pixel_data_en=&hdmi_start_count;

color_bar_rgb # (
    .DYN_EN(1'b1),
    .HS_POLORY(1'b1),
    .VS_POLORY(1'b1),
    .SYMBOL_WIDTH(8),
    .SYMBOL_NUM(1),
    .PAR_PIXEL_NUM(4),
    .HFP(HFP),
    .HST(HSP),
    .HACT(MAX_HRES),
    .HBP(HBP),
    .VFP(VFP),
    .VST(VSP),
    .VACT(MAX_VRES),
    .VBP(VBP),
    .TEST_MODE(2'd0)
  )
  color_bar_rgb_inst (
    .clk(vid_clk_dvi2),//(i_mipi_rx_pclk),
    .rst_n(pixel_data_en),
    .h_cnt(h_cnt),
    .v_cnt(v_cnt),
    .hs(hs),
    .vs(vs),
    .de(de),
    .o_vid_data({rgb_3,rgb_2,rgb_1,rgb_0})
  );


// IMX219
  frame_buffer #(
.I_VID_WIDTH         (32),
.O_VID_WIDTH         (16),
.START_ADDR          (32'h00000        ),
.AXI_DATA_WIDTH      ( AXI_DATA_WIDTH	),
.AXI_ADDR_WIDTH      ( AXI_ADDR_WIDTH	),
.WR_FIFO_DEPTH	      ( 512		),    
.RD_FIFO_DEPTH 	      ( 512 	),
.BURST_LEN  	       (127),
.FB_NUM	            (3),
.MAX_VID_WIDTH	    (960) ,
.MAX_VID_HIGHT	    (1080) 


)checker0(
       .axi_clk		(core_clk 	        ),
       .rst_n			(pixel_data_en),//(vid_rst_n   ),
       .freeze_req(1'b0), .frozen(),

/*i*/.i_clk			(i_mipi_rx_pclk      ),//(vid_clk_dvi2),//
/*i*/.i_vs			(w_mipi_rx_vs	),//(vs),//
/*i*/.i_de			(w_mipi_rx_de & w_mipi_rx_hs	),//(de),//
/*i*/.vin 		({w_mipi_rx_data[39:32],w_mipi_rx_data[29:22],w_mipi_rx_data[19:12],w_mipi_rx_data[9:2]}	),//	({rgb_3,rgb_2,rgb_1,rgb_0}),//
                     
/*i*/.o_clk			(vid_clk_dvi2),//(i_mipi_rx_pclk	),
/*i*/.o_hs    		(ch0_hs		),			
/*i*/.o_vs    		(ch0_vs		),			
/*i*/.o_de    		(ch0_de		),			
/*i*/.vout    		({ch0_g,ch0_b}	),//ch0_r,

/*i*/.H_FRONT_PORCH (HFP/2  		),//
/*i*/.H_SYNC 	 	    (HSP/2	 	),///2
/*i*/.H_VALID 	 	  (MAX_HRES/2     ),//		
/*i*/.H_BACK_PORCH	(HBP/2		),//		
/*i*/.V_FRONT_PORCH (VFP  		),//		
/*i*/.V_SYNC 	 	    (VSP 	 	),//		
/*i*/.V_VALID 	 	  (MAX_VRES     ),//		
/*i*/.V_BACK_PORCH	(VBP		),//		

       .awid			(raw_axi_awid	),      
       .awaddr		(raw_axi_awaddr	),
       .awlen			(raw_axi_awlen	),
       .awsize		(raw_axi_awsize	),
       .awburst		(raw_axi_awburst),
       .awprot    (raw_axi_awprot ),
       .awcache   (raw_axi_awcache),
       .awlock		(raw_axi_awlock	),
       .awvalid		(raw_axi_awvalid),
       .awready		(raw_axi_awready),

       .arid			(raw_axi_arid	  ),
       .araddr		(raw_axi_araddr	),
       .arlen			(raw_axi_arlen	),
       .arsize		(raw_axi_arsize	),
       .arburst 	(raw_axi_arburst),

       .arprot    (raw_axi_arprot ),
       .arcache   (raw_axi_arcache),
       .arlock 		(raw_axi_arlock	),
       .arvalid		(raw_axi_arvalid),
       .arready		(raw_axi_arready),

       .wdata			(raw_axi_wdata	),
       .wstrb			(raw_axi_wstrb	),
       .wlast			(raw_axi_wlast	),
       .wvalid		(raw_axi_wvalid	),
       .wready		(raw_axi_wready	),


       .rid			  (raw_axi_rid	),
       .rdata			(raw_axi_rdata	),
       .rlast			(raw_axi_rlast	),
       .rvalid 		(raw_axi_rvalid	),
       .rready		(raw_axi_rready	),
       .rresp			(raw_axi_rresp	),

       .bid			  (raw_axi_bid	),
       .bvalid		(raw_axi_bvalid	),
       .bready	  (raw_axi_bready	)
);


ddr3_top                 u_ddr3_top
(

.axi_clk                (core_clk            ),
.core_clk               (core_clk            ),
.sdram_clk              (sdram_clk           ),  
.rx_cal_clk             (rx_cal_clk          ),
.tx_cal_clk             (tx_cal_clk          ),
.tx_cal_clk_90edge      (tx_cal_clk_90edge   ),
.rstn                   (w_arstn             ),      
.pll_shift              (pll_shift           ),
.pll_shift_sel          (pll_shift_sel       ),
.pll_shift_ena          (pll_shift_ena       ),       
///////////////DDR BUS
.ddr_ck_hi              (ddr_ck_hi           ),
.ddr_ck_lo              (ddr_ck_lo           ),
.ddr_cke                (ddr_cke             ),    
.ddr_reset_n            (ddr_reset_n         ),
.ddr_cs_n               (ddr_cs_n            ),
.ddr_ras_n              (ddr_ras_n           ),
.ddr_cas_n              (ddr_cas_n           ),
.ddr_we_n               (ddr_we_n            ),     
.ddr_addr               (ddr_addr            ),
.ddr_ba                 (ddr_ba              ),

.ddr_dqs_oe             (ddr_dqs_oe          ),
.ddr_dqs_oe_n           (ddr_dqs_oe_n        ),
.ddr_dq_oe              (ddr_dq_oe           ),
.ddr_dqs_in_hi          (ddr_dqs_in_hi       ),
.ddr_dqs_in_lo          (ddr_dqs_in_lo       ),
.ddr_dq_in_hi           (ddr_dq_in_hi        ),
.ddr_dq_in_lo           (ddr_dq_in_lo        ),

.ddr_dqs_out_hi         (ddr_dqs_out_hi      ),
.ddr_dqs_out_lo         (ddr_dqs_out_lo      ),
.ddr_dq_out_hi          (ddr_dq_out_hi       ),
.ddr_dq_out_lo          (ddr_dq_out_lo       ),

.ddr_dm_hi              (ddr_dm_hi           ),
.ddr_dm_lo              (ddr_dm_lo           ),
.ddr_odt                (ddr_odt             ),

// Application interface ports
.app_sr_req                     (1'b0),
.app_ref_req                    (1'b0),
.app_zq_req                     (1'b0),
.app_sr_active                  (app_sr_active),
.app_ref_ack                    (app_ref_ack),
.app_zq_ack                     (app_zq_ack),

// Slave Interface Write Address Ports
.s_axi_awid                     (s_axi_awid        ),
.s_axi_awaddr                   (s_axi_awaddr      ),
.s_axi_awlen                    (s_axi_awlen       ),
.s_axi_awsize                   (s_axi_awsize      ),
.s_axi_awburst                  (s_axi_awburst     ),
.s_axi_awlock                   (s_axi_awlock      ),
.s_axi_awcache                  (s_axi_awcache     ),
.s_axi_awprot                   (s_axi_awprot      ),
.s_axi_awqos                    (4'h0              ),
.s_axi_awvalid                  (s_axi_awvalid     ),
.s_axi_awready                  (s_axi_awready     ),
// Slave Interface Write Data Ports
.s_axi_wdata                    (s_axi_wdata       ),
.s_axi_wstrb                    (s_axi_wstrb       ),
.s_axi_wlast                    (s_axi_wlast       ),
.s_axi_wvalid                   (s_axi_wvalid      ),
.s_axi_wready                   (s_axi_wready      ),
// Slave Interface Write Response Ports
.s_axi_bid                      (s_axi_bid         ),
.s_axi_bresp                    (s_axi_bresp       ),
.s_axi_bvalid                   (s_axi_bvalid      ),
.s_axi_bready                   (s_axi_bready      ),
// Slave Interface Read Address Ports
.s_axi_arid                     (s_axi_arid        ),
.s_axi_araddr                   (s_axi_araddr      ),
.s_axi_arlen                    (s_axi_arlen       ),
.s_axi_arsize                   (s_axi_arsize      ),
.s_axi_arburst                  (s_axi_arburst     ),
.s_axi_arlock                   (s_axi_arlock      ),
.s_axi_arcache                  (s_axi_arcache     ),
.s_axi_arprot                   (s_axi_arprot      ),
.s_axi_arqos                    (4'h0              ),
.s_axi_arvalid                  (s_axi_arvalid     ),
.s_axi_arready                  (s_axi_arready     ),
// Slave Interface Read Data Ports
.s_axi_rid                      (s_axi_rid         ),
.s_axi_rdata                    (s_axi_rdata       ),
.s_axi_rresp                    (s_axi_rresp       ),
.s_axi_rlast                    (s_axi_rlast       ),
.s_axi_rvalid                   (s_axi_rvalid      ),
.s_axi_rready                   (s_axi_rready      ),
//DEBUG       
.wrlvl_dq_check                 (wrlvl_dq_check    ) ,
.rd_level_dqs_check             (rd_level_dqs_check) ,
.init_cur_state                 (init_cur_state    ) ,
.idelay_ld                      (idelay_ld         ) ,
.mpr_rdlvl_dly                  (mpr_rdlvl_dly     ) ,
.cal_done                       (cal_done          ) 
);

//***************************************************************************
// debayer
//***************************************************************************


wire        rgb_vs;
wire        rgb_hs;
wire        rgb_de;
wire        rgb_valid;
wire [47:0] rgb_datax2;


debayer_top_2to1 debayer_top
(
	.in_pclk		  (vid_clk_dvi2),//(i_mipi_rx_pclk ),
	.in_rstn		  (pixel_data_en),//(vid_rst_n	),
	
	.raw_vs_i		  (ch0_vs		      ),
	.raw_hs_i		  (ch0_hs		      ),
	.raw_de_i		  (ch0_de		      ),
	.raw_valid_i	(ch0_de	        ),
	.raw_datax4_i	({ch0_b,ch0_g}	),
	
	.rgb_vs_o		  (rgb_vs         ),
	.rgb_hs_o		  (rgb_hs         ),
	.rgb_de_o		  (rgb_de         ),
	.rgb_valid_o	(rgb_valid      ),
	.rgb_datax2_o (rgb_datax2     )//b,g,r,b,g,r
);


//==============================================================================
// Integrated HDMI processing and independent/synchronous snapshots.
reg [1:0] edge_reset_sync;
always @(posedge vid_clk_dvi2 or negedge pixel_data_en) begin
    if(!pixel_data_en) edge_reset_sync<=0;
    else edge_reset_sync<={edge_reset_sync[0],1'b1};
end
reg [1:0] compare_axi_reset;
always @(posedge core_clk or negedge pixel_data_en) begin
    if(!pixel_data_en) compare_axi_reset<=0;
    else compare_axi_reset<={compare_axi_reset[0],1'b1};
end
wire [7:0] threshold_a,threshold_b;
wire [2:0] mode_a,mode_b;
wire [7:0] low_a,low_b,analysis_high,analysis_low;
wire shape_enable,number_enable,edit_low;
wire [1:0] menu_page;
wire fullscreen,denoise_enable,ai_min_select;wire [7:0] ai_min_strength;
// Fixed display-rate indication requested by the user, not a camera measurement.
wire [9:0] fps_cam=10'd60,fps_vid=10'd60;wire fps_valid=1'b1;
wire selected_b,swap_sides,live_b,capture_a,capture_b,same_frame,live_a,live_group,capture_group,awb_lock_request;
wire osd_activity_toggle,osd_help_toggle;wire [2:0] osd_context;
wire compare_held,compare_fault;
wire recognition_run;wire [2:0] app_mode;wire settings_open,editing,confirm_reset,aux_visible,shape_lock_request,osd_detail,fps_show,shape_locked,shape_result_valid;
wire [4:0] menu_cursor;
wire [1:0] frame_page,frame_speed;wire frame_playing,frame_recording,frame_selected;
wire [7:0] frame_count,frame_a,frame_b;wire [15:0] frame_delta;
wire replay_command_toggle;wire [3:0] replay_command;wire [2:0] replay_style_a,replay_style_b;
wire [11:0] wb_qr,wb_qg,wb_qb;
keys55 #(.BOOT_APP(3),.DEBOUNCE_CYCLES(1485000),.HOLD_CYCLES(44550000),.REPEAT_CYCLES(11137500)) key_control_inst(
    .clk(vid_clk_dvi2),.rst_n(edge_reset_sync[1]),.key_n(key_n),
    .osd_activity_toggle(osd_activity_toggle),.osd_help_toggle(osd_help_toggle),.osd_context(osd_context),
    .frame_page(frame_page),.frame_speed(frame_speed),.frame_playing(frame_playing),.frame_recording(frame_recording),
    .frame_selected(frame_selected),.frame_count(frame_count),.frame_a(frame_a),.frame_b(frame_b),.frame_delta(frame_delta),
    .replay_command_toggle(replay_command_toggle),.replay_command(replay_command),.replay_style_a(replay_style_a),.replay_style_b(replay_style_b),
    .wb_qr(wb_qr),.wb_qg(wb_qg),.wb_qb(wb_qb),
    .app_mode(app_mode),.settings_open(settings_open),.editing(editing),.confirm_reset(confirm_reset),.menu_cursor(menu_cursor),
    .aux_visible(aux_visible),.shape_lock_request(shape_lock_request),.osd_detail(osd_detail),.fps_show(fps_show),
    .shape_locked(shape_locked),.shape_result_valid(shape_result_valid),.recognition_run(recognition_run),
    .threshold_a(threshold_a),.threshold_b(threshold_b),.mode_a(mode_a),.mode_b(mode_b),
    .low_a(low_a),.low_b(low_b),.analysis_high(analysis_high),.analysis_low(analysis_low),
    .shape_enable(shape_enable),.number_enable(number_enable),.edit_low(edit_low),.menu_page(menu_page),.fullscreen(fullscreen),.denoise_enable(denoise_enable),.ai_min_strength(ai_min_strength),.ai_min_select(ai_min_select),
    .awb_lock_request(awb_lock_request),.live_a(live_a),.live_group(live_group),.capture_group(capture_group),
    .same_frame(same_frame),.selected_b(selected_b),.swap_sides(swap_sides),.live_b(live_b),.capture_a(capture_a),.capture_b(capture_b));
assign led[1]=selected_b;
assign led[2]=compare_held;
assign led[3]=compare_fault | gear_fault_sync[1];
wire [31:0] compare_awaddr,compare_araddr;
wire [7:0] compare_awlen,compare_arlen;
wire compare_awvalid,compare_awready,compare_wvalid,compare_wlast,compare_wready;
wire compare_bvalid,compare_bready,compare_arvalid,compare_arready,compare_rvalid,compare_rlast,compare_rready;
wire [127:0] compare_wdata,compare_rdata;
wire [15:0] compare_wstrb;
wire [1:0] compare_bresp,compare_rresp;
wire [47:0] edge_video_rgb;
wire edge_video_de,edge_video_hs,edge_video_vs;
system55 #(
    .W(MAX_HRES),.H(MAX_VRES),.HT((MAX_HRES+HSP+HBP+HFP)/2),.VT(MAX_VRES+VSP+VBP+VFP),
    .HB((HSP+HBP)/2),.VB(VSP+VBP),.HS(HSP/2),.VS(VSP),.PANEL_SWAP_RB_ON_EDGE(0)
) compare_inst (
    .video_clk(vid_clk_dvi2),.video_rst_n(edge_reset_sync[1]),.axi_clk(core_clk),.axi_rst_n(compare_axi_reset[1]),
    .osd_activity_toggle(osd_activity_toggle),.osd_help_toggle(osd_help_toggle),.osd_context(osd_context),
    .frame_page(frame_page),.frame_speed(frame_speed),.frame_playing(frame_playing),.frame_recording(frame_recording),
    .frame_selected(frame_selected),.frame_count(frame_count),.frame_a(frame_a),.frame_b(frame_b),.frame_delta(frame_delta),
    .replay_command_toggle(replay_command_toggle),.replay_command(replay_command),.replay_style_a(replay_style_a),.replay_style_b(replay_style_b),
    .wb_qr(wb_qr),.wb_qg(wb_qg),.wb_qb(wb_qb),
    .app_mode(app_mode),.settings_open(settings_open),.editing(editing),.confirm_reset(confirm_reset),.menu_cursor(menu_cursor),
    .aux_visible(aux_visible),.shape_lock_request(shape_lock_request),.osd_detail(osd_detail),.fps_show(fps_show),
    .shape_locked(shape_locked),.shape_result_valid(shape_result_valid),.recognition_run(recognition_run),
    .rgb_in(rgb_datax2),.de_in(rgb_de),.hs_in(rgb_hs),.vs_in(rgb_vs),
    .mode_a(mode_a),.mode_b(mode_b),.threshold_a(threshold_a),.threshold_b(threshold_b),
    .low_a(low_a),.low_b(low_b),.analysis_high(analysis_high),.analysis_low(analysis_low),
    .shape_enable(shape_enable),.number_enable(number_enable),.edit_low(edit_low),.menu_page(menu_page),.fullscreen(fullscreen),.denoise_enable(denoise_enable),.ai_min_strength(ai_min_strength),.ai_min_select(ai_min_select),.fps_cam(fps_cam),.fps_vid(fps_vid),.fps_valid(fps_valid),
    .awb_lock_request(awb_lock_request),.live_a(live_a),.live_group(live_group),.capture_group(capture_group),
    .same_frame(same_frame),.selected_b(selected_b),.swap_sides(swap_sides),.live_b(live_b),.capture_a(capture_a),.capture_b(capture_b),
    .rgb_out(edge_video_rgb),.de_out(edge_video_de),.hs_out(edge_video_hs),.vs_out(edge_video_vs),
    .held_b(compare_held),.fault(compare_fault),
    .awaddr(compare_awaddr),.awlen(compare_awlen),.awvalid(compare_awvalid),.awready(compare_awready),
    .wdata(compare_wdata),.wstrb(compare_wstrb),.wvalid(compare_wvalid),.wlast(compare_wlast),.wready(compare_wready),
    .bvalid(compare_bvalid),.bresp(compare_bresp),.bready(compare_bready),
    .araddr(compare_araddr),.arlen(compare_arlen),.arvalid(compare_arvalid),.arready(compare_arready),
    .rdata(compare_rdata),.rresp(compare_rresp),.rvalid(compare_rvalid),.rlast(compare_rlast),.rready(compare_rready));
wire [1:0] pair_awready,pair_wready,pair_bvalid,pair_arready,pair_rvalid,pair_rlast;
wire [3:0] pair_bresp,pair_rresp;
wire [255:0] pair_rdata;
assign {compare_awready,raw_axi_awready}=pair_awready;
assign {compare_wready,raw_axi_wready}=pair_wready;
assign {compare_bvalid,raw_axi_bvalid}=pair_bvalid;
assign {compare_arready,raw_axi_arready}=pair_arready;
assign {compare_rvalid,raw_axi_rvalid}=pair_rvalid;
assign {compare_rlast,raw_axi_rlast}=pair_rlast;
assign {compare_rdata,raw_axi_rdata}=pair_rdata;
assign {compare_rresp,raw_axi_rresp}=pair_rresp;
assign compare_bresp=pair_bresp[3:2];
assign raw_axi_bid=0;assign raw_axi_rid=0;
assign s_axi_awid=0;assign s_axi_awsize=4;assign s_axi_awburst=1;
assign s_axi_awlock=0;assign s_axi_awcache=3;assign s_axi_awprot=2;
assign s_axi_arid=0;assign s_axi_arsize=4;assign s_axi_arburst=1;
assign s_axi_arlock=0;assign s_axi_arcache=3;assign s_axi_arprot=2;
axi_pair23 memory_arbiter(
    .clk(core_clk),.rst_n(compare_axi_reset[1]),
    .c_awaddr({compare_awaddr,raw_axi_awaddr}),.c_awlen({compare_awlen,raw_axi_awlen}),
    .c_awvalid({compare_awvalid,raw_axi_awvalid}),.c_awready(pair_awready),
    .c_wdata({compare_wdata,raw_axi_wdata}),.c_wstrb({compare_wstrb,raw_axi_wstrb}),
    .c_wvalid({compare_wvalid,raw_axi_wvalid}),.c_wlast({compare_wlast,raw_axi_wlast}),.c_wready(pair_wready),
    .c_bvalid(pair_bvalid),.c_bresp(pair_bresp),.c_bready({compare_bready,raw_axi_bready}),
    .c_araddr({compare_araddr,raw_axi_araddr}),.c_arlen({compare_arlen,raw_axi_arlen}),
    .c_arvalid({compare_arvalid,raw_axi_arvalid}),.c_arready(pair_arready),
    .c_rdata(pair_rdata),.c_rresp(pair_rresp),.c_rvalid(pair_rvalid),.c_rlast(pair_rlast),
    .c_rready({compare_rready,raw_axi_rready}),
    .awaddr(s_axi_awaddr),.awlen(s_axi_awlen),.awvalid(s_axi_awvalid),.awready(s_axi_awready),
    .wdata(s_axi_wdata),.wstrb(s_axi_wstrb),.wvalid(s_axi_wvalid),.wlast(s_axi_wlast),.wready(s_axi_wready),
    .bvalid(s_axi_bvalid),.bresp(s_axi_bresp),.bready(s_axi_bready),
    .araddr(s_axi_araddr),.arlen(s_axi_arlen),.arvalid(s_axi_arvalid),.arready(s_axi_arready),
    .rdata(s_axi_rdata),.rresp(s_axi_rresp),.rvalid(s_axi_rvalid),.rlast(s_axi_rlast),.rready(s_axi_rready));

(* async_reg="true" *) reg [1:0] gear_fault_sync;
always @(posedge vid_clk_dvi2) begin
 if(!edge_reset_sync[1])gear_fault_sync<=0;
 else gear_fault_sync<={gear_fault_sync[0],gear_fault};
end
// Repack continuous pairs into one RGB pixel per HDMI clock. Blank clocks included.
wire [23:0] hdmi_rgb;
wire hdmi_de,hdmi_hs,hdmi_vs,gear_fault;
wire hdmi_arst_n=pixel_data_en & w_arstn;
hdmi_gearbox40 gearbox_inst(
    .pair_clk(vid_clk_dvi2),.pixel_clk(hdmi_tx_slow_clk),.arst_n(hdmi_arst_n),
    .rgb_pair(edge_video_rgb),.de_pair(edge_video_de),.hs_pair(edge_video_hs),.vs_pair(edge_video_vs),
    .rgb(hdmi_rgb),.de(hdmi_de),.hs(hdmi_hs),.vs(hdmi_vs),.fault(gear_fault));
reg [1:0] hdmi_reset_sync;
always @(posedge hdmi_tx_slow_clk or negedge hdmi_arst_n) begin
    if(!hdmi_arst_n)hdmi_reset_sync<=0;
    else hdmi_reset_sync<={hdmi_reset_sync[0],1'b1};
end
wire [9:0] tmds_clk,tmds_data0,tmds_data1,tmds_data2;
dvi_encoder encoder_inst(
    .pixelclk(hdmi_tx_slow_clk),.rst_p(~hdmi_reset_sync[1]),
    .i_rdata(hdmi_rgb[23:16]),.i_gdata(hdmi_rgb[15:8]),.i_bdata(hdmi_rgb[7:0]),
    .i_de(hdmi_de),.i_hs(hdmi_hs),.i_vs(hdmi_vs),
    .video_format(2'b00),.video_VIC(7'd16),
    .audio_L(24'd0),.audio_R(24'd0),.audio_valid(1'b0),
    .audio_N(20'd6144),.audio_CTS(20'd148500),
    .audio_sample_frequency(4'd2),.audio_word_length(4'b1011),
    .tmds_data0(tmds_data0),.tmds_data1(tmds_data1),.tmds_data2(tmds_data2),.tmds_clk(tmds_clk));
// Board P/N reversal is documented by the user-approved 20261012 schematic, page 10.
assign tmds_tx_clk_TX_DATA=~tmds_clk;
assign tmds_tx_data0_TX_DATA=~tmds_data0;
assign tmds_tx_data1_TX_DATA=~tmds_data1;
assign tmds_tx_data2_TX_DATA=~tmds_data2;
assign tmds_tx_clk_TX_OE=1'b1;
assign tmds_tx_data0_TX_OE=1'b1;
assign tmds_tx_data1_TX_OE=1'b1;
assign tmds_tx_data2_TX_OE=1'b1;
assign tmds_tx_clk_TX_RST=~hdmi_reset_sync[1];
assign tmds_tx_data0_TX_RST=~hdmi_reset_sync[1];
assign tmds_tx_data1_TX_RST=~hdmi_reset_sync[1];
assign tmds_tx_data2_TX_RST=~hdmi_reset_sync[1];
endmodule
