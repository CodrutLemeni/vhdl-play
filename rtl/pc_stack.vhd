-- R1600 PC Stack
-- 16-level x 15-bit LIFO for subroutine return addresses

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.r1600_pkg.all;

entity pc_stack is
    port (
        iCLK    : in  std_logic;
        iRST    : in  std_logic;
        iPUSH   : in  std_logic;
        iPOP    : in  std_logic;
        iDATA   : in  std_logic_vector(PM_ADR_W-1 downto 0);
        oDATA   : out std_logic_vector(PM_ADR_W-1 downto 0)
    );
end entity pc_stack;

architecture rtl of pc_stack is
    type stack_array_t is array(0 to STACK_DEPTH-1) of std_logic_vector(PM_ADR_W-1 downto 0);
    signal stack : stack_array_t := (others => (others => '0'));
    signal sp    : unsigned(STACK_PTR_W-1 downto 0) := (others => '0');
begin

    process(iCLK)
    begin
        if rising_edge(iCLK) then
            if iRST = '1' then
                sp <= (others => '0');
            elsif iPUSH = '1' then
                stack(to_integer(sp)) <= iDATA;
                sp <= sp + 1;
            elsif iPOP = '1' then
                sp <= sp - 1;
            end if;
        end if;
    end process;

    -- Top of stack: the last pushed value (sp-1)
    oDATA <= stack(to_integer(sp - 1)) when sp /= "0000" else (others => '0');

end architecture rtl;
