`timescale 1ns / 1ps
module system_top 
	(input logic usrclk_n, usrclk_p,
	 output logic fifo_full_led,
	 output logic tx_out);

localparam NEURON_NUMBER = 256;
localparam ACTIVITY_WIDTH = 9;
localparam REFRACTORY_WIDTH = 4;
localparam REFRACTORY_PER = 4;
localparam NEUR_WIDTH = ACTIVITY_WIDTH + REFRACTORY_WIDTH;
localparam TS_WIDTH = 16;

logic clk, reset;
logic ext_req, ext_ack;
logic ext_we, ext_re;
logic [$clog2(NEURON_NUMBER)-1:0] ext_neur_addr;
logic [NEUR_WIDTH-1:0] ext_neur_data_in;
logic [NEUR_WIDTH-1:0] ext_neur_data_out;
logic sys_en;
logic module_busy;
logic spike;
logic [(TS_WIDTH+$clog2(NEURON_NUMBER))-1:0] event_out, fifo_out_data;
// fifo signals
logic fifo_full, fifo_empty;
// serializer signals
logic ser_out_val;
logic [7:0] ser_out_data;
logic ser_next;
logic ser_wr;
// uart signals
logic tx_busy;

assign reset = 0;
assign ext_req = 0;
assign ext_we = 0;
assign ext_re = 0;
assign ext_neur_addr = 0;
assign ext_neur_data_in = 0;
assign sys_en = 1;

clk_wiz_0 xilinx_clock (
	.clk_in1_n(usrclk_n),
	.clk_in1_p(usrclk_p),
	.clk_out1(clk));

neuron_module #(
	.NEURON_NUMBER(NEURON_NUMBER),
	.ACTIVITY_WIDTH(ACTIVITY_WIDTH),
	.REFRACTORY_WIDTH(REFRACTORY_WIDTH),
	.REFRACTORY_PER(REFRACTORY_PER),
	.TS_WIDTH(TS_WIDTH)) neuron_module_under_test (
	.clk(clk),
	.reset(reset),
	.ext_req(ext_req),
	.ext_ack(ext_ack),
	.ext_we(ext_we),
	.ext_re(ext_re),
	.ext_neur_addr(ext_neur_addr),
	.ext_neur_data_in(ext_neur_data_in),
	.ext_neur_data_out(ext_neur_data_out),
	.sys_en(sys_en),
	.module_busy(module_busy),
	.spike_out(spike),
	.event_out(event_out));

fifo #(.DATA_WIDTH(TS_WIDTH+$clog2(NEURON_NUMBER)), .ADDR_WIDTH(8)) output_fifo (
	.clk(clk),
	.reset(reset),
	.wr(spike),
	.rd(ser_wr),
	.data_in(event_out),
	.fifo_full(fifo_full),
	.fifo_empty(fifo_empty),
	.data_out(fifo_out_data));

assign fifo_full_led = fifo_full;

serializer #(.IN_W(TS_WIDTH+$clog2(NEURON_NUMBER)), .OUT_W(8)) output_ser (
	.clk(clk),
	.reset(reset),
	.wr(ser_wr),
	.next(ser_next),
	.data_in(fifo_out_data),
	.data_out_val(ser_out_val),
	.data_out(ser_out_data));

assign ser_wr = ~ser_out_val & ~fifo_empty;		// we should not be sending anything and something should be at fifo's output
assign ser_next = ~tx_busy & ser_out_val;		// when uart_tx is not busy and we have valid data at serializer's output, it will always be passed to the uart module at the next clock cycle

uart_tx #(.CK_PER_BIT(869)) uart_tx (
	.clk(clk),
	.reset(0),
	.tx_out(tx_out),
	.data_req(ser_out_val),
	.data_in(ser_out_data),
	.tx_busy(tx_busy));


endmodule
