// Pipelined commutator for transferring data from nIN inputs to nOUT endpoints.
`timescale 1ns / 1ps
module comm_pipe #(parameter nIN=8, nOUT=13, wD=25)
// nIN - number of input channels
// nOUT - number of commutator output channels
// wD - data width
	// (input logic usrclk_p, usrclk_n, reset,
	(input logic clk, reset,
	 input logic [nIN-1:0] req_in,
	 input logic [nIN*wD-1:0] data_in,						// input data combined over nIN channels
	 input logic [nIN*wA_OUT-1:0] addr_in,					// output channel address for each input channel
	 output logic [nOUT-1:0] req_out,
	 output logic [nOUT*wD-1:0] data_out);					// output data combined over nOUT channels

localparam wA_OUT = $clog2(nOUT);							// output channel address width

genvar i, ii;

generate
	for (i=0; i<nIN; i++) begin: regs
		logic [nIN-1:0] req_in_reg;
		logic [(nIN-i)*wD-1:0] data_in_reg;						// registers delaying input data for each pipeline stage
		logic [(nIN-i)*wA_OUT-1:0] addr_in_reg;					// registers delaying output channel addresses for input data
	end
endgenerate

logic [nOUT*wD-1:0] comm_reg[nIN-1:0];						// commutator registers; data_in is distributed among them according to addr_in
logic [nOUT-1:0] comm_req_reg[nIN-1:0];						// registers for passing validity flags to the output
logic [nOUT-1:0] comm_reg_en[nIN-1:0];						// enables one register in accordance with the addr_in in the corresponding pipeline stage
logic [nOUT-1:0] comm_reg_en_d[nIN-1:0];	

logic [nIN*wD-1:0] data_in_d;

generate
// -------- Initial pipeline stage -------- 	
	for (ii=0; ii<nIN; ii++) begin
		always @(posedge clk)
			if (reset) begin
				regs[0].addr_in_reg[(ii+1)*wA_OUT-1:ii*wA_OUT] <= 0;
				data_in_d[(ii+1)*wD-1:ii*wD] <= 0;
			end
			else if (req_in[ii]) begin
				regs[0].addr_in_reg[(ii+1)*wA_OUT-1:ii*wA_OUT] <= addr_in[(ii+1)*wA_OUT-1:ii*wA_OUT];
				data_in_d[(ii+1)*wD-1:ii*wD] <= data_in[(ii+1)*wD-1:ii*wD];
			end

		always @(posedge clk)
			if (reset) regs[0].data_in_reg[(ii+1)*wD-1:ii*wD] <= 0;
			else regs[0].data_in_reg[(ii+1)*wD-1:ii*wD] <= data_in_d[(ii+1)*wD-1:ii*wD];

		always @(posedge clk)
			if (reset) regs[0].req_in_reg[ii] <= 0;
			else regs[0].req_in_reg[ii] <= req_in[ii];
	end
	
	always_comb begin										// address decoder for the corresponding pipeline stage
		comm_reg_en[0] = 0;
		comm_reg_en[0][regs[0].addr_in_reg[nIN*wA_OUT-1:(nIN-1)*wA_OUT]] = regs[0].req_in_reg[nIN-1];
	end

	always @(posedge clk)
		if (reset) comm_reg_en_d[0] <= 0;
		else comm_reg_en_d[0] <= comm_reg_en[0];
	
	for (ii=0; ii<nOUT; ii++) begin							// commutator registers
		always @(posedge clk)
			if (reset) comm_reg[0][(ii+1)*wD-1:ii*wD] <= 0;
			else if (comm_reg_en_d[0][ii]) comm_reg[0][(ii+1)*wD-1:ii*wD] <= regs[0].data_in_reg[nIN*wD-1:(nIN-1)*wD];

		always @(posedge clk)
			if (reset|~comm_reg_en_d[0][ii]) comm_req_reg[0][ii] <= 0;
			else if (comm_reg_en_d[0][ii]) comm_req_reg[0][ii] <= 1;
	end

// -------- Following pipeline stages --------
	for (i=1; i<nIN; i++) begin: mainPIPE
		for (ii=0; ii<nIN-i; ii++) begin
			always @(posedge clk)
				if (reset) begin
					regs[i].data_in_reg[(ii+1)*wD-1:ii*wD] <= 0;
					regs[i].addr_in_reg[(ii+1)*wA_OUT-1:ii*wA_OUT] <= 0;
				end
				else begin
					regs[i].data_in_reg[(ii+1)*wD-1:ii*wD] <= regs[i-1].data_in_reg[(ii+1)*wD-1:ii*wD];
					regs[i].addr_in_reg[(ii+1)*wA_OUT-1:ii*wA_OUT] <= regs[i-1].addr_in_reg[(ii+1)*wA_OUT-1:ii*wA_OUT];
				end

			always @(posedge clk)
				if (reset) regs[i].req_in_reg[ii] <= 0;
				else regs[i].req_in_reg[ii] <= regs[i-1].req_in_reg[ii];
		end

		always_comb begin									// address decider for the corresponding pipeline stage
			comm_reg_en[i] = 0;
			comm_reg_en[i][regs[i].addr_in_reg[(nIN-i)*wA_OUT-1:(nIN-i-1)*wA_OUT]] = regs[i].req_in_reg[nIN-i-1];
		end

		always @(posedge clk)
			if (reset) comm_reg_en_d[i] <= 0;
			else comm_reg_en_d[i] <= comm_reg_en[i];

		for (ii=0; ii<nOUT; ii++) begin						// commutator registers
			always @(posedge clk)
				if (reset) begin
					comm_reg[i][(ii+1)*wD-1:ii*wD] <= 0;
					comm_req_reg[i][ii] <= 0;
				end
				else begin
					comm_reg[i][(ii+1)*wD-1:ii*wD] <= comm_reg_en_d[i][ii] ? regs[i].data_in_reg[(nIN-i)*wD-1:(nIN-i-1)*wD]:comm_reg[i-1][(ii+1)*wD-1:ii*wD];
					comm_req_reg[i][ii] <= comm_reg_en_d[i][ii] ? 1:comm_req_reg[i-1][ii];
				end
		end
	end
endgenerate

assign data_out = comm_reg[nIN-1];
assign req_out = comm_req_reg[nIN-1];

// Initialization
initial begin
	data_in_d = 0;
	for (int k=0; k<nIN; k++) begin
		// regs[k].data_in_reg = 0;
		// regs[k].addr_in_reg = 0;
		// regs[k].req_in_reg = 0;
		comm_req_reg[k] = 0;
		comm_reg[k] = 0;
		comm_reg_en[k] = 0;
	end
end

endmodule
