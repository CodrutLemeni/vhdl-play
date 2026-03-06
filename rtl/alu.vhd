-- R1600 ALU
-- Logic, arithmetic, shift/rotate, bit manipulation operations
-- All operations are purely combinational for single-cycle execution

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.r1600_pkg.all;

entity alu is
    port (
        iOP       : in  alu_op_t;
        iA        : in  std_logic_vector(DATA_W-1 downto 0);  -- Rt value
        iB        : in  std_logic_vector(DATA_W-1 downto 0);  -- Rs value or immediate
        iCF       : in  std_logic;                             -- current carry flag
        oRESULT   : out std_logic_vector(DATA_W-1 downto 0);
        oCF       : out std_logic;                             -- new carry flag
        oZF       : out std_logic;                             -- new zero flag
        oCF_UPD   : out std_logic;                             -- CF should be updated
        oZF_UPD   : out std_logic                              -- ZF should be updated
    );
end entity alu;

architecture rtl of alu is
    signal result_i  : std_logic_vector(DATA_W-1 downto 0);
    signal cf_i      : std_logic;
    signal cf_upd_i  : std_logic;
    signal zf_upd_i  : std_logic;
    signal add_ext   : unsigned(DATA_W downto 0);
    signal sub_ext   : unsigned(DATA_W downto 0);
begin

    process(all)
        variable a_u   : unsigned(DATA_W downto 0);
        variable b_u   : unsigned(DATA_W downto 0);
        variable sum   : unsigned(DATA_W downto 0);
        variable diff  : unsigned(DATA_W downto 0);
    begin
        result_i  <= (others => '0');
        cf_i      <= iCF;  -- default: preserve
        cf_upd_i  <= '0';
        zf_upd_i  <= '0';

        a_u := unsigned('0' & iA);
        b_u := unsigned('0' & iB);

        case iOP is
            -- Logic group: ZF updated, CF unchanged
            when ALU_LD =>
                result_i <= iB;
                zf_upd_i <= '1';

            when ALU_AND =>
                result_i <= iA and iB;
                zf_upd_i <= '1';

            when ALU_OR =>
                result_i <= iA or iB;
                zf_upd_i <= '1';

            when ALU_XOR =>
                result_i <= iA xor iB;
                zf_upd_i <= '1';

            -- Arithmetic group: ZF and CF updated
            when ALU_ADD =>
                sum := a_u + b_u;
                result_i <= std_logic_vector(sum(DATA_W-1 downto 0));
                cf_i     <= sum(DATA_W);
                cf_upd_i <= '1';
                zf_upd_i <= '1';

            when ALU_ADDC =>
                if iCF = '1' then
                    sum := a_u + b_u + 1;
                else
                    sum := a_u + b_u;
                end if;
                result_i <= std_logic_vector(sum(DATA_W-1 downto 0));
                cf_i     <= sum(DATA_W);
                cf_upd_i <= '1';
                zf_upd_i <= '1';

            when ALU_SUB =>
                diff := a_u - b_u;
                result_i <= std_logic_vector(diff(DATA_W-1 downto 0));
                cf_i     <= not diff(DATA_W);  -- CF = NOT borrow
                cf_upd_i <= '1';
                zf_upd_i <= '1';

            when ALU_SUBC =>
                if iCF = '1' then
                    diff := a_u - b_u;
                else
                    diff := a_u - b_u - 1;
                end if;
                result_i <= std_logic_vector(diff(DATA_W-1 downto 0));
                cf_i     <= not diff(DATA_W);  -- CF = NOT borrow
                cf_upd_i <= '1';
                zf_upd_i <= '1';

            -- Shift left group
            when ALU_SL0 =>
                cf_i     <= iA(DATA_W-1);
                result_i <= iA(DATA_W-2 downto 0) & '0';
                cf_upd_i <= '1';
                zf_upd_i <= '1';

            when ALU_SL1 =>
                cf_i     <= iA(DATA_W-1);
                result_i <= iA(DATA_W-2 downto 0) & '1';
                cf_upd_i <= '1';
                zf_upd_i <= '1';

            when ALU_SLA =>
                cf_i     <= iA(DATA_W-1);
                result_i <= iA(DATA_W-2 downto 0) & iA(0);  -- replicate LSB
                cf_upd_i <= '1';
                zf_upd_i <= '1';

            when ALU_SLC =>
                cf_i     <= iA(DATA_W-1);
                result_i <= iA(DATA_W-2 downto 0) & iCF;
                cf_upd_i <= '1';
                zf_upd_i <= '1';

            when ALU_RL =>
                cf_i     <= iA(DATA_W-1);
                result_i <= iA(DATA_W-2 downto 0) & iA(DATA_W-1);
                cf_upd_i <= '1';
                zf_upd_i <= '1';

            -- Shift right group
            when ALU_SR0 =>
                cf_i     <= iA(0);
                result_i <= '0' & iA(DATA_W-1 downto 1);
                cf_upd_i <= '1';
                zf_upd_i <= '1';

            when ALU_SR1 =>
                cf_i     <= iA(0);
                result_i <= '1' & iA(DATA_W-1 downto 1);
                cf_upd_i <= '1';
                zf_upd_i <= '1';

            when ALU_SRA =>
                cf_i     <= iA(0);
                result_i <= iA(DATA_W-1) & iA(DATA_W-1 downto 1);  -- MSB preserved
                cf_upd_i <= '1';
                zf_upd_i <= '1';

            when ALU_SRC =>
                cf_i     <= iA(0);
                result_i <= iCF & iA(DATA_W-1 downto 1);
                cf_upd_i <= '1';
                zf_upd_i <= '1';

            when ALU_RR =>
                cf_i     <= iA(0);
                result_i <= iA(0) & iA(DATA_W-1 downto 1);
                cf_upd_i <= '1';
                zf_upd_i <= '1';

            -- Bit manipulation group: ZF updated, CF unchanged
            when ALU_RLN =>
                result_i <= iA(DATA_W-5 downto 0) & iA(DATA_W-1 downto DATA_W-4);
                zf_upd_i <= '1';

            when ALU_RRN =>
                result_i <= iA(3 downto 0) & iA(DATA_W-1 downto 4);
                zf_upd_i <= '1';

            when ALU_EXB =>
                result_i <= iA(7 downto 0) & iA(DATA_W-1 downto 8);
                zf_upd_i <= '1';

            when ALU_RVB =>
                result_i <= reverse_bits(iA);
                zf_upd_i <= '1';

            -- Pass-through (NOP, branch control, etc.)
            when ALU_PASS =>
                result_i <= iA;
                -- no flag updates

        end case;
    end process;

    oRESULT <= result_i;
    oCF     <= cf_i;
    oZF     <= '1' when result_i = x"0000" and (zf_upd_i = '1') else
               '0' when zf_upd_i = '1' else
               '0';  -- default; actual ZF retention handled at pipeline level
    oCF_UPD <= cf_upd_i;
    oZF_UPD <= zf_upd_i;

end architecture rtl;
