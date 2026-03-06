library ieee;
use ieee.std_logic_1164.all;
use work.r1600_pkg.all;

library std;
use std.env.all;

entity cond_eval_tb is
end entity cond_eval_tb;

architecture sim of cond_eval_tb is
    signal cond    : std_logic_vector(2 downto 0) := (others => '0');
    signal cf      : std_logic := '0';
    signal zf      : std_logic := '0';
    signal exec_en : std_logic;
    signal test_en : std_logic;
begin
    uut : entity work.cond_eval
        port map (
            iCOND    => cond,
            iCF      => cf,
            iZF      => zf,
            oEXEC_EN => exec_en,
            oTEST_EN => test_en
        );

    process
        procedure check_case(
            constant name         : string;
            constant cond_v       : std_logic_vector(2 downto 0);
            constant cf_v         : std_logic;
            constant zf_v         : std_logic;
            constant exp_exec_en  : std_logic;
            constant exp_test_en  : std_logic
        ) is
        begin
            cond <= cond_v;
            cf <= cf_v;
            zf <= zf_v;
            wait for 1 ns;

            assert exec_en = exp_exec_en
                report name & ": unexpected execute enable"
                severity failure;
            assert test_en = exp_test_en
                report name & ": unexpected test enable"
                severity failure;
        end procedure;
    begin
        check_case("always", COND_ALWAYS, '0', '0', '1', '0');
        check_case("test", COND_TEST, '0', '0', '1', '1');
        check_case("ifnz true", COND_IFNZ, '0', '0', '1', '0');
        check_case("ifnz false", COND_IFNZ, '0', '1', '0', '0');
        check_case("ifz true", COND_IFZ, '0', '1', '1', '0');
        check_case("ifz false", COND_IFZ, '0', '0', '0', '0');
        check_case("ifc true", COND_IFC, '1', '0', '1', '0');
        check_case("ifc false", COND_IFC, '0', '0', '0', '0');
        check_case("ifnc true", COND_IFNC, '0', '0', '1', '0');
        check_case("ifnc false", COND_IFNC, '1', '0', '0', '0');
        check_case("ifg true", COND_IFG, '1', '0', '1', '0');
        check_case("ifg false on zero", COND_IFG, '1', '1', '0', '0');
        check_case("ifg false on borrow", COND_IFG, '0', '0', '0', '0');
        check_case("ifng true on borrow", COND_IFNG, '0', '0', '1', '0');
        check_case("ifng true on zero", COND_IFNG, '1', '1', '1', '0');
        check_case("ifng false", COND_IFNG, '1', '0', '0', '0');

        report "PASS: cond_eval_tb" severity note;
        stop;
        wait;
    end process;
end architecture sim;
