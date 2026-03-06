-- R1600 Instruction Decoder
-- Decodes 32-bit instruction word into control signals
-- Uses the clean [12:11] format group encoding

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.r1600_pkg.all;

entity decode is
    port (
        iINSTR  : in  std_logic_vector(INSTR_W-1 downto 0);
        iVALID  : in  std_logic;
        oCTRL   : out ctrl_t
    );
end entity decode;

architecture rtl of decode is
    -- PM delivers 32 bits: iINSTR(31:0)
    -- Upper 16 bits [31:16] = opcode half
    -- Lower 16 bits [15:0]  = immediate half
    alias opcode : std_logic_vector(15 downto 0) is iINSTR(31 downto 16);
    alias imm16  : std_logic_vector(15 downto 0) is iINSTR(15 downto 0);

    -- Common field aliases within the 16-bit opcode
    alias cond_field : std_logic_vector(2 downto 0) is opcode(15 downto 13);
    alias fmt_group  : std_logic_vector(1 downto 0) is opcode(12 downto 11);
    alias sub_fmt    : std_logic is opcode(10);

    -- ALU RR/RK/RRK fields (format group bit[12]=0)
    alias alu_op_field : std_logic_vector(3 downto 0) is opcode(12 downto 9);
    alias alu_rt       : std_logic_vector(3 downto 0) is opcode(8 downto 5);
    alias alu_rs       : std_logic_vector(3 downto 0) is opcode(4 downto 1);
    alias alu_imm_flag : std_logic is opcode(0);

    -- R format fields (format group "10", sub_fmt=0)
    alias r_sub_op : std_logic_vector(4 downto 0) is opcode(9 downto 5);
    alias r_rt     : std_logic_vector(3 downto 0) is opcode(4 downto 1);

    -- IO format fields (format group "10", sub_fmt=1)
    alias io_dir   : std_logic is opcode(9);       -- 0=IN, 1=OUT
    alias io_rt    : std_logic_vector(3 downto 0) is opcode(8 downto 5);
    alias io_rs    : std_logic_vector(3 downto 0) is opcode(4 downto 1);
    alias io_imm   : std_logic is opcode(0);

    -- I format fields (format group "11", sub_fmt=0)
    alias i_opcode : std_logic_vector(9 downto 0) is opcode(9 downto 0);

    -- K format fields (format group "11", sub_fmt=1)
    alias k_opcode : std_logic_vector(8 downto 0) is opcode(9 downto 1);
begin

    process(all)
        variable ctrl : ctrl_t;
    begin
        ctrl := CTRL_NOP;

        if iVALID = '1' then
            ctrl.cond := cond_field;

            if opcode(12) = '0' then
                ----------------------------------------------------------------
                -- ALU RR / RK / RRK format (ops 0-7)
                ----------------------------------------------------------------
                ctrl.rt_addr := alu_rt;
                ctrl.rs_addr := alu_rs;
                ctrl.imm     := imm16;

                -- RK: imm_flag=1, Rs=0000
                -- RRK: imm_flag=1, Rs/=0000
                -- RR: imm_flag=0
                if alu_imm_flag = '1' and alu_rs = "0000" then
                    ctrl.fmt      := FMT_RK;
                    ctrl.uses_imm := '1';
                elsif alu_imm_flag = '1' then
                    ctrl.fmt      := FMT_RRK;
                    ctrl.uses_imm := '1';
                    ctrl.uses_rs  := '1';
                else
                    ctrl.fmt      := FMT_RR;
                    ctrl.uses_rs  := '1';
                end if;

                case alu_op_field is
                    when OP_LD =>
                        ctrl.alu_op     := ALU_LD;
                        ctrl.wb_en      := '1';
                        ctrl.flag_update := '1';
                    when OP_AND =>
                        ctrl.alu_op     := ALU_AND;
                        ctrl.wb_en      := '1';
                        ctrl.flag_update := '1';
                    when OP_OR =>
                        ctrl.alu_op     := ALU_OR;
                        ctrl.wb_en      := '1';
                        ctrl.flag_update := '1';
                    when OP_XOR =>
                        ctrl.alu_op     := ALU_XOR;
                        ctrl.wb_en      := '1';
                        ctrl.flag_update := '1';
                    when OP_ADD =>
                        ctrl.alu_op     := ALU_ADD;
                        ctrl.wb_en      := '1';
                        ctrl.flag_update := '1';
                    when OP_ADDC =>
                        ctrl.alu_op     := ALU_ADDC;
                        ctrl.wb_en      := '1';
                        ctrl.flag_update := '1';
                    when OP_SUB =>
                        ctrl.alu_op     := ALU_SUB;
                        ctrl.wb_en      := '1';
                        ctrl.flag_update := '1';
                    when OP_SUBC =>
                        ctrl.alu_op     := ALU_SUBC;
                        ctrl.wb_en      := '1';
                        ctrl.flag_update := '1';
                    when others =>
                        ctrl := CTRL_NOP;
                end case;

            elsif fmt_group = "10" then
                if sub_fmt = '0' then
                    --------------------------------------------------------
                    -- R format: shift/rotate/bit-manip + register branches
                    --------------------------------------------------------
                    ctrl.fmt     := FMT_R;
                    ctrl.rt_addr := r_rt;
                    ctrl.wb_en   := '1';
                    ctrl.flag_update := '1';

                    case r_sub_op is
                        when SOP_SL0 => ctrl.alu_op := ALU_SL0;
                        when SOP_SL1 => ctrl.alu_op := ALU_SL1;
                        when SOP_SLA => ctrl.alu_op := ALU_SLA;
                        when SOP_SLC => ctrl.alu_op := ALU_SLC;
                        when SOP_RL  => ctrl.alu_op := ALU_RL;
                        when SOP_SR0 => ctrl.alu_op := ALU_SR0;
                        when SOP_SR1 => ctrl.alu_op := ALU_SR1;
                        when SOP_SRA => ctrl.alu_op := ALU_SRA;
                        when SOP_SRC => ctrl.alu_op := ALU_SRC;
                        when SOP_RR  => ctrl.alu_op := ALU_RR;
                        when SOP_RLN => ctrl.alu_op := ALU_RLN;
                        when SOP_RRN => ctrl.alu_op := ALU_RRN;
                        when SOP_EXB => ctrl.alu_op := ALU_EXB;
                        when SOP_RVB => ctrl.alu_op := ALU_RVB;

                        -- Register branch variants
                        when SOP_JMP_R =>
                            ctrl.alu_op      := ALU_PASS;
                            ctrl.branch_type := BR_JMP;
                            ctrl.wb_en       := '0';
                            ctrl.flag_update := '0';
                        when SOP_DJMP_R =>
                            ctrl.alu_op      := ALU_PASS;
                            ctrl.branch_type := BR_DJMP;
                            ctrl.is_delayed  := '1';
                            ctrl.wb_en       := '0';
                            ctrl.flag_update := '0';
                        when SOP_CALL_R =>
                            ctrl.alu_op      := ALU_PASS;
                            ctrl.branch_type := BR_CALL;
                            ctrl.wb_en       := '0';
                            ctrl.flag_update := '0';
                        when SOP_CALLI_R =>
                            ctrl.alu_op      := ALU_PASS;
                            ctrl.branch_type := BR_CALLI;
                            ctrl.wb_en       := '0';
                            ctrl.flag_update := '0';
                        when SOP_DCALL_R =>
                            ctrl.alu_op      := ALU_PASS;
                            ctrl.branch_type := BR_DCALL;
                            ctrl.is_delayed  := '1';
                            ctrl.wb_en       := '0';
                            ctrl.flag_update := '0';
                        when SOP_DCALLI_R =>
                            ctrl.alu_op      := ALU_PASS;
                            ctrl.branch_type := BR_DCALLI;
                            ctrl.is_delayed  := '1';
                            ctrl.wb_en       := '0';
                            ctrl.flag_update := '0';

                        when others =>
                            ctrl := CTRL_NOP;
                    end case;

                else
                    --------------------------------------------------------
                    -- IO format: IN / OUT
                    --------------------------------------------------------
                    ctrl.fmt      := FMT_IO;
                    ctrl.rt_addr  := io_rt;
                    ctrl.rs_addr  := io_rs;
                    ctrl.imm      := imm16;
                    ctrl.alu_op   := ALU_PASS;

                    if io_imm = '1' and io_rs /= "0000" then
                        -- RRK style: IN/OUT Rt, kkkk, Rs
                        ctrl.uses_imm := '1';
                        ctrl.uses_rs  := '1';
                    elsif io_imm = '1' then
                        -- RK style: IN/OUT Rt, kkkk
                        ctrl.uses_imm := '1';
                    else
                        ctrl.uses_rs := '1';
                    end if;

                    if io_dir = '0' then
                        -- IN: read from memory to register
                        ctrl.mem_read := '1';
                        ctrl.wb_en    := '1';
                    else
                        -- OUT: write register to memory
                        ctrl.mem_write := '1';
                        ctrl.wb_en     := '0';
                    end if;
                end if;

            elsif fmt_group = "11" then
                if sub_fmt = '0' then
                    --------------------------------------------------------
                    -- I format: implicit instructions
                    --------------------------------------------------------
                    ctrl.fmt := FMT_I;

                    case i_opcode is
                        when IOP_NOP   => null;
                        when IOP_DI    => ctrl.int_disable := '1';
                        when IOP_EI    => ctrl.int_enable  := '1';
                        when IOP_PUSHF => ctrl.pushf := '1';
                        when IOP_POPF  => ctrl.popf  := '1';
                        when IOP_PUSHI => ctrl.pushi := '1';
                        when IOP_POPI  => ctrl.popi  := '1';
                        when IOP_RET   => ctrl.branch_type := BR_RET;
                        when IOP_RETI  => ctrl.branch_type := BR_RETI;
                        when IOP_DRET =>
                            ctrl.branch_type := BR_DRET;
                            ctrl.is_delayed  := '1';
                        when IOP_DRETI =>
                            ctrl.branch_type := BR_DRETI;
                            ctrl.is_delayed  := '1';
                        when others => null;
                    end case;

                else
                    --------------------------------------------------------
                    -- K format: immediate-only branches
                    --------------------------------------------------------
                    ctrl.fmt      := FMT_K;
                    ctrl.imm      := imm16;
                    ctrl.uses_imm := '1';
                    ctrl.wb_en    := '0';

                    case k_opcode is
                        when KOP_JMP =>
                            ctrl.branch_type := BR_JMP;
                        when KOP_DJMP =>
                            ctrl.branch_type := BR_DJMP;
                            ctrl.is_delayed  := '1';
                        when KOP_CALL =>
                            ctrl.branch_type := BR_CALL;
                        when KOP_CALLI =>
                            ctrl.branch_type := BR_CALLI;
                        when KOP_DCALL =>
                            ctrl.branch_type := BR_DCALL;
                            ctrl.is_delayed  := '1';
                        when KOP_DCALLI =>
                            ctrl.branch_type := BR_DCALLI;
                            ctrl.is_delayed  := '1';
                        when others =>
                            ctrl := CTRL_NOP;
                    end case;
                end if;

            else
                ctrl := CTRL_NOP;
            end if;
        end if;

        oCTRL <= ctrl;
    end process;

end architecture rtl;
