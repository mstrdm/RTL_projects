`timescale 1ns / 1ps
// Module for updating poisson neuron states. It outputs spike and updated refractory values with one clock cycle delay.
// Input: 9b - activity; 4b - refractory state
module poisson_module #(parameter ACTIVITY_WIDTH = 9, REFRACTORY_WIDTH = 4, REFRACTORY_PER = 4)
// REFRACTORY_PER - refractory period measured in dT
	(input logic clk, reset,
	 input logic poisson_en,
	 input logic [NEUR_WIDTH-1:0] poisson_in,
	 output logic [NEUR_WIDTH-1:0] poisson_out,
	 output logic spike);

localparam NEUR_WIDTH = ACTIVITY_WIDTH + REFRACTORY_WIDTH;					// number of bits per neuron
localparam REG_LEN = 16;

logic [REG_LEN-1:0] rnd_lfsr;
logic [ACTIVITY_WIDTH-1:0] activity;
logic [REFRACTORY_WIDTH-1:0] refractory_state_old, refractory_state_new;
logic poisson_cond;															// condition for spiking
logic refractory_over;														// is asserted when refractory state is zero

assign activity = poisson_in[NEUR_WIDTH-1:REFRACTORY_WIDTH];
assign refractory_state_old = poisson_in[REFRACTORY_WIDTH-1:0];

// Note: LFSR generates numbers from 1 to 2**REG_LEN-1 (NOT FROM 0)
lfsr #(.REG_LEN(REG_LEN)) rnd_generator (
	.clk(clk),
	.reset(reset),
	.en(1'b1),
	.lfsr_out(rnd_lfsr));

// Note: We define activity in 0.25Hz incriments (e.g. activity = 3 corresponds to activity_real = 0.75 Hz)
// Poisson spike generator equation: activity_real * dT_real >= random_number(0 to 1)
// Our random numbers are multiplied by 2**16;
// Our activity is multiplied by 2**2;
// We should multiply dT_real by 2**14 to maintain correct time scale.
// Target dT_real = 1 ms x 2**14 = 16.384 ~ 16

// As a result, we need to solve inequality:
// activity*16 >= rnd_lfsr
// Note: in digital systems, multiplication by power of 2 is equivalent to bit shifting, i.e. A*16 is equivalent to A<<4 (shift to the left)

assign poisson_cond = (activity << 4) >= rnd_lfsr;
assign refractory_over = (refractory_state_old == 0);

always @(posedge clk)
	if (reset) spike <= 1'b0;
	else spike <= poisson_en ? (poisson_cond & refractory_over) : 1'b0;

// If refractory state is not zero, then simply decrement it every dT; If it is zero, either leave it at zero (no spike) or set it to refractory period
assign refractory_state_new = refractory_over ? (poisson_cond ? REFRACTORY_PER : 0) : refractory_state_old - 1'b1;

always @(posedge clk)
	if (reset) poisson_out <= 0;
	else if (poisson_en) poisson_out <= {activity, refractory_state_new};

initial begin
	spike = 0;
	poisson_out = 0;
end

endmodule
