// Module for calculating exp(-t/tau) function values based on prestored exp values in ROM.
// Implementation based on dividing exp into bins end encoding it in two LUTs: one, storing max value for each bin, and second - storing exp template for all bins.
// Important: This circuit is for FIXED tau value (programmed into LUTs).
`timescale 1ns / 1ps
module exp_fix #()
// wT - numenator width
	(input logic USRCLK_N, USRCLK_P, reset,
	// (input logic clk, reset,
	 input logic req,								// request to calculate exponent (should be applied for a single clock cycle)
	 input logic [wTOT-1:0] tn,						// numenator of exponent argument
	 input logic re, we, sel,						// RAM read and write enable, selector for the LUT
	 input logic [wA_BIN-1:0] addr_in,				// address used for programming BIN_LUT; IMPORTANT: ASSUMING BIN AND EXP LUTs TO BE THE SAME SIZE
	 input logic [wMAX-1:0] data_in,				// data to LUTs
	 output logic [wMAX-1:0] data_out,				// data from LUTs
	 output logic [wMAX-1:0] result);

localparam wA_BIN = 6;								// bin LUT address width
localparam wA_IND = 6;								// exp LUT address width
localparam wTOT = wA_BIN + wA_IND;					// logarithm of the total number of points in a fit (x_tot = 2**wTOT)
localparam vMAX = 255;								// max exponent value
localparam wMAX = $clog2(vMAX);						// exp value width

logic clk;
clk_wiz_0 clock(
	.clk_in1_n(USRCLK_N),
	.clk_in1_p(USRCLK_P),
	.clk_out1(clk));

logic req_d, re_d, sel_d;
logic [wTOT-1:0] t;
logic [wMAX-1:0] bin_lut[2**wA_BIN-1:0];			// bin LUT
logic [wMAX-1:0] exp_lut[2**wA_IND-1:0];			// exp LUT
logic [wA_BIN-1:0] bin_addr;						// bin LUT address
logic [wA_IND-1:0] exp_addr;						// exp LUT address
logic [wMAX-1:0] bin_val, exp_val;					// bin and exp LUT values
logic [wMAX-1:0] bin_val_d, exp_val_d;				// bin and exp LUT values

(*use_dsp = "yes"*) logic [2*wMAX-1:0] result_upsc, result_upsc_d;		// results after bin and exp LUT value mupltiplication

// LUT programming
always @(posedge clk) begin
	if (sel&we) bin_lut[addr_in] <= data_in;
	if (~sel&we) exp_lut[addr_in] <= data_in;

	if (sel&re|req_d) bin_val <= bin_lut[bin_addr];
	if (~sel&re|req_d) exp_val <= exp_lut[exp_addr];
end

// initializing LUTs
initial begin
	$readmemb("exp_fix_lut.mem", exp_lut);
	$readmemb("bin_fix_lut.mem", bin_lut);
end

always @(posedge clk)
	if (reset) data_out <= 0;
	else if (re_d) data_out <= sel_d ? bin_val:exp_val;

// Delaying input control signals
always @(posedge clk)
	if (reset) begin
		req_d <= 0;
		re_d <= 0;
		sel_d <= 0;
	end
	else begin
		req_d <= req;
		re_d <= re;
		sel_d <= sel;
	end

// Prestoreing input value
always @(posedge clk)
	if (reset) t <= 0;
	else if (req) t <= tn;

// Extracting bin and exp LUT addresses
assign bin_addr = re ? addr_in:t[wTOT-1:wA_IND];
assign exp_addr = re ? addr_in:t[wA_IND-1:0];

always @(posedge clk)
	if (reset) begin
		bin_val_d <= 0;
		exp_val_d <= 0;
	end
	else begin
		bin_val_d <= bin_val;
		exp_val_d <= exp_val;
	end

always @(posedge clk)
	if (reset) begin
		result_upsc <= 0;
		result <= 0;
	end
	else begin
		result_upsc <= bin_val_d*exp_val_d;
		result <= result_upsc>>wMAX;
	end

// Initialization
initial begin
	t = 0;
	bin_val = 0;
	exp_val = 0;
	result_upsc = 0;
	result = 0;
end

endmodule