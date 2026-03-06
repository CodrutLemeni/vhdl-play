-- R1600 Data Memory Simulation Model
-- Two banks: Bank A (addr bit 31 = 0) and Bank B (addr bit 31 = 1)
-- 1K x 16 each for simulation, always ready (no wait states in basic test)

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.r1600_pkg.all;

entity data_mem_model is
    port (
        iCLK        : in  std_logic;
        iADR        : in  std_logic_vector(DM_ADR_W-1 downto 0);
        -- Bank A
        iWE_A       : in  std_logic;
        iRE_A       : in  std_logic;
        oRD_DAT_A   : out std_logic_vector(DATA_W-1 downto 0);
        -- Bank B
        iWE_B       : in  std_logic;
        iRE_B       : in  std_logic;
        oRD_DAT_B   : out std_logic_vector(DATA_W-1 downto 0);
        -- Write data (shared)
        iWR_DAT     : in  std_logic_vector(DATA_W-1 downto 0);
        -- Ready signal
        oRDY        : out std_logic
    );
end entity data_mem_model;

architecture sim of data_mem_model is
    type mem_array_t is array(0 to 1023) of std_logic_vector(DATA_W-1 downto 0);
    signal bank_a : mem_array_t := (others => (others => '0'));
    signal bank_b : mem_array_t := (others => (others => '0'));
    signal addr_10 : unsigned(9 downto 0);
begin

    addr_10 <= unsigned(iADR(9 downto 0));

    -- Always ready (zero wait states)
    oRDY <= '1';

    -- Bank A
    process(iCLK)
    begin
        if rising_edge(iCLK) then
            if iWE_A = '1' then
                bank_a(to_integer(addr_10)) <= iWR_DAT;
            end if;
            if iRE_A = '1' then
                oRD_DAT_A <= bank_a(to_integer(addr_10));
            end if;
        end if;
    end process;

    -- Bank B
    process(iCLK)
    begin
        if rising_edge(iCLK) then
            if iWE_B = '1' then
                bank_b(to_integer(addr_10)) <= iWR_DAT;
            end if;
            if iRE_B = '1' then
                oRD_DAT_B <= bank_b(to_integer(addr_10));
            end if;
        end if;
    end process;

end architecture sim;
