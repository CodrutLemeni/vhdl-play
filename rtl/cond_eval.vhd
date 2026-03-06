-- R1600 Conditional Execution Evaluator
-- Evaluates the 3-bit condition field against current flags

library ieee;
use ieee.std_logic_1164.all;
use work.r1600_pkg.all;

entity cond_eval is
    port (
        iCOND    : in  std_logic_vector(2 downto 0);
        iCF      : in  std_logic;
        iZF      : in  std_logic;
        oEXEC_EN : out std_logic;  -- execute the instruction
        oTEST_EN : out std_logic   -- TEST mode: flags only, no writeback
    );
end entity cond_eval;

architecture rtl of cond_eval is
begin
    process(all)
    begin
        oEXEC_EN <= '0';
        oTEST_EN <= '0';

        case iCOND is
            when COND_ALWAYS =>
                oEXEC_EN <= '1';
            when COND_TEST =>
                oEXEC_EN <= '1';
                oTEST_EN <= '1';
            when COND_IFNZ =>
                oEXEC_EN <= not iZF;
            when COND_IFZ =>
                oEXEC_EN <= iZF;
            when COND_IFC =>
                oEXEC_EN <= iCF;
            when COND_IFNC =>
                oEXEC_EN <= not iCF;
            when COND_IFG =>
                oEXEC_EN <= (not iCF) and (not iZF);
            when COND_IFNG =>
                oEXEC_EN <= iCF or iZF;
            when others =>
                oEXEC_EN <= '0';
        end case;
    end process;

end architecture rtl;
