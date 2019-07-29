----------------------------------------------------------------------------------
-- UART echo top module.

-- Every data byte received by uart_rx is sent back by uart_tx.
----------------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity uart_echo_top is
	generic (
		CK_PER_BIT 				: integer			:= 868);
	port (
		usrclk_n, usrclk_p		: in std_logic;
		uart_in					: in std_logic;
		uart_out				: out std_logic);
end uart_echo_top;

architecture synth of uart_echo_top is

	-- Module definitions
	component clk_wiz_0
		port (
			clk_in1_n 			: in std_logic;
			clk_in1_p 			: in std_logic;
			clk_out1 			: out std_logic);
	end component;	

	component uart_tx
		generic (
			CK_PER_BIT 			: integer);
		port (
			clk 				: in std_logic;
			reset 				: in std_logic;
			tx_out 				: out std_logic;
			data_req 			: in std_logic;
			data_in 			: in std_logic_vector (7 downto 0);
			tx_busy				: out std_logic);
	end component;

	component uart_rx
		generic (
			CK_PER_BIT 			: integer);
		port (
			clk 				: in std_logic;
			reset 				: in std_logic;
			rx_in 				: in std_logic;
			rx_done 			: out std_logic;
			data_out 			: out std_logic_vector (7 downto 0));
	end component;

	-- Signal definitions
	signal clk 					: std_logic;
	signal rx_done 				: std_logic;
	--signal data_reg				: std_logic_vector (7 downto 0);		-- temp register for storing uart data
	signal rx_data_out 			: std_logic_vector (7 downto 0);


begin
	
	-- Initializing clock generator
	clock_gen : clk_wiz_0
		port map (
			clk_in1_n 	=> usrclk_n,
			clk_in1_p	=> usrclk_p,
			clk_out1	=> clk);

	uart_rx_module : uart_rx
		generic map (
			CK_PER_BIT	=> CK_PER_BIT)
		port map (
			clk 		=> clk,
			reset 		=> '0',
			rx_in 		=> uart_in,
			rx_done 	=> rx_done,
			data_out 	=> rx_data_out);
	
	uart_tx_module : uart_tx
		generic map (
			CK_PER_BIT	=> CK_PER_BIT)
		port map (
			clk 		=> clk,
			reset 		=> '0',
			tx_out		=> uart_out,
			data_req 	=> rx_done,
			data_in 	=> rx_data_out);


end synth;
