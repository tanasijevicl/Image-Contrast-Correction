-- Dodavanje komponenata 'uart_tx', 'debouncer', 'edge_detector' i 'clk_wiz_0' 
-- na glavnu komponentu image_contrast_correction 
-- POTREBNO JE PODESITI GENERIKE G_CLK_FREQ, G_SER_FREQ i G_HISTOGRAM_SELECT!!!  

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use std.textio.all;
library xil_defaultlib;
use xil_defaultlib.RAM_definitions_PK.all;

entity contrast_correction_module is
    generic(
        constant G_CLK_FREQ : natural := 200;               -- frekvencijca takta (MHz)
        constant G_SER_FREQ : natural := 115200;            -- Baud rate (bps)
        constant G_HISTOGRAM_SELECT : string := "FAST"      -- Selektovanje "FAST" (veca frekvencija)  or "SIMPLE" (jednostavniji hardver)
    );
    port(
        clk_in : in std_logic;
        reset : in std_logic;
        calculate : in std_logic;
        send_data : in std_logic;
        tx : out std_logic;
        
        calc_led : out std_logic;
        send_led : out std_logic
    );
end contrast_correction_module;

architecture Structural of contrast_correction_module is
    signal tx_data : std_logic_vector(clogb2(C_MAX_PIXEL_VALUE)-1 downto 0);
    signal tx_dvalid : std_logic;
    signal tx_busy : std_logic;
    
    signal calc_deb : std_logic;
    signal send_deb : std_logic;
    signal calc_edge : std_logic;
    signal send_edge : std_logic;
    
    signal calculating : std_logic;

    component clk_wiz_0
    port(
        clk_out : out std_logic;
        reset : in std_logic;
        clk_in : in std_logic
    );
    end component;

    signal clk : std_logic;
begin
    --Instaciranje 'clk_wiz_0' komponente
    CLK_WIZ : clk_wiz_0
       port map ( 
       clk_out => clk,
       reset => reset,               
       clk_in => clk_in
     );

    --Instaciranje 'image_contrast_correction' komponente
    IMAGE_CONTRAST_CORRECTION : entity work.image_contrast_correction(Structural)
        generic map(
            G_HISTOGRAM_SELECT => G_HISTOGRAM_SELECT
        )
        port map (
            clk => clk,
            reset => reset,
            calculate => calc_edge,
            send_data => send_edge,
            
            tx_data => tx_data,
            tx_dvalid => tx_dvalid,
            tx_busy => tx_busy,
            
            calculating => calculating
            );
            
    --Instaciranje 'uart_tx' komponente
    UART_TX : entity work.uart_tx(Behavioral)
        generic map (
            CLK_FREQ => G_CLK_FREQ,
            SER_FREQ => G_SER_FREQ
            )
        port map (
            clk => clk,
            rst => reset,
            tx => tx,
            par_en => '0',
            tx_data => tx_data,
            tx_dvalid => tx_dvalid,
            tx_busy => tx_busy
            );            
    
    --Instaciranje 'debounce' komponenata
    DEBOUNCE_CALC : entity work.debouncer(Behavioral)
        generic map(
            CLK_FREQ => G_CLK_FREQ
        )
        port map(
            clk => clk,
            reset => reset,
            in_signal => calculate,
            out_signal => calc_deb
        );
        
    DEBOUNCE_SEND : entity work.debouncer(Behavioral)
        port map(
            clk => clk,
            reset => reset,
            in_signal => send_data,
            out_signal => send_deb
        );
    
    --Instaciranje 'edge_detector' komponenata
    EDGE_CALC : entity work.edge_detector(Behavioral)
        port map(
            clk => clk,
            reset => reset,
            in_signal => calc_deb,
            edge => calc_edge
        );
        
    EDGE_SEND : entity work.edge_detector(Behavioral)
        port map(
            clk => clk,
            reset => reset,
            in_signal => send_deb,
            edge => send_edge
        );
       
    -- Povezivanje signala za indikaciju stanja sistema 
    LED_PROC : process (calculating, tx_dvalid)
    begin
        calc_led <= calculating;
        send_led <= tx_dvalid;
    end process;
        

end Structural;
