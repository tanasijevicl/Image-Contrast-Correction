-- Komponenta 'histogram' na ulazu dobija jednu po jednu vrednost piksela iz im_ram-a
-- a na izlaz postavlja odgovarajuci podatak i adresu za upis u hist_ram
-- Uradjene su dve arhitekture histograma: 
--  - SIMPLE - jednostavniji hardver
--  - FAST - radi na vecoj frekvenciji, na ulazu i izlazu ima registre  
-- Detaljan opis rada SIMPLE komponente na kraju koda :)

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
library xil_defaultlib;
use xil_defaultlib.RAM_definitions_PK.all;

entity histogram is
    port(
        clk : in std_logic;
        reset : in std_logic;
        en : in std_logic;
        
        pixel_value : in std_logic_vector(C_IM_RAM_WIDTH-1 downto 0);               -- vrednost procitanog piksela
        hist_value_old : in std_logic_vector(C_HIST_RAM_WIDTH-1 downto 0);          -- procitana (stara) vrednost histograma 
        hist_value_new : out std_logic_vector(C_HIST_RAM_WIDTH-1 downto 0);         -- (nova) vrednost koja se upisuje u hist_ram
        hist_wr_addr : out std_logic_vector(clogb2(C_HIST_RAM_DEPTH)-1 downto 0)    -- adresa histograma na koju upisuje u hist_ram   
    );
end histogram;

-- Arhitektura histograma koja radi na vecoj frekvenciji (ima registre na ulazu i izlazu)
architecture Fast of histogram is
    type State_t is (stIdle, stCalc);                                
    signal curr_state, next_state : State_t;
    
    -- Registri za pamcenje prethodnih vrednosti signala pixel_value
    signal pixel_value_d1 : std_logic_vector(C_IM_RAM_WIDTH-1 downto 0);
    signal pixel_value_d2 : std_logic_vector(C_IM_RAM_WIDTH-1 downto 0);
    signal pixel_value_d3 : std_logic_vector(C_IM_RAM_WIDTH-1 downto 0);
    
    signal pixel_value_reg1 : std_logic_vector(C_IM_RAM_WIDTH-1 downto 0);       
    signal pixel_value_reg2 : std_logic_vector(C_IM_RAM_WIDTH-1 downto 0);     
    signal pixel_value_reg3 : std_logic_vector(C_IM_RAM_WIDTH-1 downto 0);     
    signal pixel_value_reg4 : std_logic_vector(C_IM_RAM_WIDTH-1 downto 0);
    
    signal hist_value_old_reg : std_logic_vector(C_HIST_RAM_WIDTH-1 downto 0);
    signal clk_cnt : natural;
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
    
    -- U zavisnosti od prehodna 4 piksela na izlaz hist_value_new se postavlja odgovarajuca vrednost 
    HIST_CALC_PROC: process (clk) is
        variable increment : integer := 1;
    begin
        if (rising_edge(clk)) then
            case curr_state is
                when stIdle =>
                    hist_wr_addr <= (others => '0');
                    hist_value_new <= (others => '0');
                when stCalc =>  
                    
                    if (clk_cnt >= 2) then    
                        if (pixel_value_d3 = pixel_value_reg1 and pixel_value_d3 = pixel_value_reg2 and
                            pixel_value_d3 = pixel_value_reg3 and pixel_value_d3 = pixel_value_reg4) then
                            increment := 5;
                        elsif (pixel_value_d3 = pixel_value_reg1 and pixel_value_d3 = pixel_value_reg2 and
                               pixel_value_d3 = pixel_value_reg3) then
                            increment := 4;
                        elsif (pixel_value_d3 = pixel_value_reg1 and pixel_value_d3 = pixel_value_reg2 and
                               pixel_value_d3 = pixel_value_reg4) then
                            increment := 4;
                        elsif (pixel_value_d3 = pixel_value_reg1 and pixel_value_d3 = pixel_value_reg3 and
                               pixel_value_d3 = pixel_value_reg4) then
                            increment := 4;
                        elsif (pixel_value_d3 = pixel_value_reg2 and pixel_value_d3 = pixel_value_reg3 and
                               pixel_value_d3 = pixel_value_reg4) then
                            increment := 4;
                        elsif (pixel_value_d3 = pixel_value_reg1 and pixel_value_d3 = pixel_value_reg2) then
                            increment := 3;
                        elsif (pixel_value_d3 = pixel_value_reg1 and pixel_value_d3 = pixel_value_reg3) then
                            increment := 3;
                        elsif (pixel_value_d3 = pixel_value_reg1 and pixel_value_d3 = pixel_value_reg4) then
                            increment := 3;
                        elsif (pixel_value_d3 = pixel_value_reg2 and pixel_value_d3 = pixel_value_reg3) then
                            increment := 3;
                        elsif (pixel_value_d3 = pixel_value_reg2 and pixel_value_d3 = pixel_value_reg4) then
                            increment := 3;
                        elsif (pixel_value_d3 = pixel_value_reg3 and pixel_value_d3 = pixel_value_reg4) then
                            increment := 3;
                        elsif (pixel_value_d3 = pixel_value_reg1) then
                            increment := 2;                                          
                        elsif (pixel_value_d3 = pixel_value_reg2) then
                            increment := 2;
                        elsif (pixel_value_d3 = pixel_value_reg3) then
                            increment := 2;
                        elsif (pixel_value_d3 = pixel_value_reg4) then
                            increment := 2;
                        else
                            increment := 1;
                        end if; 
                    end if;
                    
                    hist_wr_addr <= pixel_value_d3;
                    hist_value_new <= std_logic_vector(unsigned(hist_value_old_reg) + increment);
            end case;
        end if;
    end process HIST_CALC_PROC;
    
    -- Pamcenje prethodnih vrednosti piksela
    PIXEL_TMP_PROC: process (clk) is
    begin
        if (rising_edge(clk)) then
            case curr_state is
                when stIdle =>
                    pixel_value_d1 <= (others => '0');
                    pixel_value_d2 <= (others => '0');
                    pixel_value_d3 <= (others => '0');
                
                    pixel_value_reg1 <= (others => '0');
                    pixel_value_reg2 <= (others => '0');
                    pixel_value_reg3 <= (others => '0');
                    pixel_value_reg4 <= (others => '0');
                when stCalc =>
                    pixel_value_d1 <= pixel_value;
                    pixel_value_d2 <= pixel_value_d1;
                    pixel_value_d3 <= pixel_value_d2;
                
                    pixel_value_reg1 <= pixel_value_d3;
                    pixel_value_reg2 <= pixel_value_reg1;
                    pixel_value_reg3 <= pixel_value_reg2;
                    pixel_value_reg4 <= pixel_value_reg3;
            end case;
            hist_value_old_reg <= hist_value_old;
        end if;
    end process PIXEL_TMP_PROC;
    
    -- Brojac
    CLK_CNT_PROC: process (clk) is
    begin
        if(rising_edge(clk)) then
            case curr_state is  
                when stIdle =>
                    clk_cnt <= 0;
                when stCalc =>
                    clk_cnt <= clk_cnt + 1;
            end case;
        end if;    
    end process CLK_CNT_PROC;
    
end Fast;


architecture Simple of histogram is
    type State_t is (stIdle, stCalc);                                
    signal curr_state, next_state : State_t;
    
    signal pixel_value_reg1 : std_logic_vector(C_IM_RAM_WIDTH-1 downto 0);      -- prosla vrenost pixel_value  
    signal pixel_value_reg2 : std_logic_vector(C_IM_RAM_WIDTH-1 downto 0);      -- pretprosla vrednost pixel_value
    
    signal pixel_hazard1 : std_logic_vector(C_IM_RAM_WIDTH-1 downto 0);         -- vrednost piksela koji bi mogao da izazove hazard
    signal hazard1 : std_logic;                                                 -- indikator da bi moglo da dodje do hazarda
    signal pixel_hazard2 : std_logic_vector(C_IM_RAM_WIDTH-1 downto 0);         -- vrednost piksela koji bi mogao da izazove hazard  
    signal hazard2 : std_logic;                                                 -- indikator da bi moglo da dodje do hazarda
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

    -- Trenutna adresa upisa u hist_ram (pixel_value_reg2) se poredi sa naredne dve adrese (piksela) 
    -- i ukoliko su vrednosti pikela iste detektuje se potencijalni hazard. 
    POTENTIAL_HAZARD_PROC: process (clk) is
    begin
        if (rising_edge(clk)) then 
            case curr_state is
                when stIdle =>
                    hazard1 <= '0';
                    hazard2 <= '0';
                    pixel_hazard1 <= (others => '0');
                    pixel_hazard2 <= (others => '0'); 
                when stCalc =>
                    -- provera da li za narednu adresu na izlazu (piksel) postoji hazard                   
                    if (pixel_value_reg2 = pixel_value_reg1 or pixel_value_reg2 = pixel_value) then
                        hazard1 <= '1';
                        pixel_hazard1 <= pixel_value_reg2;
                    else
                        hazard1 <= '0';
                        pixel_hazard1 <= (others => '0');
                    end if;
                    
                    -- hazard 2 je stara vrednost hazarda 1
                    hazard2 <= hazard1;
                    pixel_hazard2 <= pixel_hazard1;
            end case;
        end if;
    end process POTENTIAL_HAZARD_PROC;
    
    -- U zavisnosti od 'hazard' indikatora na izlaz hist_value_new se postavlja odgovarajuca vrednost 
    HIST_CALC_PROC: process (hist_value_old, pixel_value_reg2, hazard1, hazard2, pixel_hazard1, pixel_hazard2, curr_state) is
    begin
        case curr_state is
            when stIdle =>
                hist_wr_addr <= (others => '0');
                hist_value_new <= (others => '0');
            when stCalc =>
                -- ukoliko za posmatrani piksel postoji hazard dodati odgovarajuci inkrement
                if (hazard1 = '1' and pixel_hazard1 = pixel_value_reg2 and hazard2 = '1' and pixel_hazard2 = pixel_value_reg2) then
                    hist_value_new <= std_logic_vector(unsigned(hist_value_old) + 3);  
                elsif (hazard1 = '1' and pixel_hazard1 = pixel_value_reg2) then
                    hist_value_new <= std_logic_vector(unsigned(hist_value_old) + 2); 
                elsif (hazard2 = '1' and pixel_hazard2 = pixel_value_reg2) then
                    hist_value_new <= std_logic_vector(unsigned(hist_value_old) + 2);
                else
                    hist_value_new <= std_logic_vector(unsigned(hist_value_old) + 1);  
                end if;
                
                hist_wr_addr <= pixel_value_reg2;
        end case;
    end process HIST_CALC_PROC;
    
    -- Pamcenje prethodne dve vrednosti piksela
    PIXEL_TMP_PROC: process (clk) is
    begin
        if (rising_edge(clk)) then
            pixel_value_reg1 <= pixel_value;
            pixel_value_reg2 <= pixel_value_reg1; 
        end if;
    end process PIXEL_TMP_PROC;
    
end Simple;


-- Komponenta 'histogram' (Simple) pamti 3 uzastopne vrednosti piksela i detektuje da li moze doci do hazarda prlikom
-- pristupa hist_ram-u, u zavisnosti od potencijalnog hazarda i procitane vrednosti iz hist_ram-a
-- na izlaz se postavlja odgovarajuci podatak i adresa za upis u hist_ram.
-- 1. Slucaj - dva uzastopna piksela identicne vrednosti:
--    - prilikom obrade prvog piksela detektuje se potencijalni hazard
--    - prilikom obrade drugog piksela hazard1 je aktivan i nova vrednost histograma se inkrementira za 2
-- 2. Slucaj - dva piksela indeticne vrednosti razdvojene nekim drugim pikselom:
--    - prilikom obrade prvog piksela detektuje se potencijalni hazard
--    - aktivni hazard1 ne utice na "medjupiksel" jer se proverava podudarnost sa vrednoscu pixel_hazard1    
--    - prilikom obrade treceg piksela hazard2 je aktivan i nova vrednost histograma se inkrementira za 2
-- 3. Slucaj - tri ili vise uzastopnih piksela identicne vrednosti:
--    - prilikom obrade prvog piksela detektuje se potencijalni hazard
--    - prilikom obrade drugog piksela detektuje se potencijalni hazard, hazard1 je aktivan i nova vrednost 
--      histograma se inkrementira za 2 (bitno ako se pojavljuje vise od 3 uzastopna piksela identicne vrednosti)
--    - prilikom obrade trceg piksela hazard1 i hazard2 su aktivni i nova vrednost histograma se inkrementira za 3
-- 4. Slucaj - naizmenicno pojavljivanje 2 vrednosti piksela:
--    - identicna obrada kao u 1. slucaju, s tim sto su aktivni i hazard1 i hazard2, ali zbog provere podudarnosti
--      trenutnog piksela sa vrednostima pixel_hazard1 i pixel_hazard2 nova vrednost histograma se inkrementira za 2
