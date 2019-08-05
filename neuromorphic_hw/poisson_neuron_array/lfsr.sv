`timescale 1ns / 1ps
module lfsr #(parameter REG_LEN = 16)
	(input logic clk, reset,
	 input logic en,
	 output logic [REG_LEN-1:0] lfsr_out);

genvar i;

logic [REG_LEN-1:0] lfsr_reg;

generate
	for (i=0; i<REG_LEN; i++) begin: LFSR
		if (i==0) begin
			always @(posedge clk)
				if (reset) lfsr_reg[i] <= 1;
				else if (en) lfsr_reg[i] <= lfsr_reg[15]^lfsr_reg[14]^lfsr_reg[12]^lfsr_reg[3];
		end
		else begin
			always @(posedge clk)
				if (reset) lfsr_reg[i] <= 0;
				else if (en) lfsr_reg[i] <= lfsr_reg[i-1];
		end
	end
endgenerate

assign lfsr_out[0] = lfsr_reg[0];
assign lfsr_out[1] = lfsr_reg[15];
assign lfsr_out[2] = lfsr_reg[2];
assign lfsr_out[3] = lfsr_reg[14];

assign lfsr_out[4] = lfsr_reg[10];
assign lfsr_out[5] = lfsr_reg[5];
assign lfsr_out[6] = lfsr_reg[13];
assign lfsr_out[7] = lfsr_reg[7];

assign lfsr_out[8] = lfsr_reg[8];
assign lfsr_out[9] = lfsr_reg[9];
assign lfsr_out[10] = lfsr_reg[4];
assign lfsr_out[11] = lfsr_reg[11];

assign lfsr_out[12] = lfsr_reg[12];
assign lfsr_out[13] = lfsr_reg[6];
assign lfsr_out[14] = lfsr_reg[3];
assign lfsr_out[15] = lfsr_reg[1];

initial begin
	for (int k=1; k<REG_LEN; k++) begin
		lfsr_reg[k] = 0;
	end
	lfsr_reg[0] = 1;
end

endmodule
