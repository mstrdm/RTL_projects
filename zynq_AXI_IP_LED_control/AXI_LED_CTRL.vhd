--------------------------------------------------------------------------------
-- Simple AXI4-Lite peripheral for ZYNQ-7000 PS (ZC702 board).

-- This peripheral uses PL to register user button and switch inputs and PS for
-- controlling the LED strip on the ZC702 board based on these inputs.

-- Peripheral register map:
-- 0x00 - led_reg		-- LED status register (written by the PS)
-- 0x04 - dir_reg		-- stores the direction of the active LED shifting
--						   (continuously updated with sw_dir switch state)
-- 0x08 - non_reg		-- stores number of active LEDs (incremented/decremented 
--						   with btn_up and btn_down user buttons)
-- 0x0C - blink_reg		-- stores blinking flag (continuously updated with
--						   sw_blink switch state)

-- Note: This module was designed as a Zynq-7000 AXI interface implementation 
-- practice and carries no other practical importance. 
--------------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;

entity AXI_LED_CTRL is
	generic (
		WAIT_CYCLES		: natural								:= 4;			-- number of clock cycles to wait for debouncing buttton signal
		SYNC 			: boolean								:= True;		-- add/remove synchronizers from button inputs
		C_S_AXI_ADDR_WIDTH : natural							:= 12;			-- address width for addressing module's registers
		C_S_AXI_DATA_WIDTH : natural							:= 32);			

	port (
		-- AXI4-LITE INTERFACE SIGNALS
		-- clock and reset
		S_AXI_ACLK		: in std_logic;
		S_AXI_ARESETN	: in std_logic;
		-- write address channel
		S_AXI_AWADDR	: in std_logic_vector (C_S_AXI_ADDR_WIDTH-1 downto 0);
		S_AXI_AWVALID	: in std_logic;
		S_AXI_AWREADY	: out std_logic;
		-- write data channel
		S_AXI_WDATA		: in std_logic_vector (C_S_AXI_DATA_WIDTH-1 downto 0);
		S_AXI_WSTRB		: in std_logic_vector (3 downto 0);
		S_AXI_WVALID	: in std_logic;
		S_AXI_WREADY	: out std_logic;
		-- read address channel
		S_AXI_ARADDR	: in std_logic_vector (C_S_AXI_ADDR_WIDTH-1 downto 0);
		S_AXI_ARVALID	: in std_logic;
		S_AXI_ARREADY	: out std_logic;
		-- read data channel
		S_AXI_RDATA		: out std_logic_vector (C_S_AXI_DATA_WIDTH-1 downto 0);
		S_AXI_RRESP		: out std_logic_vector (1 downto 0);
		S_AXI_RVALID 	: out std_logic;
		S_AXI_RREADY 	: in std_logic;
		--write response channel
		S_AXI_BRESP 	: out std_logic_vector (1 downto 0);
		S_AXI_BVALID 	: out std_logic;
		S_AXI_BREADY 	: in std_logic;

		-- USER INPUT/OUTPUT SIGNALS
		-- button and switch inputs
		sw_dir			: in std_logic;
		btn_up			: in std_logic;
		btn_down		: in std_logic;
		sw_blink		: in std_logic;
		-- LEDs
		led_out			: out std_logic_vector (7 downto 0));
end AXI_LED_CTRL;



architecture synth of AXI_LED_CTRL is
	-- state machine types and signals
	type state_t is (s_idle, s_perform, s_reply);
	signal rd_state_reg, wr_state_reg: state_t					:= s_idle;		-- write and read state machines use different busses and operate independently

	-- supplementary axi4 signals and registers
	signal wr_addr		: integer;												-- input write address converted to integer
	signal rd_addr		: integer;												-- input read address converted to integer
	signal wr_addr_reg	: std_logic_vector (C_S_AXI_ADDR_WIDTH-1 downto 0);
	--signal rd_addr_reg	: std_logic_vector (31 downto 0);
	signal awready_reg	: std_logic 							:= '1';
	signal wready_reg	: std_logic 							:= '0';
	signal arready_reg	: std_logic 							:= '1';
	signal rdata_reg	: std_logic_vector (C_S_AXI_DATA_WIDTH-1 downto 0)		:= (others => '0');
	signal rresp_reg	: std_logic_vector (1 downto 0)			:= (others => '0');
	signal rvalid_reg 	: std_logic 							:= '0';
	signal bresp_reg 	: std_logic_vector (1 downto 0) 		:= (others => '0');
	signal bvalid_reg 	: std_logic 							:= '0';

	-- axi registers
	signal led_reg 		: std_logic_vector (7 downto 0)			:= (others => '0');
	signal dir_reg 		: std_logic_vector (7 downto 0)			:= (others => '0');
	signal non_reg 		: std_logic_vector (7 downto 0)			:= (others => '0');
	signal blink_reg	: std_logic_vector (7 downto 0)			:= (others => '0');

	component debouncer
		generic (
			WAIT_CYCLES : natural;
			SYNC 		: boolean);
		port (
			clk 		: in std_logic;
			reset 		: in std_logic;
			signal_in 	: in std_logic;
			signal_out 	: out std_logic);
	end component;

	signal btn_up_db	: std_logic;											-- synchronized and debounced button and switch input signals
	signal btn_down_db	: std_logic;
	signal sw_dir_db	: std_logic;
	signal sw_blink_db	: std_logic;

	signal btn_up_temp	: std_logic 							:= '0';			-- required for implementing pulsers (assert signal for only one clk cycle per button press)
	signal btn_down_temp : std_logic							:= '0';

	signal btn_up_pulse : std_logic;
	signal btn_down_pulse : std_logic;

	signal reset 		: std_logic;											-- positive reset

begin
	
wr_addr <= to_integer(unsigned(wr_addr_reg));
rd_addr <= to_integer(unsigned(S_AXI_ARADDR));

--------------------------------------------------------------------------------
-------------------------- AXI4-LITE READ/WRITE CONTROL ------------------------
--------------------------------------------------------------------------------
-- AXI read (data sent to master) FSM
read_fsm : process (S_AXI_ACLK) begin
	if rising_edge (S_AXI_ACLK) then
		if S_AXI_ARESETN = '0' then
			rd_state_reg <= s_idle;
			arready_reg <= '1';													-- ready to receive address
			rvalid_reg <= '0';													-- not ready to receive data (receiving address first)
			rdata_reg <= (others => '0');
			rresp_reg <= (others => '0');
		else
			case rd_state_reg is
				-- waiting for the read command
				when s_idle =>
					if (S_AXI_ARVALID = '1') then
						rd_state_reg <= s_reply;
						arready_reg <= '0';										-- no additional addresses accepted while sending data to the master

						case (rd_addr) is
							when 0 => rdata_reg <= X"000000" & led_reg;
							when 4 => rdata_reg <= X"000000" & dir_reg;
							when 8 => rdata_reg <= X"000000" & non_reg;
							when 12 => rdata_reg <= X"000000" & blink_reg;
							when others => rdata_reg <= (others => '0');
						end case;

						rvalid_reg <= '1';										-- ready to send data at the next clock cycle
						--rd_addr_reg <= S_AXI_ARADDR;

					end if;

				-- performing reading from the registers
				when s_perform =>
					NULL;

				when s_reply =>
					if (S_AXI_RREADY = '1') then
						rvalid_reg <= '0';										-- not sending any more data
						arready_reg <= '1';										-- ready to receive address at the next clock cycle
						rd_state_reg <= s_idle;									-- going back to idle
					end if;

			end case;
		end if;
	end if;
end process;

-- AXI write (data sent from master) FSM
write_fsm : process (S_AXI_ACLK) begin
	if rising_edge (S_AXI_ACLK) then
		if S_AXI_ARESETN = '0' then
			wr_state_reg <= s_idle;
			awready_reg <= '1';
			wready_reg <= '0';
			bvalid_reg <= '0';
			bresp_reg <= (others => '0');
			led_reg <= (others => '0');
		else
			case wr_state_reg is
				-- waiting for write command
				when s_idle =>
					if (S_AXI_AWVALID = '1') then
						wr_state_reg <= s_perform;
						awready_reg <= '0';
						wready_reg <= '1';
						wr_addr_reg <= S_AXI_AWADDR;
					end if;

				-- performing writing to the registers
				when s_perform =>
					if (S_AXI_WVALID = '1') then
						wready_reg <= '0';
						bvalid_reg <= '1';

						case (wr_addr) is
							when 0 => led_reg <= S_AXI_WDATA(7 downto 0);
							when others => NULL;
						end case;

						wr_state_reg <= s_reply;
					end if;

				-- replying in write response channel
				when s_reply =>
					if (S_AXI_BREADY = '1') then
						awready_reg <= '1';
						bvalid_reg <= '0';
						wr_state_reg <= s_idle;
					end if;

			end case;
		end if;
	end if;
end process;

S_AXI_AWREADY <= awready_reg;
S_AXI_WREADY <= wready_reg;
S_AXI_ARREADY <= arready_reg;
S_AXI_RDATA <= rdata_reg;
S_AXI_RRESP <= rresp_reg;
S_AXI_RVALID <= rvalid_reg;
S_AXI_BRESP <= bresp_reg;
S_AXI_BVALID <= bvalid_reg;

--------------------------------------------------------------------------------
---------------------- USER INPUT/OUTPUT AND AXI REGISTERS ---------------------
--------------------------------------------------------------------------------

-- Input button debouncers (with synchronizers)
up_debouncer : debouncer
	generic map (
		WAIT_CYCLES => WAIT_CYCLES,
		SYNC 		=> SYNC)
	port map (
		clk 		=> S_AXI_ACLK,
		reset 		=> reset,
		signal_in	=> btn_up,
		signal_out	=> btn_up_db);

down_debouncer : debouncer
	generic map (
		WAIT_CYCLES => WAIT_CYCLES,
		SYNC 		=> SYNC)
	port map (
		clk 		=> S_AXI_ACLK,
		reset 		=> reset,
		signal_in	=> btn_down,
		signal_out	=> btn_down_db);

dir_debouncer : debouncer
	generic map (
		WAIT_CYCLES => WAIT_CYCLES,
		SYNC 		=> SYNC)
	port map (
		clk 		=> S_AXI_ACLK,
		reset 		=> reset,
		signal_in	=> sw_dir,
		signal_out	=> sw_dir_db);

blink_debouncer : debouncer
	generic map (
		WAIT_CYCLES => WAIT_CYCLES,
		SYNC 		=> SYNC)
	port map (
		clk 		=> S_AXI_ACLK,
		reset 		=> reset,
		signal_in	=> sw_blink,
		signal_out	=> sw_blink_db);

-- Pulsers (asserting control signals for one clock cycle per button press)
process (S_AXI_ACLK) begin
	if rising_edge (S_AXI_ACLK) then
		if (S_AXI_ARESETN = '0') then
			btn_up_temp <= '0';
			btn_down_temp <= '0';
		else
			btn_up_temp <= btn_up_db;
			btn_down_temp <= btn_down_db;
		end if;
	end if;
end process;

btn_up_pulse <= btn_up_db and not(btn_up_temp);
btn_down_pulse <= btn_down_db and not(btn_down_temp);

-- designated dir_reg interpretation:
-- 0x00 - moving left
-- 0x01 - moving right
process (S_AXI_ACLK) begin
	if rising_edge (S_AXI_ACLK) then
		if (S_AXI_ARESETN = '0') then
			dir_reg <= X"00";
		else
			if (sw_dir_db = '0') then
				dir_reg <= X"00";
			else
				dir_reg <= X"01";
			end if;
		end if;
	end if;
end process;

-- designated non_reg interpretation:
-- [0x00; 0x08] number of LEDs turned ON
process (S_AXI_ACLK) begin
	if rising_edge (S_AXI_ACLK) then
		if (S_AXI_ARESETN = '0') then
			non_reg <= X"00";
		else
			if (btn_down_pulse = '1') then
				if (non_reg = X"00") then
					non_reg <= X"00";
				else
				 	non_reg <= non_reg - X"01";
				end if; 
			elsif (btn_up_pulse = '1') then
				if (non_reg = X"08") then
					non_reg <= X"08";
				else
				 	non_reg <= non_reg + X"01";
				end if; 
			end if;
		end if;
	end if;
end process;

-- blink_reg
process (S_AXI_ACLK) begin
	if rising_edge (S_AXI_ACLK) then
		if (S_AXI_ARESETN = '0') then
			blink_reg <= X"00";
		else
			if (sw_blink_db = '1') then
				blink_reg <= X"01";
			else
				blink_reg <= X"00";
			end if;
		end if;
	end if;
end process;

led_out <= led_reg;
reset <= not(S_AXI_ARESETN);

end synth;
