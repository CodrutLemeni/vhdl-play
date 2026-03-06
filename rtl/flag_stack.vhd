-- R1600 Flag Stack
-- 16-level x 3-bit LIFO for flag save/restore (CF, ZF, IF)

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.r1600_pkg.all;

entity flag_stack is
    port (
        iCLK    : in  std_logic;
        iRST    : in  std_logic;
        iPUSH   : in  std_logic;
        iPOP    : in  std_logic;
        iCF     : in  std_logic;
        iZF     : in  std_logic;
        iIF     : in  std_logic;
        oCF     : out std_logic;
        oZF     : out std_logic;
        oIF     : out std_logic
    );
end entity flag_stack;

architecture rtl of flag_stack is
    type stack_array_t is array(0 to STACK_DEPTH-1) of std_logic_vector(2 downto 0);
    signal stack : stack_array_t := (others => (others => '0'));
    signal sp    : unsigned(STACK_PTR_W-1 downto 0) := (others => '0');
    signal top   : std_logic_vector(2 downto 0);
begin

    process(iCLK)
    begin
        if rising_edge(iCLK) then
            if iRST = '1' then
                sp <= (others => '0');
            elsif iPUSH = '1' then
                stack(to_integer(sp)) <= iCF & iZF & iIF;
                sp <= sp + 1;
            elsif iPOP = '1' then
                sp <= sp - 1;
            end if;
        end if;
    end process;

    top <= stack(to_integer(sp - 1)) when sp /= "0000" else "000";
    oCF <= top(2);
    oZF <= top(1);
    oIF <= top(0);

end architecture rtl;
