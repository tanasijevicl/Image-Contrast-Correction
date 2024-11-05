-- Komponenta 'cumul_hist' predstavlja stablo sabiraca, sa registrima na ulazu, izlazu i svakom medjustepenu (pipeline)
-- Na ulazu se paralelno dobija jedna po jedna vrednost histograma iz svakog hist_ram-a
-- Na izlazu se dobija jedna po jedna (skalirana) vrednost kumulativnog histograma

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
library xil_defaultlib;
use xil_defaultlib.RAM_definitions_PK.all;

entity cumul_hist is
    port(
        clk : in std_logic;
        reset : in std_logic;
        en : in std_logic;
        
        hist_value_in : in Hist_ram_data_array_t;                                   -- vrednost histograma iz hist_ram-ova
        cumul_hist_value_out : out std_logic_vector(C_HIST_RAM_WIDTH-1 downto 0)    -- izracunata vrednost kumulativnog histograma 
    );
end cumul_hist;

architecture Behavioral of cumul_hist is
    type State_t is (stIdle, stCalc);
    signal curr_state, next_state : State_t;
    
    -- ulazni registri
    signal hist_value_reg : Hist_ram_data_array_t;
    
    -- prvi medjustepen registara
    signal stage_one_sum1 : natural range 0 to C_NUM_PIXELS;        
    signal stage_one_sum2 : natural range 0 to C_NUM_PIXELS;
    signal stage_one_sum3 : natural range 0 to C_NUM_PIXELS;
    signal stage_one_sum4 : natural range 0 to C_NUM_PIXELS;
    
    -- drugi medjustepen registara
    signal stage_two_sum1 : natural range 0 to C_NUM_PIXELS;
    signal stage_two_sum2 : natural range 0 to C_NUM_PIXELS;
    
    -- prethodna vrednost kumulativnog histograma
    signal cumul_hist_reg : natural range 0 to C_NUM_PIXELS;
    
begin

    STATE_TRANSITION: process (clk) is
    begin
        if rising_edge(clk) then
            if reset = '1' then
                curr_state <= stIdle;
            else
                curr_state <= next_state;
            end if;        
        end if;
    end process STATE_TRANSITION;
    
    -- Signal 'en' predstavlja signal dozovole za rad komponente 
    NEXT_STATE_LOGIC: process (en, curr_state) is
    begin
        next_state <= curr_state; 
        case curr_state is  
            when stIdle =>
                if (en = '1') then
                    next_state <= stCalc;
                end if;
            when stCalc =>
                if (en = '0') then
                    next_state <= stIdle;
                end if;
        end case;
    end process NEXT_STATE_LOGIC;
    
    -- Upis ulaznih vrednosti histograma u registre
    REG_PROC: process (clk) is
    begin
        if (rising_edge(clk)) then
            case curr_state is  
                when stIdle =>
                    for i in 0 to C_NUM_MEMS-1 loop
                        hist_value_reg(i) <= (others => '0');
                    end loop; 
                when stCalc =>
                    for i in 0 to C_NUM_MEMS-1 loop
                        hist_value_reg(i) <= hist_value_in(i);
                    end loop; 
            end case;
        end if;
    end process REG_PROC;

    -- Stablo sabiraca, nakon svakog sabiraca po jedan registar za pamcenje medjurezultata (pipeline)
    CALC_PROC: process (clk) is
    begin
        if (rising_edge(clk)) then
            case curr_state is  
                when stIdle =>
                    stage_one_sum1 <= 0;
                    stage_one_sum2 <= 0;
                    stage_one_sum3 <= 0;
                    stage_one_sum4 <= 0;
                    stage_two_sum1 <= 0;
                    stage_two_sum2 <= 0;
                    cumul_hist_reg <= 0;
                when stCalc =>
                    stage_one_sum1 <= to_integer(unsigned(hist_value_reg(0))) + to_integer(unsigned(hist_value_reg(1)));
                    stage_one_sum2 <= to_integer(unsigned(hist_value_reg(2))) + to_integer(unsigned(hist_value_reg(3)));
                    stage_one_sum3 <= to_integer(unsigned(hist_value_reg(4))) + to_integer(unsigned(hist_value_reg(5)));
                    stage_one_sum4 <= to_integer(unsigned(hist_value_reg(6))) + to_integer(unsigned(hist_value_reg(7)));
                    stage_two_sum1 <= stage_one_sum1 + stage_one_sum2;
                    stage_two_sum2 <= stage_one_sum3 + stage_one_sum4;
                    cumul_hist_reg <=  stage_two_sum1 + stage_two_sum2 + cumul_hist_reg;
            end case;
        end if;
    end process CALC_PROC;

    -- Ukoliko je vrednost kumulativnog histograma maksimalna (65536), 
    -- u memoriju se upisuje 'max-1' (65535), jer je to maksimalna vrednost podatka hist_ram-a  
    OUTPUT_PROC: process (clk) is
    begin
        if (rising_edge(clk)) then
            case curr_state is  
                when stIdle =>
                    cumul_hist_value_out <= (others => '0');   
                when stCalc =>
                    if (stage_two_sum1 + stage_two_sum2 + cumul_hist_reg < C_NUM_PIXELS) then
                        cumul_hist_value_out <= std_logic_vector(to_unsigned(stage_two_sum1 + stage_two_sum2 + cumul_hist_reg, C_HIST_RAM_WIDTH));
                    else
                        cumul_hist_value_out <= std_logic_vector(to_unsigned(C_NUM_PIXELS - 1, 16));
                    end if; 
            end case;
        end if;
    end process OUTPUT_PROC;
    
end Behavioral;
