`timescale 1ns / 1ps
module fifo #(parameter DATA_WIDTH=16, ADDR_WIDTH=7)
// DATA_WIDTH - width of data to be stored in FIFO
// ADDR_WIDTH - defines FIFO depth
	(input logic clk, reset,
	 input logic wr, rd,							// write and read commands
	 input logic [DATA_WIDTH-1:0] data_in,
	 output logic fifo_full, fifo_empty,			// full and empty flags
	 output logic [DATA_WIDTH-1:0] data_out);

// FIFO RAM
logic [DATA_WIDTH-1:0] fifo_mem [2**ADDR_WIDTH-1:0];
logic wr_en, rd_en;									// write and read enable
logic [ADDR_WIDTH-1:0] wr_ptr, rd_ptr;				// RAM read and write addresses
// Flags
logic empty_int, empty_int_d;						// integral empty signal and its delayed version
// Pointers
logic [ADDR_WIDTH:0] ptr_dist;						// distance between read and write pointers
logic wr_d;
logic rd_en_int, rd_en_ext;							// internal and external read enable signals


always @(posedge clk)
	if (wr_en) fifo_mem[wr_ptr] <= data_in;

always @(posedge clk)
	if (reset) data_out <= 0;
	else if (rd_en) data_out <= fifo_mem[rd_ptr];

// Flags
assign empty_int = ptr_dist == 0;
assign fifo_full = ptr_dist == 2**ADDR_WIDTH;		// fifo is full when we wrap around our address space

always @(posedge clk)
	if (reset) empty_int_d <= 1;
	else empty_int_d <= empty_int;

assign fifo_empty = empty_int|empty_int_d;			// going down with empty_int_d and going up with empty_int

// Pointers
always @(posedge clk)
	if (reset) ptr_dist <= 0;
	else if (wr_en^rd_en_ext) ptr_dist <= rd_en ? ptr_dist - 1'b1 : ptr_dist + 1'b1;

assign wr_en = ~fifo_full & wr;
assign rd_en_ext = (~empty_int & rd);
assign rd_en_int = (empty_int_d & wr_d);
assign rd_en = rd_en_ext|rd_en_int;					// (normal_read_condition)|(premature_read_condition)

always @(posedge clk)
	if (reset) wr_d <= 0;
	else wr_d <= wr;								// delaying wr for premature read (after we do first write)

always @(posedge clk)
	if (reset) wr_ptr <= 0;
	else if (wr_en) wr_ptr <= wr_ptr + 1'b1;

always @(posedge clk)
	if (reset) rd_ptr <= 0;
	else if (rd_en_int|(rd_en_ext&(ptr_dist>1))) rd_ptr <= rd_ptr + 1'b1;


// Initialization
initial begin
	data_out = 0;
	ptr_dist = 0;
	empty_int_d = 1;
	wr_d = 0;
	wr_ptr = 0;
	rd_ptr = 0;

	for (int i=0; i<2**ADDR_WIDTH; i++) begin
		fifo_mem[i] = 0;
	end

end

endmodule