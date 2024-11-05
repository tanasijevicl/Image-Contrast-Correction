----------------------------------------------------------------------------------
-- UART transmitter 
-- The component takes data from tx_data port and sends it serialy via tx port
-- using standardized UART interface. It requires information about operating
-- clock frequency and baudrate in compile time. We recommend to use 500000 bps 
-- for the purpose of the project. tx_dvalid indicates that the tx_data is
-- valid and should be kept high until tx_busy becomes '1'. When tx_busy becomes
-- '1' UART accepted the data and user can wait the transfer to be finished. When
-- transfer is finished tx_busy becomes '0'.
----------------------------------------------------------------------------------
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_ARITH.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;

entity uart_tx is
generic (
	CLK_FREQ	: integer := 125;		-- Main frequency (MHz)
	SER_FREQ	: integer := 500000		-- Baud rate (bps)
);
port (
	-- Control
	clk			: in	std_logic;		-- Main clock
	rst			: in	std_logic;		-- Main reset
	-- External Interface
	tx			: out	std_logic;		-- RS232 transmitted serial data
	-- RS232/UART Configuration
	par_en		: in	std_logic;		-- Parity bit enable
	-- uPC Interface
	tx_dvalid   : in	std_logic;						-- Indicates that tx_data is valid and should be sent
	tx_data		: in	std_logic_vector(7 downto 0);	-- Data to transmit
	tx_busy     : out   std_logic                       -- Active while UART is busy and cannot receive data
);
end uart_tx;

architecture Behavioral of uart_tx is

	-- Constants
	constant UART_IDLE	:	std_logic := '1';
	constant UART_START	:	std_logic := '0';
	constant PARITY_EN	:	std_logic := '1';
	constant RST_LVL	:	std_logic := '1';

	-- Types
	type state is (idle,data,parity,stop1,stop2);			-- Stop1 and Stop2 are inter frame gap signals

	-- TX Signals
	signal tx_fsm		:	state;							-- Control of transmission
	signal tx_clk_en	:	std_logic;						-- Transmited clock enable
	signal tx_par_bit	:	std_logic;						-- Calculated Parity bit
	signal tx_data_tmp	:	std_logic_vector(7 downto 0);	-- Parallel to serial converter
	signal tx_data_cnt	:	std_logic_vector(2 downto 0);	-- Count transmited bits

begin

	tx_clk_gen:process(clk)
		variable counter	:	integer range 0 to conv_integer((CLK_FREQ*1_000_000)/SER_FREQ-1);
	begin
		if clk'event and clk = '1' then
			-- Normal Operation
			if counter = (CLK_FREQ*1_000_000)/SER_FREQ-1 then
				tx_clk_en	<=	'1';
				counter		:=	0;
			else
				tx_clk_en	<=	'0';
				counter		:=	counter + 1;
			end if;
			-- Reset condition
			if rst = RST_LVL then
				tx_clk_en	<=	'0';
				counter		:=	0;
			end if;
		end if;
	end process;

	tx_proc:process(clk)
		variable data_cnt	: std_logic_vector(2 downto 0);
	begin
		if clk'event and clk = '1' then
			if tx_clk_en = '1' then
				-- Default values
				tx						<=	UART_IDLE;
                tx_busy                 <=  '1';
				-- FSM description
				case tx_fsm is
					-- Wait to transfer data
					when idle =>
                        tx_busy <= '0';
						-- Send Init Bit
						if tx_dvalid = '1' then
							tx			<=	UART_START;
							tx_data_tmp	<=	tx_data;
							tx_fsm		<=	data;
							tx_data_cnt	<=	(others=>'1');
							tx_par_bit	<=	'0';
						end if;
					-- Data receive
					when data =>
						tx				<=	tx_data_tmp(0);
						tx_par_bit		<=	tx_par_bit xor tx_data_tmp(0);
						if tx_data_cnt = 0 then
							if par_en = PARITY_EN then
								tx_fsm	<=	parity;
							else
								tx_fsm	<=	stop1;
							end if;
							tx_data_cnt	<=	(others=>'1');
						else
							tx_data_tmp	<=	'0' & tx_data_tmp(7 downto 1);
							tx_data_cnt	<=	tx_data_cnt - 1;
						end if;
					when parity =>
						tx				<=	tx_par_bit;
						tx_fsm			<=	stop1;
					-- End of communication
					when stop1 =>
						-- Send Stop Bit
						tx				<=	UART_IDLE;
						tx_fsm			<=	stop2;
					when stop2 =>
						-- Send Stop Bit
						tx				<=	UART_IDLE;
						tx_fsm			<=	idle;
					-- Invalid States
					when others => null;
				end case;
				-- Reset condition
				if rst = RST_LVL then
					tx_fsm				<=	idle;
					tx_par_bit			<=	'0';
					tx_data_tmp			<=	(others=>'0');
					tx_data_cnt			<=	(others=>'0');
				end if;
			end if;
		end if;
	end process;

end Behavioral;

