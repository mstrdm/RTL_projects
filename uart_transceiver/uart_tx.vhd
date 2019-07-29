--------------------------------------------------------------------------------
-- UART transmitter module.

-- Parameter CK_PER_BIT is equal to the number of clock cycles per single
-- bit transmission time.
-- E.g.: if data transmission rate is 115200 and clock speed is set to 100 MHz, 
-- CK_PER_BIT = ceil(100e6/115200) = 869
--------------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity uart_tx is
	generic (
		CK_PER_BIT 			: integer 							:= 869);

	port (
		clk					: in std_logic;
		reset				: in std_logic;
		-- uart interface
		tx_out				: out std_logic;
		-- user interface
		data_req			: in std_logic;												-- request to send the data
		data_in				: in std_logic_vector (7 downto 0);							-- data to be sent
		tx_busy				: out std_logic);											-- controller is busy sending data
end uart_tx;

architecture synth of uart_tx is
	type state_t is (s_idle, s_start, s_transmit, s_end);
	signal tx_state			: state_t							:= s_idle;
	signal count_sample		: integer range 0 to 7				:= 0;
	signal count_bit_time	: integer range 0 to CK_PER_BIT-1	:= 0;
	signal data_in_reg		: std_logic_vector (7 downto 0)		:= (others => '0');

begin
	
	process (tx_state, count_sample, data_in_reg) begin
		case (tx_state) is
			when (s_idle) =>
				tx_out <= '1';
				tx_busy <= '0';
			when (s_start) => 
				tx_out <= '0';
				tx_busy <= '1';
			when (s_transmit) =>
				tx_out <= data_in_reg(count_sample);
				tx_busy <= '1';
			when (s_end) =>
				tx_out <= '1';
				tx_busy <= '1';
		end case;
	end process;

	process (clk) begin
		if rising_edge (clk) then
			if (reset = '1') then
				tx_state <= s_idle;
				data_in_reg <= (others => '0');
				count_sample <= 0;
				count_bit_time <= 0;

			else
				case (tx_state) is
					-- Controller is in IDLE state
					when (s_idle) =>
						if (data_req = '1') then
							tx_state <= s_start;
							count_bit_time <= 0;
							data_in_reg <= data_in;										-- recording data
						end if;

					-- Controller is sending the starting bit (pulling tx line low)
					when (s_start) =>
						if (count_bit_time = CK_PER_BIT-1) then
							tx_state <= s_transmit;
							count_bit_time <= 0;
							count_sample <= 0;
						else
							count_bit_time <= count_bit_time + 1;
						end if;

					-- Controller is transmitting data
					when (s_transmit) =>
						if (count_bit_time = CK_PER_BIT-1) then
							count_bit_time <= 0;
							if (count_sample = 7) then
								tx_state <= s_end;
							else
								count_sample <= count_sample + 1;
							end if;
						else
							count_bit_time <= count_bit_time + 1;
						end if;

					-- Controller is sending "stop" bit
					when (s_end) =>
						if (count_bit_time = CK_PER_BIT-1) then
							tx_state <= s_idle;
						else
							count_bit_time <= count_bit_time + 1;
						end if;

				end case;
			end if;
		end if;
	end process;

end synth;
