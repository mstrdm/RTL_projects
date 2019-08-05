--------------------------------------------------------------------------------
-- UART receiver module.

-- Parameter CK_PER_BIT is equal to the number of clock cycles per single
-- bit transmission time.
-- E.g.: if data transmission rate is 115200 and clock speed is set to 100 MHz, 
-- CK_PER_BIT = ceil(100e6/115200) = 869
--------------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;
use IEEE.MATH_REAL.ALL;

entity uart_rx is
	generic (
		CK_PER_BIT 			: integer 							:= 869);			-- number of internal clock cycles per single UART bit transmission

	port (
		clk, reset 			: in std_logic;
		-- uart interface
		rx_in 				: in std_logic;
		-- user interface
		rx_done 			: out std_logic;
		data_out 			: out std_logic_vector(7 downto 0));
end;

architecture synth of uart_rx is
	type state_t is (s_idle, s_start, s_sample, s_end);
	signal rx_state 		: state_t 							:= s_idle;
	signal count_sample		: integer range 0 to 7				:= 0;
	signal count_mid		: integer range 0 to CK_PER_BIT 	:= 0;			-- counter width for counting clock cycles
	signal rx_in_temp 		: std_logic 						:= '0';
	signal rx_in_sync 		: std_logic 						:= '0';

begin
	
	-- synchronizer for input signal
	process (clk) begin
		if rising_edge (clk) then
			if (reset = '1') then
				rx_in_temp <= '1';
				rx_in_sync <= '1';
			else
				rx_in_temp <= rx_in;
				rx_in_sync <= rx_in_temp;
			end if;
		end if;
	end process;

	-- state register
	process (clk) begin
		if rising_edge (clk) then
			if (reset = '1') then 
				rx_state <= s_idle;
				count_mid <= 0;
				count_sample <= 0;
				rx_done <= '0';
				data_out <= (others => '0');
			else
				case rx_state is
					-- CONTROLLER IS IDLE
					when s_idle =>
						rx_done <= '0';
						if rx_in_sync = '0' then 
							rx_state <= s_start;
						else rx_state <= s_idle;
						end if;

					-- BEGINNING OF TRANSMISSION HAS BEEN DETECTED
					when s_start =>
						if (count_mid < CK_PER_BIT/2-1) then count_mid <= count_mid + 1;
						else
							if (rx_in_sync = '1') then rx_state <= s_idle;
							else
								count_mid <= 0;
								count_sample <= 0;
								rx_state <= s_sample;
							end if;
						end if;

					-- SAMPLING DATA
					when s_sample =>
						if (count_mid < CK_PER_BIT-1) then count_mid <= count_mid + 1;
						else
							count_mid <= 0;
							data_out(count_sample) <= rx_in_sync;
							if (count_sample = 7) then
								rx_state <= s_end;
							else 
								rx_state <= s_sample;
							end if;
							count_sample <= count_sample + 1;
						end if;

					-- FINALIZING
					when s_end =>
						if (count_mid < CK_PER_BIT-1) then 
							count_mid <= count_mid + 1;
						else
							count_mid <= 0;
							rx_state <= s_idle;
							rx_done <= '1';
						end if;

				end case;
			end if;
		end if;
	end process;

end architecture synth;