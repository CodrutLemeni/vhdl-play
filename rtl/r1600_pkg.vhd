-- R1600 16-bit RISC Processor - Package
-- Types, constants, and opcode encoding definitions
--
-- Opcode encoding scheme (16-bit opcode word, upper half of 32-bit PM word):
--   [15:13] = Condition field (3 bits)
--   [12:11] = Format group (2 bits):
--     "0x" (bit[12]=0): ALU RR/RK/RRK format
--       [12:9]=op(4), [8:5]=Rt(4), [4:1]=Rs(4), [0]=imm_flag
--     "10": R-format + IO-format
--       [10]=0: R-format (shift/rotate + register branches)
--         [9:5]=sub_op(5), [4:1]=Rt(4), [0]=0
--       [10]=1: IO-format (IN/OUT)
--         [9]=dir(0=IN,1=OUT), [8:5]=Rt(4), [4:1]=Rs(4), [0]=imm_flag
--     "11": I-format + K-format
--       [10]=0: I-format (NOP/DI/EI/PUSHF/POPF/PUSHI/POPI/RET/RETI/DRET/DRETI)
--         [9:0]=opcode(10)
--       [10]=1: K-format (JMP/DJMP/CALL/CALLI/DCALL/DCALLI with immediate)
--         [9:1]=opcode(9), [0]=1

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

package r1600_pkg is

    ---------------------------------------------------------------------------
    -- Width constants
    ---------------------------------------------------------------------------
    constant DATA_W     : natural := 16;
    constant PM_ADR_W   : natural := 15;   -- 32K program memory
    constant DM_ADR_W   : natural := 32;   -- 4G data memory
    constant REG_ADR_W  : natural := 4;    -- 16 registers
    constant INSTR_W    : natural := 32;   -- full instruction word (from PM)
    constant STACK_DEPTH: natural := 16;   -- PC stack and flag stack depth
    constant STACK_PTR_W: natural := 4;    -- log2(16)

    ---------------------------------------------------------------------------
    -- Interrupt / debug vectors
    ---------------------------------------------------------------------------
    constant INT_VECTOR : std_logic_vector(PM_ADR_W-1 downto 0) := "000000000001000"; -- 0x0008 = 8
    constant DBG_VECTOR : std_logic_vector(PM_ADR_W-1 downto 0) := "000000000010000"; -- 0x0010 = 16

    ---------------------------------------------------------------------------
    -- Conditional execution field encoding (bits [15:13] of opcode)
    ---------------------------------------------------------------------------
    constant COND_ALWAYS : std_logic_vector(2 downto 0) := "000";
    constant COND_TEST   : std_logic_vector(2 downto 0) := "001";
    constant COND_IFNZ   : std_logic_vector(2 downto 0) := "010";
    constant COND_IFZ    : std_logic_vector(2 downto 0) := "011";
    constant COND_IFC    : std_logic_vector(2 downto 0) := "100";
    constant COND_IFNC   : std_logic_vector(2 downto 0) := "101";
    constant COND_IFG    : std_logic_vector(2 downto 0) := "110";
    constant COND_IFNG   : std_logic_vector(2 downto 0) := "111";

    ---------------------------------------------------------------------------
    -- ALU operation encoding
    ---------------------------------------------------------------------------
    type alu_op_t is (
        ALU_LD, ALU_AND, ALU_OR, ALU_XOR,
        ALU_ADD, ALU_ADDC, ALU_SUB, ALU_SUBC,
        ALU_SL0, ALU_SL1, ALU_SLA, ALU_SLC, ALU_RL,
        ALU_SR0, ALU_SR1, ALU_SRA, ALU_SRC, ALU_RR,
        ALU_RLN, ALU_RRN, ALU_EXB, ALU_RVB,
        ALU_PASS  -- pass through (NOP, branches etc.)
    );

    ---------------------------------------------------------------------------
    -- Instruction format type
    ---------------------------------------------------------------------------
    type instr_fmt_t is (
        FMT_RR,   -- register-register (ALU)
        FMT_RRK,  -- register-register-immediate (IN/OUT type 2)
        FMT_RK,   -- register-immediate (ALU with imm)
        FMT_R,    -- single register (shift/rotate/register branches)
        FMT_IO,   -- IN/OUT format
        FMT_I,    -- implicit (NOP, DI, EI, RET, etc.)
        FMT_K     -- immediate-only (JMP kkkk, CALL kkkk, etc.)
    );

    ---------------------------------------------------------------------------
    -- Branch type
    ---------------------------------------------------------------------------
    type branch_type_t is (
        BR_NONE,
        BR_JMP, BR_CALL, BR_CALLI,
        BR_DJMP, BR_DCALL, BR_DCALLI,
        BR_RET, BR_RETI,
        BR_DRET, BR_DRETI
    );

    ---------------------------------------------------------------------------
    -- Opcode encoding constants
    ---------------------------------------------------------------------------

    -- ALU RR/RK format opcodes (bits [12:9], format group bit[12]=0)
    -- Only ops 0-7 (bit[12]=0) are valid in this group
    constant OP_LD   : std_logic_vector(3 downto 0) := "0000";
    constant OP_AND  : std_logic_vector(3 downto 0) := "0001";
    constant OP_OR   : std_logic_vector(3 downto 0) := "0010";
    constant OP_XOR  : std_logic_vector(3 downto 0) := "0011";
    constant OP_ADD  : std_logic_vector(3 downto 0) := "0100";
    constant OP_ADDC : std_logic_vector(3 downto 0) := "0101";
    constant OP_SUB  : std_logic_vector(3 downto 0) := "0110";
    constant OP_SUBC : std_logic_vector(3 downto 0) := "0111";

    -- R format sub_op (bits [9:5], within format group "10", sub-format [10]=0)
    -- Shift/rotate/bit manipulation (14 ops)
    constant SOP_SL0 : std_logic_vector(4 downto 0) := "00000";
    constant SOP_SL1 : std_logic_vector(4 downto 0) := "00001";
    constant SOP_SLA : std_logic_vector(4 downto 0) := "00010";
    constant SOP_SLC : std_logic_vector(4 downto 0) := "00011";
    constant SOP_RL  : std_logic_vector(4 downto 0) := "00100";
    constant SOP_SR0 : std_logic_vector(4 downto 0) := "00101";
    constant SOP_SR1 : std_logic_vector(4 downto 0) := "00110";
    constant SOP_SRA : std_logic_vector(4 downto 0) := "00111";
    constant SOP_SRC : std_logic_vector(4 downto 0) := "01000";
    constant SOP_RR  : std_logic_vector(4 downto 0) := "01001";
    constant SOP_RLN : std_logic_vector(4 downto 0) := "01010";
    constant SOP_RRN : std_logic_vector(4 downto 0) := "01011";
    constant SOP_EXB : std_logic_vector(4 downto 0) := "01100";
    constant SOP_RVB : std_logic_vector(4 downto 0) := "01101";
    -- Register branch sub_ops (6 ops)
    constant SOP_JMP_R   : std_logic_vector(4 downto 0) := "01110";
    constant SOP_DJMP_R  : std_logic_vector(4 downto 0) := "01111";
    constant SOP_CALL_R  : std_logic_vector(4 downto 0) := "10000";
    constant SOP_CALLI_R : std_logic_vector(4 downto 0) := "10001";
    constant SOP_DCALL_R : std_logic_vector(4 downto 0) := "10010";
    constant SOP_DCALLI_R: std_logic_vector(4 downto 0) := "10011";

    -- I format opcodes (bits [9:0], within format group "11", sub-format [10]=0)
    constant IOP_NOP   : std_logic_vector(9 downto 0) := "0000000000";
    constant IOP_DI    : std_logic_vector(9 downto 0) := "0000000001";
    constant IOP_EI    : std_logic_vector(9 downto 0) := "0000000010";
    constant IOP_PUSHF : std_logic_vector(9 downto 0) := "0000000011";
    constant IOP_POPF  : std_logic_vector(9 downto 0) := "0000000100";
    constant IOP_PUSHI : std_logic_vector(9 downto 0) := "0000000101";
    constant IOP_POPI  : std_logic_vector(9 downto 0) := "0000000110";
    constant IOP_RET   : std_logic_vector(9 downto 0) := "0000000111";
    constant IOP_RETI  : std_logic_vector(9 downto 0) := "0000001000";
    constant IOP_DRET  : std_logic_vector(9 downto 0) := "0000001001";
    constant IOP_DRETI : std_logic_vector(9 downto 0) := "0000001010";

    -- K format sub_op (bits [9:1], within format group "11", sub-format [10]=1)
    -- bit[0] is always 1 for K format
    constant KOP_JMP   : std_logic_vector(8 downto 0) := "000000000";
    constant KOP_DJMP  : std_logic_vector(8 downto 0) := "000000001";
    constant KOP_CALL  : std_logic_vector(8 downto 0) := "000000010";
    constant KOP_CALLI : std_logic_vector(8 downto 0) := "000000011";
    constant KOP_DCALL : std_logic_vector(8 downto 0) := "000000100";
    constant KOP_DCALLI: std_logic_vector(8 downto 0) := "000000101";

    ---------------------------------------------------------------------------
    -- Decoded control signals record
    ---------------------------------------------------------------------------
    type ctrl_t is record
        alu_op      : alu_op_t;
        fmt         : instr_fmt_t;
        rt_addr     : std_logic_vector(REG_ADR_W-1 downto 0);
        rs_addr     : std_logic_vector(REG_ADR_W-1 downto 0);
        imm         : std_logic_vector(DATA_W-1 downto 0);
        cond        : std_logic_vector(2 downto 0);
        mem_read    : std_logic;
        mem_write   : std_logic;
        branch_type : branch_type_t;
        is_delayed  : std_logic;
        wb_en       : std_logic;
        flag_update : std_logic;
        pushf       : std_logic;
        popf        : std_logic;
        pushi       : std_logic;
        popi        : std_logic;
        int_enable  : std_logic;  -- EI
        int_disable : std_logic;  -- DI
        uses_imm    : std_logic;  -- instruction uses immediate (for Rs mux)
        uses_rs     : std_logic;  -- instruction uses Rs register (for RRK address calc)
    end record ctrl_t;

    constant CTRL_NOP : ctrl_t := (
        alu_op      => ALU_PASS,
        fmt         => FMT_I,
        rt_addr     => (others => '0'),
        rs_addr     => (others => '0'),
        imm         => (others => '0'),
        cond        => COND_ALWAYS,
        mem_read    => '0',
        mem_write   => '0',
        branch_type => BR_NONE,
        is_delayed  => '0',
        wb_en       => '0',
        flag_update => '0',
        pushf       => '0',
        popf        => '0',
        pushi       => '0',
        popi        => '0',
        int_enable  => '0',
        int_disable => '0',
        uses_imm    => '0',
        uses_rs     => '0'
    );

    ---------------------------------------------------------------------------
    -- Pipeline register records
    ---------------------------------------------------------------------------
    type if_id_t is record
        instr   : std_logic_vector(INSTR_W-1 downto 0);
        pc      : std_logic_vector(PM_ADR_W-1 downto 0);
        valid   : std_logic;
    end record if_id_t;

    constant IF_ID_NOP : if_id_t := (
        instr => (others => '0'),
        pc    => (others => '0'),
        valid => '0'
    );

    type id_ex1_t is record
        ctrl    : ctrl_t;
        rt_data : std_logic_vector(DATA_W-1 downto 0);
        rs_data : std_logic_vector(DATA_W-1 downto 0);
        pc      : std_logic_vector(PM_ADR_W-1 downto 0);
        exec_en : std_logic;   -- condition evaluated true
        test_en : std_logic;   -- TEST mode: update flags only
        valid   : std_logic;
    end record id_ex1_t;

    constant ID_EX1_NOP : id_ex1_t := (
        ctrl    => CTRL_NOP,
        rt_data => (others => '0'),
        rs_data => (others => '0'),
        pc      => (others => '0'),
        exec_en => '0',
        test_en => '0',
        valid   => '0'
    );

    type ex1_ex2_t is record
        ctrl      : ctrl_t;
        alu_result: std_logic_vector(DATA_W-1 downto 0);
        alu_cf    : std_logic;
        alu_zf    : std_logic;
        dm_addr   : std_logic_vector(DM_ADR_W-1 downto 0);
        wr_data   : std_logic_vector(DATA_W-1 downto 0);
        exec_en   : std_logic;
        test_en   : std_logic;
        valid     : std_logic;
        -- Captured flag stack output for POPF/POPI/RETI
        pop_cf    : std_logic;
        pop_zf    : std_logic;
        pop_if    : std_logic;
    end record ex1_ex2_t;

    constant EX1_EX2_NOP : ex1_ex2_t := (
        ctrl       => CTRL_NOP,
        alu_result => (others => '0'),
        alu_cf     => '0',
        alu_zf     => '0',
        dm_addr    => (others => '0'),
        wr_data    => (others => '0'),
        exec_en    => '0',
        test_en    => '0',
        valid      => '0',
        pop_cf     => '0',
        pop_zf     => '0',
        pop_if     => '0'
    );

    type ex2_wb_t is record
        ctrl      : ctrl_t;
        result    : std_logic_vector(DATA_W-1 downto 0);
        alu_cf    : std_logic;
        alu_zf    : std_logic;
        exec_en   : std_logic;
        test_en   : std_logic;
        valid     : std_logic;
        -- Captured flag stack output for POPF/POPI/RETI
        pop_cf    : std_logic;
        pop_zf    : std_logic;
        pop_if    : std_logic;
    end record ex2_wb_t;

    constant EX2_WB_NOP : ex2_wb_t := (
        ctrl    => CTRL_NOP,
        result  => (others => '0'),
        alu_cf  => '0',
        alu_zf  => '0',
        exec_en => '0',
        test_en => '0',
        valid   => '0',
        pop_cf  => '0',
        pop_zf  => '0',
        pop_if  => '0'
    );

    ---------------------------------------------------------------------------
    -- Helper function: reverse bits
    ---------------------------------------------------------------------------
    function reverse_bits(v : std_logic_vector) return std_logic_vector;

end package r1600_pkg;

package body r1600_pkg is

    function reverse_bits(v : std_logic_vector) return std_logic_vector is
        variable result : std_logic_vector(v'range);
    begin
        for i in v'range loop
            result(v'high - i + v'low) := v(i);
        end loop;
        return result;
    end function;

end package body r1600_pkg;
