library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

package RAM_definitions_PK is
    impure function clogb2 (depth: in natural) return integer;
    
    -- Konstante vezane za sliku
    constant C_IMAGE_DIM : natural := 256;                              -- Dimenzije slike
    constant C_MAX_PIXEL_VALUE : natural := 256;                        -- Maksimalna vrednost piksela
    constant C_NUM_MEMS  : natural := 8;                                -- Broj memorija na koje se deli slika
    constant C_NUM_PIXELS : natural := C_IMAGE_DIM*C_IMAGE_DIM;         -- Broj piksela u slici
    
    -- Konstante i "magistrale" im_ram-a
    constant C_IM_RAM_WIDTH : natural := clogb2(C_MAX_PIXEL_VALUE);
    constant C_IM_RAM_DEPTH : natural := C_NUM_PIXELS/C_NUM_MEMS;
    type Im_ram_addr_array_t is array(0 to C_NUM_MEMS-1) of std_logic_vector(clogb2(C_IM_RAM_DEPTH)-1 downto 0);
    type Im_ram_data_array_t is array(0 to C_NUM_MEMS-1) of std_logic_vector(C_IM_RAM_WIDTH - 1 downto 0);  
    
    -- Konstante i "magistrale" hist_ram-a
    constant C_HIST_RAM_WIDTH : natural := clogb2(C_NUM_PIXELS);        
    constant C_HIST_RAM_DEPTH : natural := C_MAX_PIXEL_VALUE;
    type Hist_ram_addr_array_t is array(0 to C_NUM_MEMS-1) of std_logic_vector(clogb2(C_HIST_RAM_DEPTH)-1 downto 0);
    type Hist_ram_data_array_t is array(0 to C_NUM_MEMS-1) of std_logic_vector(C_HIST_RAM_WIDTH - 1 downto 0);
end RAM_definitions_PK;

package body RAM_definitions_PK is
    --  The following function calculates the address width based on specified RAM depth
    impure function clogb2( depth : natural) return integer is
        variable temp    : integer := depth;
        variable ret_val : integer := 0;
    begin
        while temp > 1 loop
            ret_val := ret_val + 1;
            temp    := temp / 2;
        end loop;
        return ret_val;
    end function;
end package body RAM_definitions_PK;
