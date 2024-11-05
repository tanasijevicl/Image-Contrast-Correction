-- Komponenta 'debouncer' eliminise gliceve ulaznog signala, tj. na izlazu daje "cist" signal
-- Konkretno u ovom projektu se koristi za eleminisanje gliceva koji se javljaju prilikom pritiskanja i otpustanja tastera

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity debouncer is
    generic(
        constant CLK_FREQ : natural := 125              -- frekvencija takta u MHz  
    );
    port (
        clk, reset : in std_logic;
        in_signal : in std_logic;
        out_signal : out std_logic
    );
end debouncer;

architecture Behavioral of debouncer is
    constant C_DEBOUNCE : natural := CLK_FREQ*1000;     -- 10ms - vreme za koje signal mora da bude stabilan
    
    type State_t is (stZero, stPotentialZero, stOne, stPotentialOne);
    signal curr_state, next_state : State_t;
    
    signal clk_cnt : natural range 0 to C_DEBOUNCE;
begin

    STATE_TRANSITION: process (clk) is
    begin
        if rising_edge(clk) then
            if reset = '1' then
                curr_state <= stZero;
            else
                curr_state <= next_state;            
            end if;
        end if;
    end process STATE_TRANSITION;
    
    -- Ako je signal dovoljno dugo stabilan (bez gliceva) prelazi se iz jednog u drugo "stabilno" stanje
    NEXT_STATE_LOGIC: process (in_signal, curr_state, clk_cnt) is
    begin
        next_state <= curr_state;
        case curr_state is
            when stZero =>                                  -- stabilna nula
                if in_signal = '1' then
                    next_state <= stPotentialOne;
                end if;
            when stOne =>                                   -- stabilna jedinica
                if in_signal = '0' then
                    next_state <= stPotentialZero;
                end if;            
            when stPotentialOne =>                          -- potencijalna jedinica
                if in_signal = '0' then                     -- provera da li je u pitanju glic
                    next_state <= stZero;
                else
                    if (clk_cnt >= C_DEBOUNCE) then
                        next_state <= stOne;
                    end if;
                end if;
            when stPotentialZero =>                         -- potencijalna nula
                if in_signal = '1' then                     -- provera da li je u pitanju glic
                    next_state <= stOne;
                else
                    if (clk_cnt >= C_DEBOUNCE) then
                        next_state <= stZero;
                    end if;
                end if;
        end case;
    end process NEXT_STATE_LOGIC;
    
    -- Izlaz se menja samo u slucaju prelaska iz jednog u drugo "stabilno" stanje 
    OUTPUT_LOGIC: process (clk) is
    begin
        if (rising_edge(clk)) then
            if (curr_state = stZero or curr_state = stPotentialOne) then
                out_signal <= '0';
            else
                out_signal <= '1';
            end if;
        end if;
    end process OUTPUT_LOGIC;
    
    -- Brojac
    CLK_CNT_PROC: process (clk) is
    begin
        if rising_edge(clk) then
            if (curr_state = stPotentialOne or curr_state = stPotentialZero) then 
                clk_cnt <= clk_cnt + 1;
            else
                clk_cnt <= 0;
            end if;
        end if;
    end process CLK_CNT_PROC;

end Behavioral;
