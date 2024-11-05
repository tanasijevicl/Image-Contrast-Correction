-- U komponenti 'image_contrast_correction' je izvrseno povezivanje komponenata za korekciju kontrasta slike

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use std.textio.all;
library xil_defaultlib;
use xil_defaultlib.RAM_definitions_PK.all;

entity image_contrast_correction is
    generic(
        G_HISTOGRAM_SELECT : string := "FAST"       -- Selektovanje "FAST" (veca frekvencija)  or "SIMPLE" (jednostavniji hardver)
    );
    port(
        clk : in std_logic;
        reset : in std_logic;
        calculate : in std_logic;
        send_data : in std_logic;
        
        tx_data : out std_logic_vector(clogb2(C_MAX_PIXEL_VALUE)-1 downto 0);
        tx_dvalid : out std_logic;
        tx_busy : in std_logic;
        
        calculating : out std_logic
    );
end image_contrast_correction;

architecture Structural of image_contrast_correction is
    -- CONTROL UNIT
    signal hist_en : std_logic;
    signal cumul_hist_en : std_logic;
    signal equal_en : std_logic;
    signal cu_hist_ram_wr_addr : std_logic_vector(clogb2(C_HIST_RAM_DEPTH)-1 downto 0);
    signal cu_hist_ram_rd_addr : std_logic_vector(clogb2(C_HIST_RAM_DEPTH)-1 downto 0);
    signal im_ram_sel : std_logic_vector(clogb2(C_NUM_MEMS)-1 downto 0);

    -- IMAGE RAM                                                                   
    signal im_ram_wr_addr : std_logic_vector(clogb2(C_IM_RAM_DEPTH)-1 downto 0);      
    signal im_ram_wr_data : Im_ram_data_array_t;
    signal im_ram_wr_en : std_logic;                                            
    signal im_ram_rd_addr : std_logic_vector(clogb2(C_IM_RAM_DEPTH)-1 downto 0);      
    signal im_ram_rd_data : Im_ram_data_array_t;
    
    -- HIST RAM
    signal hist_ram_wr_addr : Hist_ram_addr_array_t;
    signal hist_ram_wr_data : Hist_ram_data_array_t;
    signal hist_ram_wr_en : std_logic;
    signal hist_ram_rd_addr : Hist_ram_addr_array_t;
    signal hist_ram_rd_data : Hist_ram_data_array_t;
    
    -- HISTOGRAM
    signal hist_value_new : Hist_ram_data_array_t;
    signal hist_wr_addr : Hist_ram_addr_array_t;
    
    -- KUMULATIVNI HISTOGRAM
    signal cumul_hist_value_out : std_logic_vector(C_HIST_RAM_WIDTH-1 downto 0);
    
begin
    --Instaciranje 'control_unit' komponente
    CONTROL_UNIT : entity work.control_unit(Behavioral)
        generic map(
            G_HISTOGRAM => G_HISTOGRAM_SELECT        
        )
        port map (
            clk => clk,
            reset => reset,
            
            calculate => calculate,
            send_data => send_data,
            
            hist_en => hist_en,
            cumul_hist_en => cumul_hist_en,
            equal_en => equal_en,
            
            tx_dvalid => tx_dvalid,
            tx_busy => tx_busy,
            im_ram_sel => im_ram_sel,
            
            im_ram_wr_en => im_ram_wr_en,
            im_ram_wr_addr => im_ram_wr_addr,
            im_ram_rd_addr => im_ram_rd_addr,
        
            hist_ram_wr_en => hist_ram_wr_en,
            hist_ram_wr_addr => cu_hist_ram_wr_addr,
            hist_ram_rd_addr => cu_hist_ram_rd_addr);

    --Instaciranje 'im_ram' komponenata
    IM_MEMS: for i in 0 to C_NUM_MEMS-1 generate
        IM_MEM : entity work.im_ram(Behavioral)
            generic map (
                G_RAM_WIDTH => 8,
                G_RAM_DEPTH => C_IM_RAM_DEPTH,
                G_RAM_PERFORMANCE => "HIGH_PERFORMANCE",
                G_RAM_INIT_FILE => "lenaCorrupted" & integer'image(i) & ".dat") 
            port map (
                addra  => im_ram_wr_addr,
                addrb  => im_ram_rd_addr,
                dina   => hist_ram_rd_data(i)(15 downto 8),
                clka   => clk,
                wea    => im_ram_wr_en,
                enb    => '1',
                rstb   => '0',
                regceb => '1',
                doutb  => im_ram_rd_data(i)
            );
    end generate;
    
    --Instaciranje 'hist_ram' komponenata
    HIST_MEM: for i in 0 to C_NUM_MEMS-1 generate
        HIST_MEM : entity work.hist_ram(Behavioral)
            generic map (
                G_RAM_WIDTH => 16,
                G_RAM_DEPTH => C_HIST_RAM_DEPTH,
                G_RAM_PERFORMANCE => "HIGH_PERFORMANCE",
                G_RAM_INIT_FILE => "")
            port map (
                addra  => hist_ram_wr_addr(i),
                addrb  => hist_ram_rd_addr(i),
                dina   => hist_ram_wr_data(i),
                clka   => clk,
                wea    => hist_ram_wr_en,
                enb    => '1',
                rstb   => '0',
                regceb => '1',
                doutb  => hist_ram_rd_data(i)
            );
    end generate;
    
    -- Instaciranje 'histogram' komponenata
    -- U zavisnosti od arhitekture (Fast ili Simple) potrebno je podesiti sinhronizaciju u kontrolnoj jedinici!!!
    FAST: if G_HISTOGRAM_SELECT = "FAST"  generate
         HISTOGRAMS: for i in 0 to C_NUM_MEMS-1 generate
            HISTOGRAM : entity work.histogram(Fast)
                port map (
                    clk => clk,
                    reset => reset,
                    en => hist_en,
                    
                    pixel_value => im_ram_rd_data(i),
                    hist_value_old => hist_ram_rd_data(i),
                    hist_value_new => hist_value_new(i),
                    hist_wr_addr => hist_wr_addr(i)
                );
        end generate;
    end generate;
    
    SIMPLE: if G_HISTOGRAM_SELECT = "SIMPLE"  generate
         HISTOGRAMS: for i in 0 to C_NUM_MEMS-1 generate
            HISTOGRAM : entity work.histogram(Simple)
                port map (
                    clk => clk,
                    reset => reset,
                    en => hist_en,
                    
                    pixel_value => im_ram_rd_data(i),
                    hist_value_old => hist_ram_rd_data(i),
                    hist_value_new => hist_value_new(i),
                    hist_wr_addr => hist_wr_addr(i)
                );
        end generate;
    end generate;
    
    --Instaciranje 'cumul_hist' komponente
    CUMUL_HIST : entity work.cumul_hist(Behavioral)
        port map (
            clk => clk,
            reset => reset,
            en => cumul_hist_en,
            
            hist_value_in => hist_ram_rd_data,
            cumul_hist_value_out => cumul_hist_value_out
        );
        
    -- Povezivanje signala u zavisnosti od faze izracunavanja
    CONNECTIONS_PROC : process (hist_en, equal_en, hist_wr_addr, hist_value_new, im_ram_rd_data, 
                                cu_hist_ram_wr_addr, cumul_hist_value_out, cu_hist_ram_rd_addr) is
    begin
        for i in 0 to C_NUM_MEMS-1 loop
            if (hist_en = '1' or equal_en = '1') then
                hist_ram_wr_addr(i) <= hist_wr_addr(i);
                hist_ram_wr_data(i) <= hist_value_new(i);
                hist_ram_rd_addr(i) <= im_ram_rd_data(i);
            else
                hist_ram_wr_addr(i) <= cu_hist_ram_wr_addr;
                hist_ram_wr_data(i) <= cumul_hist_value_out;
                hist_ram_rd_addr(i) <= cu_hist_ram_rd_addr;
            end if;
        end loop;    
    end process CONNECTIONS_PROC;
    
    -- Selktovanje izlaza im_ram-a za slanje podataka
    TX_PROC : process (im_ram_sel, im_ram_rd_data)
    begin
        tx_data <= im_ram_rd_data(to_integer(unsigned(im_ram_sel)));
    end process TX_PROC; 
    
    -- Povezivanje signala za indikaciju stanja sistema
    INDICATE_PROC : process (hist_en, cumul_hist_en, equal_en)
    begin
        calculating <= hist_en or cumul_hist_en or equal_en;
    end process;    
         
end Structural;
