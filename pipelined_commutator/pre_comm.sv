// Precommutator circuit -- distributes input data among four parallel commutator pipelines.
// WARNING: This module only works correctly with nOUT = 2**n. If nOUT is arbitrary, use comm_addr_adapter module at the input.
`timescale 1ns / 1ps
module pre_comm #(parameter nIN=8, nOUT=52, wD=25, nPIPE=4)
// nIN - number of input channels
// nOUT - number of commutator output channels
// wD - data width
// nPIPE - number of parallel commutator pipelines
	(input logic clk, reset,
	 input logic [nIN-1:0] req_in,
	 input logic [wD*nIN-1:0] data_in,
	 input logic [wA_OUT*nIN-1:0] addr_in,
	 output logic [nIN-1:0] req_out[nPIPE-1:0],
	 output logic [wD*nIN-1:0] data_out[nPIPE-1:0],
	 output logic [wA_CH*nIN-1:0] addr_out[nPIPE-1:0]);

genvar i, ii;

localparam wA_OUT = $clog2(nOUT);											// output channel address width
localparam wA_PIPE = $clog2(nPIPE);											// pipeline address width
localparam wA_CH = wA_OUT - wA_PIPE;

logic [wD-1:0] data_in_reg[nIN-1:0];										// prestoring input data
logic [nIN-1:0] req_in_reg;													// prestoring input requests
logic [wA_OUT-1:0] addr_in_reg[nIN-1:0];									// prestoring full output channel addresses
logic [wA_PIPE-1:0] pipe_addr[nIN-1:0];										// pipeline addresses separated from full addresses
logic [wA_CH-1:0] ch_addr[nIN-1:0];											// channel addresses without pipeline address parts
logic [nPIPE-1:0] pipe_addr_dec[nIN-1:0];									// decoded pipeline address

// Pipelining for improved performance
logic [wA_PIPE-1:0] pipe_addr_d[nIN-1:0];
logic [wA_CH-1:0] ch_addr_d[nIN-1:0];
logic [wD-1:0] data_in_reg_d[nIN-1:0]; 
logic [nPIPE-1:0] pipe_addr_dec_d[nIN-1:0];

generate
	for (i=0; i<nIN; i++) begin
// ---- Prestoring input data and channel addresses ----
		always @(posedge clk)
			if (reset) begin
				data_in_reg[i] <= 0;
				addr_in_reg[i] <= 0;
			end
			else if (req_in[i]) begin
				data_in_reg[i] <= data_in[(i+1)*wD-1:i*wD];
				addr_in_reg[i] <= addr_in[(i+1)*wA_OUT-1:i*wA_OUT];
			end

			always @(posedge clk)
				if (reset) req_in_reg[i] <= 0;
				else req_in_reg[i] <= req_in[i];

// ---- Pipelining delays ----
			always @(posedge clk)
				if (reset) begin
					ch_addr_d[i] <= 0;
					pipe_addr_dec_d[i] <= 0;
					data_in_reg_d[i] <= 0;
				end
				else begin
					ch_addr_d[i] <= ch_addr[i];
					pipe_addr_dec_d[i] <= pipe_addr_dec[i];
					data_in_reg_d[i] <= data_in_reg[i];
				end

// ---- Separating and decoding pipeline addresses ----
		assign pipe_addr[i] = addr_in_reg[i][wA_OUT-1:wA_CH];
		assign ch_addr[i] = addr_in_reg[i][wA_CH-1:0];

		always_comb begin
			pipe_addr_dec[i] = 0;
			pipe_addr_dec[i][pipe_addr[i]] = req_in_reg[i];
		end

// ---- Writing data to output registers ----
		for (ii=0; ii<nPIPE; ii++) begin
			always @(posedge clk)
				if (reset) begin
					data_out[ii][(i+1)*wD-1:i*wD] <= 0;
					addr_out[ii][(i+1)*wA_CH-1:i*wA_CH] <= 0;
				end
				else if (pipe_addr_dec_d[i][ii]) begin
					data_out[ii][(i+1)*wD-1:i*wD] <= data_in_reg_d[i];
					addr_out[ii][(i+1)*wA_CH-1:i*wA_CH] <= ch_addr_d[i];
				end

			always @(posedge clk)
				if (reset) req_out[ii][i] <= 0;
				else req_out[ii][i] <= pipe_addr_dec_d[i][ii];
		end
	end
endgenerate

// Initialization
initial begin
	for (int k=0; k<nIN; k++) begin
		data_in_reg[k] = 0;
		addr_in_reg[k] = 0;
		req_in_reg[k] = 0;
		ch_addr[k] = 0;
		ch_addr_d[k] = 0;
		pipe_addr_dec[k] = 0;
		pipe_addr_dec_d[k] = 0;
		data_in_reg_d[k] = 0;
	end

	for (int k=0; k<nPIPE; k++) begin
		data_out[k] = 0;
		addr_out[k] = 0;
		req_out[k] = 0;
	end
end

endmodule
