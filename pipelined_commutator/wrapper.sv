// Wrapper module for pipelined commutator. Includes pre-commutator module and pre-commutator adapter for arbitrary number of commutator endpoints.
// Check commutator module for further description of it's function.
// NOTE: Module implemented with no timing errors @500 MHz clock with nIN=12 and nOUT=32.
`timescale 1ns / 1ps
module wrapper
	(input logic usrclk_p, usrclk_n, reset, in, rec,
	 output logic out);

localparam nIN = 12;						// 8
localparam nPIPE = 2;					// 2
localparam wD = 38;						// 25
localparam nOUT = 32;					// 52
localparam wA_OUT = $clog2(nOUT);											// output channel address width
localparam wDATA = nIN*(wD+1+wA_OUT);
localparam wDATA_OUT = nOUT*(wD+1);
localparam wA_PIPE = $clog2(nPIPE);

genvar i;

logic clk;
logic [wDATA-1:0] input_data;
logic [wDATA_OUT-1:0] output_data, data_out;

logic [nIN-1:0] pre_req_in;
logic [nIN*wD-1:0] pre_data_in;
logic [nIN*wA_OUT-1:0] pre_addr_in;

logic [nIN-1:0] pre_req_out[nPIPE-1:0];
logic [wD*nIN-1:0] pre_data_out[nPIPE-1:0];
logic [(wA_OUT-wA_PIPE)*nIN-1:0] pre_addr_out[nPIPE-1:0];

clk_wiz_0 clock(
	.clk_in1_p(usrclk_p),
	.clk_in1_n(usrclk_n),
	.clk_out1(clk));

always @(posedge clk)
	input_data[0] <= in;

always @(posedge clk)
	output_data[0] <= data_out[0];

generate
	for (i=1; i<wDATA; i++) begin
		always @(posedge clk)
			input_data[i] <= input_data[i-1];
	end

	for (i=1; i<wDATA_OUT; i++) begin
		always @(posedge clk)
			if (rec) output_data[i] <= data_out[i];
			else output_data[i] <= output_data[i-1];
	end
endgenerate

assign out = output_data[wDATA_OUT-1];


// comm_pipe #(.nIN(8), .nOUT(52), .wD(25)) comm_pipe(
// 	.clk(clk),
// 	.reset(reset),
// 	.req_in(input_data[255:248]),
// 	.data_in(input_data[199:0]),
// 	.addr_in(input_data[247:200]),
// 	.req_out(data_out[1351:1300]),
// 	.data_out(data_out[1299:0]));

pre_comm_adapter #(.nIN(nIN), .nOUT(nOUT), .wD(wD)) pre_comm_adapter(
	.clk(clk),
	.reset(reset),
	.req_in(input_data[wDATA-1:wDATA-nIN]),
	.data_in(input_data[wD*nIN-1:0]),
	.addr_in(input_data[wDATA-nIN-1:wD*nIN]),
	.req_out(pre_req_in),
	.data_out(pre_data_in),
	.addr_out(pre_addr_in));

pre_comm #(.nIN(nIN), .nOUT(nOUT), .wD(wD), .nPIPE(nPIPE)) pre_comm(
	.clk(clk),
	.reset(reset),
	.req_in(pre_req_in),
	.data_in(pre_data_in),
	.addr_in(pre_addr_in),
	.req_out(pre_req_out),
	.data_out(pre_data_out),
	.addr_out(pre_addr_out));

generate
	for (i=0; i<nPIPE; i++) begin
		comm_pipe #(.nIN(nIN), .nOUT(nOUT/nPIPE), .wD(wD)) comm_pipe(
		.clk(clk),
		.reset(reset),
		.req_in(pre_req_out[i]),
		.data_in(pre_data_out[i]),
		.addr_in(pre_addr_out[i]),
		.req_out(data_out[(i+1)*(wD+1)*nOUT/nPIPE-1:i*(wD+1)*nOUT/nPIPE+wD*nOUT/nPIPE]),
		.data_out(data_out[i*(wD+1)*nOUT/nPIPE+wD*nOUT/nPIPE-1:i*(wD+1)*nOUT/nPIPE]));
end
endgenerate

endmodule
