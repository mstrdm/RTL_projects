`timescale 1ns / 1ps
module tb_fifo ();

localparam DATA_WIDTH = 8;
localparam ADDR_WIDTH = 7;

logic clk;
logic wr, rd;
logic [DATA_WIDTH-1:0] data_in, data_out;
logic fifo_full, fifo_empty;


fifo #(.DATA_WIDTH(DATA_WIDTH), .ADDR_WIDTH(ADDR_WIDTH)) fifo_under_test (
	.*,
	.reset(0));


always begin
	clk=0; #5; clk=1; #5;
end


initial begin
	wr = 0;
	rd = 0;
	data_in = 8'hAA;
	#10;

	wr = 1; #10; wr = 0; #100;

	for (int i=0; i<300; i++) begin
		data_in = data_in + 1;
		wr = 1;
		#10;
		wr = 0;
		#100;
	end

	// for (int i=0; i<15; i++) begin
	// 	rd = 1;
	// 	#10;
	// 	rd = 0;
	// end



end


endmodule
