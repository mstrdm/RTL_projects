// Contains state machine for controlling the system.

`timescale 1ns / 1ps
module system_ctrl #(parameter NEURON_NUMBER=256, ACTIVITY_WIDTH=9, REFRACTORY_WIDTH=4)
	(input logic clk, reset,
	 input logic rx_done,
	 input logic [7:0] rx_data,
	 // neuron_module interface
	 input logic nm_ack,
	 output logic nm_req,
	 output logic [$clog2(NEURON_NUMBER)-1:0] nm_addr,
	 output logic [NEUR_WIDTH-1:0] nm_data,
	 output logic nm_we,
	 // system flags
	 output logic sys_en);

localparam NEUR_WIDTH = ACTIVITY_WIDTH + REFRACTORY_WIDTH;					// number of bits per neuron
localparam cmd_idle = 8'hFF;
localparam cmd_wract = 8'h01;

typedef enum logic [1:0] {idle_s, wract1_s, wract2_s} state_t;
state_t state_reg;
logic fifo_wr;																// writing into fifo from which data is applied to the neuron_module
logic [15:0] fifo_din, fifo_dout;
logic fifo_full, fifo_empty;

fifo #(.DATA_WIDTH(16), .ADDR_WIDTH(8)) nm_fifo (
	.clk(clk),
	.reset(reset),
	.wr(fifo_wr),
	.rd(nm_ack),
	.data_in(fifo_din),
	.fifo_full(fifo_full),
	.fifo_empty(fifo_empty),
	.data_out(fifo_dout));

assign nm_addr = fifo_dout[15:8];
assign nm_data = {1'b0, fifo_dout[7:0], 4'd0};
assign nm_req = ~fifo_empty;
assign nm_we = ~fifo_empty;

always @(posedge clk)
	if (reset) begin
		state_reg <= idle_s;
		sys_en <= 0;
		fifo_din <= 0;
		fifo_wr <= 0;
	end

	else if (rx_done) begin
		case (state_reg)
			idle_s:
				case (rx_data)
					cmd_wract: begin
						state_reg <= wract1_s;
						sys_en <= 1;
					end
					default: begin
						state_reg <= idle_s;
						sys_en <= 0;
					end
				endcase

			wract1_s: begin
				fifo_wr <= 0;
				case (rx_data)
					cmd_idle: begin
						state_reg <= idle_s;
						sys_en <= 0;
					end
					default: begin
						state_reg <= wract2_s;
						fifo_din[15:8] <= rx_data;
					end
				endcase
			end

			wract2_s:
				case (rx_data)
					cmd_idle: begin
						state_reg <= idle_s;
						sys_en <= 0;
					end
					default: begin
						state_reg <= wract1_s;
						fifo_din[7:0] <= rx_data;
						fifo_wr <= ~fifo_full;
					end
				endcase
		endcase
	end

endmodule
