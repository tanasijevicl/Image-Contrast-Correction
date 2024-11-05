-- Komponenta 'control_unit' je zaduzena za postavljanje: signala dozvole za upis u memoriju,
-- ispravnih adresa za citanje i upis, signala za dozvolu ostalih komponenata, kao i za 
-- postavljanje signala za slanje podataka prko uart-a

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use std.textio.all;
library xil_defaultlib;
use xil_defaultlib.RAM_definitions_PK.all;

entity control_unit is
    generic(
        G_HISTOGRAM : string := "FAST"          -- Select "FAST" or "SIMPLE"
    );
    port(
        clk : in std_logic;
        reset : in std_logic;
        
        calculate : in std_logic;               -- signal za pokretanje obrade slike
        send_data : in std_logic;               -- signal za pokretanje slanja podataka
      
        hist_en : out std_logic;                -- dozvola za rad komponente 'histogram'
        cumul_hist_en : out std_logic;          -- dozvola za rad komponente 'cumul_hist'
        equal_en : out std_logic;               -- dozvola za rad ekvivalizacije

        tx_busy : in std_logic;                                                             -- indikator da je uart zauzet       
        tx_dvalid : out std_logic;                                                          -- indikator da je postavljeni poadtak validan
        im_ram_sel : out std_logic_vector(clogb2(C_NUM_MEMS)-1 downto 0);                   -- "selektovanje" im_ram-a                                                                                                                       
        
        im_ram_rd_addr : out std_logic_vector(clogb2(C_IM_RAM_DEPTH)-1 downto 0);           -- adresa piksela koji se cita iz im_ram
        im_ram_wr_en : out std_logic;                                                       -- dozvola za upis u im_ram
        im_ram_wr_addr : out std_logic_vector(clogb2(C_IM_RAM_DEPTH)-1 downto 0);           -- adresa histograma na koju upisuje u im_ram
        
        hist_ram_rd_addr : out std_logic_vector(clogb2(C_HIST_RAM_DEPTH)-1 downto 0);       -- adresa histograma koji se cita iz hist_ram
        hist_ram_wr_en : out std_logic;                                                     -- dozvola za upis u hist_ram
        hist_ram_wr_addr : out std_logic_vector(clogb2(C_HIST_RAM_DEPTH)-1 downto 0)        -- adresa histograma na koju upisuje u hist_ram
    );
end control_unit;

architecture Behavioral of control_unit is
    
    type State_t is (stIdle, stHist, stCumulHist, stEqual, stSendData);
    signal curr_state, next_state : State_t;
    
    -- Broj taktova potrebnih da se zavrsi odredjena faza izracunavanja
    constant C_HIST_CALC_TIME_FAST : natural := C_NUM_PIXELS/C_NUM_MEMS + 4;
    constant C_HIST_CALC_TIME_SIMPLE : natural := C_NUM_PIXELS/C_NUM_MEMS + 2;
    constant C_CUMUL_HIST_CALC_TIME : natural := C_MAX_PIXEL_VALUE + 4;
    constant C_EQUAL_CALC_TIME : natural := C_NUM_PIXELS/C_NUM_MEMS + 2;
    
    -- Pomocni signali za slanje podataka preko uart-a
    signal addr_cnt : natural range 0 to C_IM_RAM_DEPTH - 1;                -- adresa podatka za slanje iz im_ram-a
    signal pixel_cnt : natural range 0 to C_NUM_PIXELS;                     -- ukupan broj poslatih piksela
    signal tx_busy_prev : std_logic;                                        -- prethodna vrednost singala tx_busy
    
    signal clk_cnt : natural range 0 to C_NUM_PIXELS;
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
    
    -- Ukoliko se koristi FAST histogram, sinhronizacija je sledeca:
    FAST: if G_HISTOGRAM = "FAST" generate
        -- Signal 'calculate' pokrece izracunavanje korekcije kontrasta slike
        -- Signal 'send_data' pokrece slanje podata preko uart-a
        NEXT_STATE_LOGIC: process (calculate, send_data, clk_cnt, pixel_cnt, curr_state) is
        begin
            next_state <= curr_state; 
            case curr_state is  
                when stIdle =>
                    if (calculate = '1') then
                        next_state <= stHist;
                    elsif(send_data = '1') then
                        next_state <= stSendData;
                    end if;
                when stHist =>              
                    if (clk_cnt > C_HIST_CALC_TIME_FAST) then
                        next_state <= stCumulHist;
                    end if;
                when stCumulHist =>
                    if (clk_cnt > C_CUMUL_HIST_CALC_TIME) then
                        next_state <= stEqual;
                    end if;
                when stEqual =>
                    if (clk_cnt > C_EQUAL_CALC_TIME) then
                        next_state <= stIdle;
                    end if;
                when stSendData =>
                    if (pixel_cnt >= C_NUM_PIXELS)then
                        next_state <= stIdle;
                    end if;
            end case;
        end process NEXT_STATE_LOGIC;
    
        -- Postavljanje 'en' signala komponente na aktivnu vrednost, kada su podaci na ulazu komponente validni    
        CONTROL_PROC: process (clk) is
        begin
            if (rising_edge(clk)) then
                case curr_state is  
                    when stHist =>
                        if (clk_cnt >= 1) then
                            hist_en <= '1';
                        end if;
                        cumul_hist_en <= '0';
                        equal_en <= '0'; 
                    when stCumulHist =>
                        hist_en <= '0';
                        if (clk_cnt >= 2) then
                            cumul_hist_en <= '1';
                        end if;
                        equal_en <= '0';
                    when stEqual =>
                        hist_en <= '0';
                        cumul_hist_en <= '0';
                        equal_en <= '1';
                    when others =>
                        hist_en <= '0';
                        cumul_hist_en <= '0';
                        equal_en <= '0';              
                end case;
            end if;
        end process CONTROL_PROC;
        
        -- Kontrola za promenu adrese i dozvole za upis u hist_ram
        WRITE_HIST_RAM_PROC: process (clk) is
        begin
            if (rising_edge(clk)) then
                case curr_state is
                    when stHist =>
                        if (clk_cnt >= 6) then
                            hist_ram_wr_en <= '1';
                            hist_ram_wr_addr <= (others => '0');
                        end if;
                    when stCumulHist =>
                        if (clk_cnt >= 6) then
                            hist_ram_wr_en <= '1';
                            hist_ram_wr_addr <= std_logic_vector(to_unsigned(clk_cnt-6, clogb2(C_HIST_RAM_DEPTH)));
                        else
                            hist_ram_wr_en <= '0';
                            hist_ram_wr_addr <= (others => '0');
                        end if;
                    when others =>
                        hist_ram_wr_en <= '0';
                        hist_ram_wr_addr <= (others => '0');
                end case;     
            end if;    
        end process WRITE_HIST_RAM_PROC;
    end generate;
    
    -- Ukoliko se koristi SIMPLE histogram, sinhronizacija je sledeca:
    SIMPLE: if G_HISTOGRAM = "SIMPLE" generate
        -- Signal 'calculate' pokrece izracunavanje korekcije kontrasta slike
        -- Signal 'send_data' pokrece slanje podata preko uart-a
        NEXT_STATE_LOGIC: process (calculate, send_data, clk_cnt, pixel_cnt, curr_state) is
        begin
            next_state <= curr_state; 
            case curr_state is  
                when stIdle =>
                    if (calculate = '1') then
                        next_state <= stHist;
                    elsif(send_data = '1') then
                        next_state <= stSendData;
                    end if;
                when stHist =>              
                    if (clk_cnt > C_HIST_CALC_TIME_SIMPLE) then
                        next_state <= stCumulHist;
                    end if;
                when stCumulHist =>
                    if (clk_cnt > C_CUMUL_HIST_CALC_TIME) then
                        next_state <= stEqual;
                    end if;
                when stEqual =>
                    if (clk_cnt > C_EQUAL_CALC_TIME) then
                        next_state <= stIdle;
                    end if;
                when stSendData =>
                    if (pixel_cnt >= C_NUM_PIXELS)then
                        next_state <= stIdle;
                    end if;
            end case;
        end process NEXT_STATE_LOGIC;
    
        -- Postavljanje 'en' signala komponente na aktivnu vrednost, kada su podaci na ulazu komponente validni    
        CONTROL_PROC: process (clk) is
        begin
            if (rising_edge(clk)) then
                case curr_state is  
                    when stHist =>
                        if (clk_cnt >= 3) then
                            hist_en <= '1';
                        end if;
                        cumul_hist_en <= '0';
                        equal_en <= '0'; 
                    when stCumulHist =>
                        hist_en <= '0';
                        if (clk_cnt >= 2) then
                            cumul_hist_en <= '1';
                        end if;
                        equal_en <= '0';
                    when stEqual =>
                        hist_en <= '0';
                        cumul_hist_en <= '0';
                        equal_en <= '1';
                    when others =>
                        hist_en <= '0';
                        cumul_hist_en <= '0';
                        equal_en <= '0';              
                end case;
            end if;
        end process CONTROL_PROC;
        
        -- Kontrola za promenu adrese i dozvole za upis u hist_ram
        WRITE_HIST_RAM_PROC: process (clk) is
        begin
            if (rising_edge(clk)) then
                case curr_state is
                    when stHist =>
                        if (clk_cnt >= 4) then
                            hist_ram_wr_en <= '1';
                            hist_ram_wr_addr <= (others => '0');
                        end if;
                    when stCumulHist =>
                        if (clk_cnt >= 6) then
                            hist_ram_wr_en <= '1';
                            hist_ram_wr_addr <= std_logic_vector(to_unsigned(clk_cnt-6, clogb2(C_HIST_RAM_DEPTH)));
                        else
                            hist_ram_wr_en <= '0';
                            hist_ram_wr_addr <= (others => '0');
                        end if;
                    when others =>
                        hist_ram_wr_en <= '0';
                        hist_ram_wr_addr <= (others => '0');
                end case;     
            end if;    
        end process WRITE_HIST_RAM_PROC;
    end generate;    
    
    -- Kontrola za promenu adrese za citanje hist_ram-a
    READ_HIST_RAM_PROC: process (clk) is
    begin
        if (rising_edge(clk)) then
            case curr_state is
                when stCumulHist | stEqual =>
                    hist_ram_rd_addr <= std_logic_vector(to_unsigned(clk_cnt, clogb2(C_HIST_RAM_DEPTH)));       
                when others =>
                    hist_ram_rd_addr <= (others => '0');   
            end case;     
        end if;    
    end process READ_HIST_RAM_PROC;
  
    -- Kontrola za promenu adrese i dozvole za upis u im_ram
    WRITE_IM_RAM_PROC: process (clk) is
    begin
        if (rising_edge(clk)) then
            case curr_state is
                when stEqual =>
                    if (clk_cnt >= 4) then
                        im_ram_wr_en <= '1';
                        im_ram_wr_addr <= std_logic_vector(to_unsigned(clk_cnt-4, clogb2(C_IM_RAM_DEPTH)));
                    end if;    
                when others =>
                    im_ram_wr_en <= '0';
                    im_ram_wr_addr <= (others => '0');
            end case;     
        end if;    
    end process WRITE_IM_RAM_PROC; 

    -- Kontrola za promenu adrese za citanje im_ram-a
    READ_IM_RAM_PROC: process (clk) is
    begin
        if (rising_edge(clk)) then
            case curr_state is
                when stHist | stEqual =>
                    im_ram_rd_addr <= std_logic_vector(to_unsigned(clk_cnt, clogb2(C_IM_RAM_DEPTH)));
                when stSendData =>
                    im_ram_rd_addr <= std_logic_vector(to_unsigned(addr_cnt, clogb2(C_IM_RAM_DEPTH)));
                when others =>
                    im_ram_rd_addr <= (others => '0');
            end case;     
        end if;
    end process READ_IM_RAM_PROC;
    
    -- Kako je slanje jednog podatka dosta duze od citanja novog podatka iz memorije
    -- tx_dvalid se postavlja na '1' nakon 2*Tclk i ostaje na '1' sve do kraja slanja 
    SEND_DATA_PROC: process (clk) is
    begin
        if (rising_edge(clk)) then
            case curr_state is  
                when stSendData =>
                    if (clk_cnt >= 2) then
                        tx_dvalid <= '1';
                    end if;
                when others => 
                    tx_dvalid <= '0';
            end case;
        end if;
    end process SEND_DATA_PROC;
    
    -- Nakon sto se detektuje uzlazna ivica signala tx_busy postavlja se nova adresa za citanje iz im_ram-a
    DATA_CNT_PROC: process (clk) is
    begin
        if (rising_edge(clk)) then
            tx_busy_prev <= tx_busy;
            case curr_state is  
                when stSendData =>
                    if (tx_busy_prev = '0' and tx_busy = '1') then
                        pixel_cnt <= pixel_cnt + 1;
                        addr_cnt <= addr_cnt + 1;
                    end if;
                when others =>
                    pixel_cnt <= 0;
                    addr_cnt <= 0;
            end case;
        end if;
    end process DATA_CNT_PROC;
    
    -- Selktovanje izlaza im_ram-a za slanje podataka
    -- Nakon sto se procitaju podaci sa svih adresa iz jednog im_ram-a
    -- na silaznu ivicu signala tx_busy se menja im_ram_sel 
    MEM_SEL_PROC: process (clk) is
        variable mem_sel : natural range 0 to C_NUM_MEMS := 0;
    begin
        if (rising_edge(clk)) then
            case curr_state is  
                when stSendData =>
                    if (tx_busy_prev = '1' and tx_busy = '0') then
                        if (addr_cnt = 0) then
                            mem_sel := mem_sel + 1;
                        end if;    
                    end if;
                    im_ram_sel <= std_logic_vector(to_unsigned(mem_sel, clogb2(C_NUM_MEMS)));
                when others =>
                    mem_sel := 0;  
                    im_ram_sel <= (others => '0');
            end case;
        end if;
    end process MEM_SEL_PROC;
    
    -- Brojac, resetuje se na 0 nakon svake promene stanja
    CLK_CNT_PROC: process (clk) is
    begin
        if(rising_edge(clk)) then
            case curr_state is  
                when stIdle =>
                    clk_cnt <= 0;
                when others =>
                    if (curr_state = next_state) then
                        clk_cnt <= clk_cnt + 1;
                    else
                        clk_cnt <= 0;
                    end if;
            end case;
        end if;    
    end process CLK_CNT_PROC;
    
end Behavioral;
