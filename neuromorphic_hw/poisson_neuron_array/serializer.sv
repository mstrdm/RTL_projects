// Module for serializing data.
// NOTE: Input data width should be equal to a whole number times output data width (e.g. IN_W = 3*OUT_W)
`timescale 1ns / 1ps
module serializer #(IN_W=24, OUT_W=8)
	(input logic clk, reset,
	 input logic wr, next,
	 input logic [IN_W-1:0] data_in,
	 output logic data_out_val,
	 output logic [OUT_W-1:0] data_out);

localparam N_REG = IN_W/OUT_W;			// number of registers

genvar i;

logic [OUT_W-1:0] data_reg [N_REG-1:0];	// defining data registers
logic valid_reg [N_REG-1:0];			// validity register

generate
	for (i=0; i<N_REG; i++) begin: shift_reg
		always @(posedge clk)
			if (reset) valid_reg[i] <= 0;
			else if (wr) valid_reg[i] <= 1;
			else if (next) valid_reg[i] <= (i==0) ? 0 : valid_reg[i-1];

		always @(posedge clk)
			if (reset) data_reg[i] <= 0;
			else if (wr) data_reg[i] <= data_in[(i+1)*OUT_W-1:i*OUT_W];
			else if (next) data_reg[i] <= (i==0) ? 0 : data_reg[i-1];
	end
endgenerate

assign data_out = data_reg[N_REG-1];
assign data_out_val = valid_reg[N_REG-1];

initial begin
	for (int k=0; k<N_REG; k++) begin
		valid_reg[k] = 0;
		data_reg[k] = 0;
	end
end

endmodule
