library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
library xil_defaultlib;
use xil_defaultlib.RAM_definitions_PK.all;

entity contrast_correction_module_tb is
end contrast_correction_module_tb;

architecture Behavioral of contrast_correction_module_tb is
    constant CLK_PERIOD : time := 1 ns; -- Clock period

    signal clk : std_logic := '0';
    signal reset : std_logic := '0';
    signal calculate : std_logic := '0'; 
    signal send_data : std_logic := '0';
    signal tx : std_logic := '0';

begin

    uut: entity work.contrast_correction_module
        generic map (
            G_CLK_FREQ => 1,                  
            G_SER_FREQ => 115200,              
            G_HISTOGRAM_SELECT => "FAST"   
        )
        port map (
            clk_in => clk,
            reset => reset,
            calculate => calculate,
            send_data => send_data,
            tx => tx
        );
        
    clk <= not clk after CLK_PERIOD/2;
        
    -- Stimulus process
    stimulus_process: process
    begin
        reset <= '1';
        wait for CLK_PERIOD*10;
        reset <= '0';
        wait for CLK_PERIOD*10;

        calculate <= '1';
        wait for CLK_PERIOD*2000;
        calculate <= '0';
        wait;
           
    end process;
end Behavioral;