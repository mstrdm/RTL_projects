--------------------------------------------------------------------------------
-- Debouncer module.

-- Upon detecting change in the input signal, this debouncer module monitor it 
-- for WAIT_CYCLES clock cycles. The new state is passed to the output only
-- if it is maintained for the entire monitoring period.

-- Optional (SYNCH = True/False) synchronizer is available at the input.
--------------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity DEBOUNCER is
	generic (
		WAIT_CYCLES : natural := 4;
		SYNC : boolean := True);										-- adds syncronyzer (two flops) at the input
	port (
		clk, reset : in std_logic;
		signal_in : in  std_logic;
		signal_out : out std_logic);
end DEBOUNCER;

architecture synth of DEBOUNCER is
	type state_t is (s_idle, s_check);
	signal state_reg : state_t := s_idle;
	signal signal_in_temp, signal_in_sync : std_logic := '0';			-- synchronizer signals
	signal count : integer range 0 to WAIT_CYCLES-1;					-- counter for stability checking
	signal signal_in_int : std_logic := '0';							-- internal signal_in (after synchronizer)
	signal in_reg, out_reg : std_logic := '0';							-- input and output registers

begin
	-- Synchronizer description
	synchronizer : process (clk) begin
		if rising_edge (clk) then
			if reset = '1' then
				signal_in_temp <= '0';
				signal_in_sync <= '0';
			else
				signal_in_temp <= signal_in;
				signal_in_sync <= signal_in_temp;
			end if;
		end if;
	end process synchronizer;

	-- Conditional synchronizer bypass
	sync_on : if SYNC = True generate
		process (signal_in_sync) begin
			signal_in_int <= signal_in_sync;
		end process;
	end generate sync_on;

	sync_off : if SYNC = False generate
		process (signal_in) begin
			signal_in_int <= signal_in;
		end process;
	end generate sync_off;	

	-- State machine for checking stability
	process (clk) begin
		if rising_edge (clk) then
			if reset = '1' then
				count <= 0;
				state_reg <= s_idle;
				in_reg <= '0';
				out_reg <= '0';

			else 
				case state_reg is

					when s_idle =>
						if out_reg /= signal_in_int then
							in_reg <= signal_in_int;
							state_reg <= s_check;
							count <= WAIT_CYCLES-1;
						end if;

					when s_check =>
						if signal_in_int /= in_reg then
							state_reg <= s_idle;
							count <= 0;
						else
							if count = 0 then
								out_reg <= in_reg;
								state_reg <= s_idle;
							else
								count <= count - 1;
							end if;
						end if;
				end case;
			end if;
		end if;
	end process;

-- passing output register value to the port
signal_out <= out_reg;

end architecture synth;
