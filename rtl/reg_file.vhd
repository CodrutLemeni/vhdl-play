-- R1600 Register File
-- 16 x 16-bit, 2 read ports (combinational), 1 write port (synchronous)
-- Infers distributed RAM for 200 MHz timing

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.r1600_pkg.all;

entity reg_file is
    port (
        iCLK    : in  std_logic;
        iRST    : in  std_logic;
        -- Write port
        iWR_EN  : in  std_logic;
        iWR_ADDR: in  std_logic_vector(REG_ADR_W-1 downto 0);
        iWR_DATA: in  std_logic_vector(DATA_W-1 downto 0);
        -- Read port A (Rt)
        iRD_A_ADDR: in  std_logic_vector(REG_ADR_W-1 downto 0);
        oRD_A_DATA: out std_logic_vector(DATA_W-1 downto 0);
        -- Read port B (Rs)
        iRD_B_ADDR: in  std_logic_vector(REG_ADR_W-1 downto 0);
        oRD_B_DATA: out std_logic_vector(DATA_W-1 downto 0)
    );
end entity reg_file;

architecture rtl of reg_file is
    type reg_array_t is array(0 to 2**REG_ADR_W-1) of std_logic_vector(DATA_W-1 downto 0);
    signal regs : reg_array_t := (others => (others => '0'));
begin

    -- Synchronous write
    process(iCLK)
    begin
        if rising_edge(iCLK) then
            if iRST = '1' then
                regs <= (others => (others => '0'));
            elsif iWR_EN = '1' then
                regs(to_integer(unsigned(iWR_ADDR))) <= iWR_DATA;
            end if;
        end if;
    end process;

    -- Combinational read with write-through
    oRD_A_DATA <= iWR_DATA when (iWR_EN = '1' and iWR_ADDR = iRD_A_ADDR) else
                  regs(to_integer(unsigned(iRD_A_ADDR)));
    oRD_B_DATA <= iWR_DATA when (iWR_EN = '1' and iWR_ADDR = iRD_B_ADDR) else
                  regs(to_integer(unsigned(iRD_B_ADDR)));

end architecture rtl;
