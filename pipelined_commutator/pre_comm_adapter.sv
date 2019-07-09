// Module for adapting addresses to be used with arbitrary number of output channels in the commutator.
// This module is only required if pre_comm module is used.
// E.g.: If commutator has 40 output channels and two parallel pipelines, we want each pipeline to handle 20;
//		 Without adapter, distributuon would be 32 in the first and 8 in the second pipeline.
// WARNING: This module is specifically designed for only two parallel pipelines.
`timescale 1ns / 1ps
module pre_comm_adapter #(parameter nIN=8, nOUT=52, wD=25)
// nIN - number of input channels
// nOUT - number of commutator output channels
// wD - data width
	(input logic clk, reset,
	 input logic [nIN-1:0] req_in,
	 input logic [wD*nIN-1:0] data_in,
	 input logic [wA_OUT*nIN-1:0] addr_in,
	 output logic [nIN-1:0] req_out,
	 output logic [wD*nIN-1:0] data_out,
	 output logic [wA_OUT*nIN-1:0] addr_out);

localparam wA_OUT = $clog2(nOUT);								// output channel address width
localparam nCH = nOUT/2;
localparam wA_CH = $clog2(nCH);

genvar i;

logic [wA_OUT-1:0] addr_in_reg[nIN-1:0];

generate
	for (i=0; i<nIN; i++) begin
		always @(posedge clk)
			if (reset) begin
				data_out[(i+1)*wD-1:i*wD] <= 0;
				addr_in_reg[i] <= 0;
			end
			else if (req_in[i]) begin
				data_out[(i+1)*wD-1:i*wD] <= data_in[(i+1)*wD-1:i*wD];
				addr_in_reg[i] <= addr_in[(i+1)*wA_OUT-1:i*wA_OUT];
			end

		always @(posedge clk)
			if (reset) req_out[i] <= 0;
			else req_out[i] <= req_in[i];

		// OUTPUT IS NOT PIPELINED SINCE IT DIRECTLY TRAVELS TO THE INPUT REG OF pre_comm MODULE
		assign addr_out[(i+1)*wA_OUT-1:i*wA_OUT] = (addr_in_reg[i] >= nCH) ? (addr_in_reg[i] + (2**wA_CH-nCH)):addr_in_reg[i];
	end
endgenerate

// Initialization
initial
	for (int k=0; k<nIN; k++) begin
		req_out[k] = 0;
		data_out[k] = 0;
		addr_in_reg[k] = 0;
	end

endmodule
