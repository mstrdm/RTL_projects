// Module for calculating exp(-tn/td) function values based on prestored exp values in ROM.
// Implementation based on dividing exp into bins end encoding it in two LUTs: one, storing max value for each bin, and second - storing exp template for all bins.
// 39 LUT, 18 FF, +0.400 ns worst negative slack @500 MHz.
`timescale 1ns / 1ps
module exp_rom #(parameter wTn=6, wTd=6)
// wTn - numenator width
// wTd - denumenator width
	(input logic USRCLK_N, USRCLK_P, reset,
	// (input logic clk, reset,
	 input logic req,								// request to calculate exponent (should be applied for a single clock cycle)
	 input logic [wTn-1:0] tn,						// numenator of exponent argument
	 input logic [wTd-1:0] td,						// denumenator of exponent argument
	 output logic [wMAX-1:0] result);

localparam wA_BIN = 6;								// bin LUT address width
localparam wA_IND = 6;								// exp LUT address width
localparam vMAX = 255;								// max exponent value
localparam wMAX = $clog2(vMAX);						// exp value width
localparam wREC = 12;								// reciprocal LUT width
localparam nREC = 64;								// number of entries in reciprocal LUT
localparam wA_REC = $clog2(nREC);					// reciprocal LUT address width
localparam wTOT = wA_BIN + wA_IND;					// logarithm of the total number of points in a fit (x_tot = 2**wTOT)
localparam wSC = 3;									// log of the scaling factor for t to match the scale in LUT

logic clk;
clk_wiz_0 clock(
	.clk_in1_n(USRCLK_N),
	.clk_in1_p(USRCLK_P),
	.clk_out1(clk));

logic [wTn-1:0] tn_d;								// tn stored at the input
logic [wTd-1:0] td_d;								// td stored at the input
logic [wREC-1:0] recip_lut[nREC-1:0];				// reciprocal LUT
logic [wREC-1:0] td_rec;							// reciprocal td
logic [wTn-1:0] tn_d2;								// delayed tn
logic [wREC+wTn-1:0] t_prelim, t_prelim_d;			// prelimenary t (tn*2^12/td)
logic [wA_BIN+wA_IND-1:0] t;

logic [wMAX-1:0] bin_lut[2**wA_BIN-1:0];			// bin LUT
logic [wMAX-1:0] exp_lut[2**wA_IND-1:0];			// exp LUT
logic [wA_BIN-1:0] bin_addr;						// bin LUT address
logic [wA_IND-1:0] exp_addr;						// exp LUT address
logic [wMAX-1:0] bin_val, exp_val;					// bin and exp LUT values

(*use_dsp48 = "yes"*) logic [2*wMAX-1:0] result_upsc, result_upsc_d;		// results after bin and exp LUT value mupltiplication

// initializing LUTs
initial begin
	$readmemb("exp_lut.mem", exp_lut);
	$readmemb("bin_lut.mem", bin_lut);
	$readmemb("recip.mem", recip_lut);
end

// Storing input
always @(posedge clk)
	if (reset) begin
		tn_d <= 0;
		td_d <= 0;
	end
	else if (req) begin
		tn_d <= tn;
		td_d <= td;
	end

// Extracting reciprocal value for td
always @(posedge clk)
	if (reset) begin
		tn_d2 <= 0;
		td_rec <= 0;
	end
	else begin
		tn_d2 <= tn_d;
		td_rec <= recip_lut[td_d];
	end

// Calculating prelimenary t
always @(posedge clk)
	if (reset) t_prelim <= 0;
	else t_prelim <= tn_d2*td_rec;

always @(posedge clk)
	if (reset) t_prelim_d <= 0;
	else t_prelim_d <= t_prelim;

// Scaling t
// assign t = ((t_prelim_d>>wSC) < 2**wTOT-1) ? (t_prelim_d>>wSC):(2**wTOT-1);

always @(posedge clk)
	if (reset) t <= 0;
	else t <= ((t_prelim_d>>wSC) < 2**wTOT-1) ? (t_prelim_d>>wSC):(2**wTOT-1);

// Extracting bin and exp LUT addresses
assign bin_addr = t[wA_BIN+wA_IND-1:wA_IND];
assign exp_addr = t[wA_IND-1:0];

always @(posedge clk)
	if (reset) begin
		bin_val <= 0;
		exp_val <= 0;
	end
	else begin
		bin_val <= bin_lut[bin_addr];
		exp_val <= exp_lut[exp_addr];
	end

always @(posedge clk)
	if (reset) begin
		result_upsc <= 0;
		result <= 0;
	end
	else begin
		result_upsc <= bin_val*exp_val;
		result <= result_upsc>>wMAX;
	end

// always @(posedge clk)
// 	if (reset) result <= 0;
// 	else result <= result_upsc_d>>wMAX;

// Initialization
initial begin
	tn_d = 0;
	td_d = 0;
	tn_d2 = 0;
	td_rec = 0;
	t_prelim = 0;
	t_prelim_d = 0;
	t = 0;
	bin_val = 0;
	exp_val = 0;
	result_upsc = 0;
	// result_upsc_d = 0;
	result = 0;
end

endmodule

// --------------------------------------------------------------------------------------------------------------------------------------------
// // Implementation based on dividing exp into bins and using linear fit for each bin.
// // 37 LUT, 25 FF, +0.319 ns worst negative slack @500 MHz. 
// `timescale 1ns / 1ps
// module exp_rom #(parameter wTn=6, wTd=6)
// // wTn - numenator width
// // wTd - denumenator width
// 	(input logic USRCLK_N, USRCLK_P, reset,
// 	// (input logic clk, reset,
// 	 input logic req,								// request to calculate exponent (should be applied for a single clock cycle)
// 	 input logic [wTn-1:0] tn,						// numenator of exponent argument
// 	 input logic [wTd-1:0] td,						// denumenator of exponent argument
// 	 output logic [wPb-1:0] result);

// localparam wPa = 4;									// parameter "a" width (y = a*x + b)
// localparam wPb = 8;									// parameter "b" and output exponent value width
// localparam nBIN = 64;								// number of bins per exponential fit (entries in parameter LUT)
// localparam wA_BIN = $clog2(nBIN);					// exponent LUT address width
// localparam wREC = 12;								// reciprocal LUT width
// localparam nREC = 64;								// number of entries in reciprocal LUT
// localparam wA_REC = $clog2(nREC);					// reciprocal LUT address width
// localparam wK = 4;									// logarithm of the upscaling factor for improved linear fit precision (round_k = 2**wK)
// localparam wTOT = 11;								// logarithm of the total number of points in a fit (x_tot = 2**wTOT)
// localparam wSC = 4;									// logarithm of the scaling factor for t to match the scale in LUT (f_sc = 2**wSC)

// logic clk;
// clk_wiz_0 clock(
// 	.clk_in1_n(USRCLK_N),
// 	.clk_in1_p(USRCLK_P),
// 	.clk_out1(clk));

// logic [wTn-1:0] tn_d;								// tn stored at the input
// logic [wTd-1:0] td_d;								// td stored at the input
// logic [wREC-1:0] recip_lut[nREC-1:0];				// reciprocal LUT
// logic [wREC-1:0] td_rec;							// reciprocal td
// logic [wTn-1:0] tn_d2;								// delayed tn
// logic [wREC+wTn-1:0] t_prelim, t_prelim_d;			// prelimenary t (tn*2^12/td)
// logic [wTOT-1:0] t, t_d;
// logic [wPa+wPb-1:0] param_lut[nBIN-1:0];			// exponent fit parameter LUT
// logic [wA_BIN-1:0] bin_n;							// bin number
// logic [wPa-1:0] a;
// logic [wPb-1:0] b, b_d;
// logic [wPb+wK-1:0] b_sc;
// (*use_dsp48 = "yes"*) logic [wPb+wK-1:0] a_mp;							// a*t
// logic [wPb+wK-1:0] result_prelim;

// // initializing LUTs
// initial begin
// 	$readmemb("exp.mem", param_lut);
// 	$readmemb("recip.mem", recip_lut);
// end

// // Storing input
// always @(posedge clk)
// 	if (reset) begin
// 		tn_d <= 0;
// 		td_d <= 0;
// 	end
// 	else if (req) begin
// 		tn_d <= tn;
// 		td_d <= td;
// 	end

// // Extracting reciprocal value for td
// always @(posedge clk)
// 	if (reset) begin
// 		tn_d2 <= 0;
// 		td_rec <= 0;
// 	end
// 	else begin
// 		tn_d2 <= tn_d;
// 		td_rec <= recip_lut[td_d];
// 	end

// // Calculating prelimenary t
// always @(posedge clk)
// 	if (reset) t_prelim <= 0;
// 	else t_prelim <= tn_d2*td_rec;

// always @(posedge clk)
// 	if (reset) t_prelim_d <= 0;
// 	else t_prelim_d <= t_prelim;

// // Scaling t
// // assign t = ((t_prelim_d>>wSC) < 2**wTOT-1) ? (t_prelim_d>>wSC):(2**wTOT-1);
// always @(posedge clk)
// 	if (reset) t <= 0;
// 	else t <= ((t_prelim_d>>wSC) < 2**wTOT-1) ? (t_prelim_d>>wSC):(2**wTOT-1);

// // Extracting fitting parameters
// assign bin_n = t[wTOT-1:wTOT-wA_BIN];

// always @(posedge clk)
// 	if (reset) begin
// 		a <= 0;
// 		b <= 0;
// 	end
// 	else begin
// 		a <= param_lut[bin_n][wPa+wPb-1:wPb];
// 		b <= param_lut[bin_n][wPb-1:0];
// 	end

// always @(posedge clk)
// 	if (reset) t_d <= 0;
// 	else t_d <= t;

// // Linear fit
// always @(posedge clk)
// 	if (reset) begin
// 		b_d <= 0;
// 		a_mp <= 0;
// 	end
// 	else begin
// 		b_d <= b;
// 		a_mp <= a*t_d;
// 	end

// assign b_sc = b_d << wK;
// assign result_prelim = b_sc - a_mp;

// always @(posedge clk)
// 	if (reset) result <= 0;
// 	else result <= result_prelim >> wK;

// // Initialization
// initial begin
// 	tn_d = 0;
// 	td_d = 0;
// 	tn_d2 = 0;
// 	td_rec = 0;
// 	t_prelim = 0;
// 	t_prelim_d = 0;
// 	t = 0;
// 	a = 0;
// 	b = 0;
// 	t_d = 0;
// 	b_d = 0;
// 	a_mp = 0;
// 	b_sc = 0;
// 	result = 0;
// end

// endmodule
