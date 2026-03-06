library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.r1600_pkg.all;

library std;
use std.env.all;

entity alu_tb is
end entity alu_tb;

architecture sim of alu_tb is
    signal op       : alu_op_t := ALU_PASS;
    signal a        : std_logic_vector(DATA_W-1 downto 0) := (others => '0');
    signal b        : std_logic_vector(DATA_W-1 downto 0) := (others => '0');
    signal cf_in    : std_logic := '0';
    signal result   : std_logic_vector(DATA_W-1 downto 0);
    signal cf_out   : std_logic;
    signal zf_out   : std_logic;
    signal cf_upd   : std_logic;
    signal zf_upd   : std_logic;
begin
    uut : entity work.alu
        port map (
            iOP     => op,
            iA      => a,
            iB      => b,
            iCF     => cf_in,
            oRESULT => result,
            oCF     => cf_out,
            oZF     => zf_out,
            oCF_UPD => cf_upd,
            oZF_UPD => zf_upd
        );

    process
        procedure check_case(
            constant name          : string;
            constant op_v          : alu_op_t;
            constant a_v           : std_logic_vector(DATA_W-1 downto 0);
            constant b_v           : std_logic_vector(DATA_W-1 downto 0);
            constant cf_in_v       : std_logic;
            constant exp_result_v  : std_logic_vector(DATA_W-1 downto 0);
            constant exp_cf_v      : std_logic;
            constant exp_zf_v      : std_logic;
            constant exp_cf_upd_v  : std_logic;
            constant exp_zf_upd_v  : std_logic
        ) is
        begin
            op <= op_v;
            a <= a_v;
            b <= b_v;
            cf_in <= cf_in_v;
            wait for 1 ns;

            assert result = exp_result_v
                report name & ": unexpected result"
                severity failure;
            assert cf_out = exp_cf_v
                report name & ": unexpected carry flag"
                severity failure;
            assert zf_out = exp_zf_v
                report name & ": unexpected zero flag"
                severity failure;
            assert cf_upd = exp_cf_upd_v
                report name & ": unexpected carry update flag"
                severity failure;
            assert zf_upd = exp_zf_upd_v
                report name & ": unexpected zero update flag"
                severity failure;
        end procedure;
    begin
        check_case("ld", ALU_LD, x"1234", x"00AA", '1', x"00AA", '1', '0', '0', '1');
        check_case("and zero", ALU_AND, x"00F0", x"0F0F", '0', x"0000", '0', '1', '0', '1');
        check_case("or", ALU_OR, x"00F0", x"0F0F", '0', x"0FFF", '0', '0', '0', '1');
        check_case("xor", ALU_XOR, x"00FF", x"0F0F", '0', x"0FF0", '0', '0', '0', '1');
        check_case("add", ALU_ADD, x"00AA", x"0055", '0', x"00FF", '0', '0', '1', '1');
        check_case("add carry", ALU_ADD, x"FFFF", x"0001", '0', x"0000", '1', '1', '1', '1');
        check_case("addc", ALU_ADDC, x"0001", x"0001", '1', x"0003", '0', '0', '1', '1');
        check_case("sub no borrow", ALU_SUB, x"0005", x"0005", '0', x"0000", '1', '1', '1', '1');
        check_case("sub borrow", ALU_SUB, x"0000", x"0001", '0', x"FFFF", '0', '0', '1', '1');
        check_case("subc with carry clear", ALU_SUBC, x"0005", x"0001", '0', x"0003", '1', '0', '1', '1');
        check_case("sl0", ALU_SL0, x"8001", x"0000", '0', x"0002", '1', '0', '1', '1');
        check_case("sr1", ALU_SR1, x"0001", x"0000", '0', x"8000", '1', '0', '1', '1');
        check_case("src", ALU_SRC, x"0002", x"0000", '1', x"8001", '0', '0', '1', '1');
        check_case("rl", ALU_RL, x"8001", x"0000", '0', x"0003", '1', '0', '1', '1');
        check_case("rr", ALU_RR, x"0001", x"0000", '0', x"8000", '1', '0', '1', '1');
        check_case("rln", ALU_RLN, x"1234", x"0000", '1', x"2341", '1', '0', '0', '1');
        check_case("rrn", ALU_RRN, x"1234", x"0000", '0', x"4123", '0', '0', '0', '1');
        check_case("exb", ALU_EXB, x"1234", x"0000", '0', x"3412", '0', '0', '0', '1');
        check_case("rvb", ALU_RVB, x"0003", x"0000", '1', x"C000", '1', '0', '0', '1');
        check_case("pass", ALU_PASS, x"55AA", x"1234", '1', x"55AA", '1', '0', '0', '0');

        report "PASS: alu_tb" severity note;
        stop;
        wait;
    end process;
end architecture sim;
