`timescale 1ns / 1ps
module neuron_module #(parameter NEURON_NUMBER=256, ACTIVITY_WIDTH=9, REFRACTORY_WIDTH=4, REFRACTORY_PER=4, TS_WIDTH=16)
// ACTIVITY_WIDTH 		- number of bits for encoding activity
// REFRACTORY_WIDTH		- number of bits for encoding refractory state
// REFRACTORY_PER 		- refractory period measured in dT
	(input logic clk, reset,
	 //external access signals
	 input logic ext_req,													// external memory access request
	 output logic ext_ack,													// acknowledge external access request
	 input logic ext_we, ext_re,											// external write and read enable
	 input logic [$clog2(NEURON_NUMBER)-1:0] ext_neur_addr,					// external access address
	 input logic [NEUR_WIDTH-1:0] ext_neur_data_in,
	 output logic [NEUR_WIDTH-1:0] ext_neur_data_out,
	 input logic sys_en,													// flag for enabling the system operation
	 output logic module_busy,												// indicates that external access will be ignored
	 output logic spike_out,
	 output logic [(TS_WIDTH+$clog2(NEURON_NUMBER))-1:0] event_out						// time stamp + neuron address
	 );

localparam NEUR_WIDTH = ACTIVITY_WIDTH + REFRACTORY_WIDTH;					// number of bits per neuron
localparam DT = 100000;														// number of clock cycles to wait for 1 ms

// ----------------------------------------------------------------------------
// Main neuron memory; external and internal access definitions
// ----------------------------------------------------------------------------
logic [NEUR_WIDTH-1:0] neur_ram [NEURON_NUMBER-1:0];
logic [$clog2(NEURON_NUMBER)-1:0] int_neur_wr_addr, int_neur_rd_addr;		// internal neuron address
logic [NEUR_WIDTH-1:0] int_neur_data_in;									// internal data applied to neuron memory
logic int_re, int_we;														// internal read and write enable
logic [$clog2(NEURON_NUMBER)-1:0] neur_wr_addr, neur_rd_addr;	
logic [NEUR_WIDTH-1:0] neur_data_in, neur_data_out;
logic neur_re, neur_we;														// read and write enable to the memory

assign neur_we = ext_access ? ext_we : int_we;
assign neur_re = ext_access ? ext_re : int_re;
assign neur_wr_addr = ext_access ? ext_neur_addr : int_neur_wr_addr;
assign neur_rd_addr = ext_access ? ext_neur_addr : int_neur_rd_addr;
assign neur_data_in = ext_access ? ext_neur_data_in : int_neur_data_in;

always @(posedge clk)
	if (neur_we) neur_ram[neur_wr_addr] <= neur_data_in;

always @(posedge clk)
	if (reset) neur_data_out <= 0;
	else if (neur_re) neur_data_out <= neur_ram[neur_rd_addr];

assign ext_neur_data_out = neur_data_out;

// ----------------------------------------------------------------------------
// dT counter (1 ms); responsible for system's time resolution
// ----------------------------------------------------------------------------
logic [$clog2(DT)-1:0] dt_count, dt_count_free;
logic dt_tick, dt_tick_free;
// Comment: _free versions run independently of sys_en and are only used for time stamping

always @(posedge clk)
	if (reset|dt_tick) dt_count <= 0;
	else if (sys_en) dt_count <= dt_count + 1;

assign dt_tick = (dt_count == DT-1);

always @(posedge clk)
	if (reset|dt_tick_free) dt_count_free <= 0;
	else dt_count_free <= dt_count_free + 1;

assign dt_tick_free = (dt_count_free == DT-1);

// ----------------------------------------------------------------------------
// Memory scrolling counter;
// Sequentially reads out all memory entries every dT (1 ms)
// ---------------------------------------------------------------------------- 
logic [$clog2(NEURON_NUMBER+1)-1:0] scroll_count;
logic scroll_on;															// asserted when scrolling through the memory

assign scroll_on = (scroll_count < NEURON_NUMBER) & sys_en;

always @(posedge clk)
	if (reset) scroll_count <= NEURON_NUMBER;
	else if (sys_en) scroll_count <= dt_tick ? 0 : (scroll_on ? scroll_count + 1 : scroll_count);

// ----------------------------------------------------------------------------
// Internal neuron memory addressing
// ----------------------------------------------------------------------------
logic poisson_en;
logic [$clog2(NEURON_NUMBER)-1:0] int_neur_rd_addr_d;

assign int_neur_rd_addr = scroll_count[$clog2(NEURON_NUMBER)-1:0];
assign int_re = scroll_on;

// delaying addresses
always @(posedge clk)
	if (reset) begin
		int_neur_rd_addr_d <= 0;
		int_neur_wr_addr <= 0;
	end
	else if (sys_en) begin
		int_neur_rd_addr_d <= int_neur_rd_addr;
		int_neur_wr_addr <= int_neur_rd_addr_d;							// write address is two clock cycles delayed from the read address (1 clk for reading from memory and 1 clk for poisson module processing)		
	end

// delaying control signlas
always @(posedge clk)
	if (reset) begin
		poisson_en <= 0;
		int_we <= 0;
	end
	else begin
		poisson_en <= int_re;
		int_we <= poisson_en;
	end

// ----------------------------------------------------------------------------
// Poisson module
// ----------------------------------------------------------------------------
logic spike;															// internal spike

poisson_module #(.ACTIVITY_WIDTH(ACTIVITY_WIDTH), .REFRACTORY_WIDTH(REFRACTORY_WIDTH), .REFRACTORY_PER(REFRACTORY_PER)) poisson_module (
	.clk(clk),
	.reset(reset),
	.poisson_en(poisson_en),
	.poisson_in(neur_data_out),
	.poisson_out(int_neur_data_in),
	.spike(spike));

assign module_busy = (int_re|int_we) & sys_en;							// prevent external access when memory is being read or written by internal modules
assign ext_access = ext_req & ~module_busy;								
assign ext_ack = ext_access;

// ----------------------------------------------------------------------------
// Time stamping output data
// ----------------------------------------------------------------------------
logic [TS_WIDTH-1:0] time_stamp;

always @(posedge clk)
	if (reset) time_stamp <= 0;
	else if (dt_tick_free) time_stamp <= time_stamp + 1'b1;

always @(posedge clk)
	if (reset) spike_out <= 0;
	else spike_out <= spike;

always @(posedge clk)
	if (reset) event_out <= 0;
	else if (spike) event_out <= {time_stamp, int_neur_wr_addr};

// ----------------------------------------------------------------------------
// Initialization
// ----------------------------------------------------------------------------
initial begin
	dt_count = 0;
	scroll_count = 0;
	poisson_en = 0;
	int_we = 0;
	int_neur_rd_addr_d = 0;
	int_neur_wr_addr = 0;
	neur_data_out = 0;

	for (int i=0; i<NEURON_NUMBER; i++) begin
		if (i==10) neur_ram[i] = {9'd511, 4'b0};
		else neur_ram[i] = 0;
	end

	dt_count_free = 0;
	time_stamp = 0;
	spike_out = 0;
	event_out = 0;

end

endmodule
