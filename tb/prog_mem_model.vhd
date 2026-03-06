-- R1600 Program Memory Simulation Model
-- 32K x 32-bit, initialized with test program
-- Synchronous read with 1-cycle latency

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.r1600_pkg.all;

entity prog_mem_model is
    port (
        iCLK    : in  std_logic;
        iADR    : in  std_logic_vector(PM_ADR_W-1 downto 0);
        iRE     : in  std_logic;
        oDAT    : out std_logic_vector(INSTR_W-1 downto 0)
    );
end entity prog_mem_model;

architecture sim of prog_mem_model is

    type mem_array_t is array(0 to 1023) of std_logic_vector(INSTR_W-1 downto 0);

    ---------------------------------------------------------------------------
    -- Instruction builder functions (new encoding scheme)
    ---------------------------------------------------------------------------

    -- ALU RR: cond(3) | 0 & op(3) | Rt(4) | Rs(4) | 0 | imm16=0000
    -- opcode[12]=0, [12:9]=op, [8:5]=Rt, [4:1]=Rs, [0]=0
    function make_rr(cond : integer; op : std_logic_vector(3 downto 0);
                     rt, rs : integer) return std_logic_vector is
        variable w : std_logic_vector(31 downto 0) := (others => '0');
    begin
        w(31 downto 29) := std_logic_vector(to_unsigned(cond, 3));
        w(28 downto 25) := op;
        w(24 downto 21) := std_logic_vector(to_unsigned(rt, 4));
        w(20 downto 17) := std_logic_vector(to_unsigned(rs, 4));
        w(16) := '0';  -- RR format (no immediate)
        return w;
    end function;

    -- ALU RK: cond(3) | op(4) | Rt(4) | 0000 | 1 | imm16
    function make_rk(cond : integer; op : std_logic_vector(3 downto 0);
                     rt : integer; imm : integer) return std_logic_vector is
        variable w : std_logic_vector(31 downto 0) := (others => '0');
    begin
        w(31 downto 29) := std_logic_vector(to_unsigned(cond, 3));
        w(28 downto 25) := op;
        w(24 downto 21) := std_logic_vector(to_unsigned(rt, 4));
        w(20 downto 17) := "0000";
        w(16) := '1';  -- RK format (with immediate)
        w(15 downto 0) := std_logic_vector(to_unsigned(imm, 16));
        return w;
    end function;

    -- R format: cond(3) | "10" | 0 | sub_op(5) | Rt(4) | 0 | 0...0
    -- opcode[12:11]="10", [10]=0, [9:5]=sub_op, [4:1]=Rt, [0]=0
    function make_r(cond : integer; sub_op : std_logic_vector(4 downto 0);
                    rt : integer) return std_logic_vector is
        variable w : std_logic_vector(31 downto 0) := (others => '0');
    begin
        w(31 downto 29) := std_logic_vector(to_unsigned(cond, 3));
        w(28 downto 27) := "10";  -- format group
        w(26)           := '0';   -- sub-format: R
        w(25 downto 21) := sub_op;
        w(20 downto 17) := std_logic_vector(to_unsigned(rt, 4));
        w(16)           := '0';
        return w;
    end function;

    -- I format: cond(3) | "11" | 0 | i_opcode(10) | 0...0
    -- opcode[12:11]="11", [10]=0, [9:0]=i_opcode
    function make_i(cond : integer; iop : std_logic_vector(9 downto 0))
                    return std_logic_vector is
        variable w : std_logic_vector(31 downto 0) := (others => '0');
    begin
        w(31 downto 29) := std_logic_vector(to_unsigned(cond, 3));
        w(28 downto 27) := "11";  -- format group
        w(26)           := '0';   -- sub-format: I
        w(25 downto 16) := iop;
        return w;
    end function;

    -- K format: cond(3) | "11" | 1 | k_opcode(9) | 1 | imm16
    -- opcode[12:11]="11", [10]=1, [9:1]=k_opcode, [0]=1
    function make_k(cond : integer; kop : std_logic_vector(8 downto 0);
                    imm : integer) return std_logic_vector is
        variable w : std_logic_vector(31 downto 0) := (others => '0');
    begin
        w(31 downto 29) := std_logic_vector(to_unsigned(cond, 3));
        w(28 downto 27) := "11";  -- format group
        w(26)           := '1';   -- sub-format: K
        w(25 downto 17) := kop;
        w(16)           := '1';   -- K format marker
        w(15 downto 0)  := std_logic_vector(to_unsigned(imm, 16));
        return w;
    end function;

    ---------------------------------------------------------------------------
    -- Test program
    ---------------------------------------------------------------------------
    signal mem : mem_array_t := (
        -- Address 0x0000: Reset vector - program starts here
        -- =====================================================

        -- Test 1: Load immediates into registers
        0  => make_rk(0, OP_LD, 1, 16#00AA#),    -- LD R1, 0x00AA
        1  => make_rk(0, OP_LD, 2, 16#0055#),    -- LD R2, 0x0055
        2  => make_rk(0, OP_LD, 3, 16#FFFF#),    -- LD R3, 0xFFFF
        3  => make_rk(0, OP_LD, 4, 16#0001#),    -- LD R4, 0x0001

        -- Test 2: Logic operations (NOP between dependent ops for hazard stall)
        4  => make_i(0, IOP_NOP),                 -- NOP (let R1 write complete)
        5  => make_rr(0, OP_OR,  5, 1),           -- OR  R5, R1  (R5 = 0 OR 0xAA = 0xAA)
        6  => make_i(0, IOP_NOP),                 -- NOP
        7  => make_rr(0, OP_XOR, 6, 1),           -- XOR R6, R1  (R6 = 0 XOR 0xAA = 0xAA)

        -- Test 3: Arithmetic operations
        8  => make_rk(0, OP_LD, 8, 16#00AA#),     -- LD R8, 0x00AA
        9  => make_i(0, IOP_NOP),                  -- NOP (hazard stall for R8)
        10 => make_rr(0, OP_ADD, 8, 2),           -- ADD R8, R2  (R8 = 0xAA + 0x55 = 0xFF)
        11 => make_i(0, IOP_NOP),                  -- NOP
        12 => make_rr(0, OP_ADD, 8, 4),           -- ADD R8, R4  (R8 = 0xFF + 1 = 0x100)

        -- Test 4: Shift operations
        13 => make_rk(0, OP_LD, 10, 16#8001#),    -- LD R10, 0x8001
        14 => make_i(0, IOP_NOP),                  -- NOP
        15 => make_r(0, SOP_SL0, 10),             -- SL0 R10 (0x8001 << 1 = 0x0002, CF=1)
        16 => make_i(0, IOP_NOP),                  -- NOP
        17 => make_r(0, SOP_SR0, 10),             -- SR0 R10 (0x0002 >> 1 = 0x0001, CF=0)
        18 => make_i(0, IOP_NOP),                  -- NOP
        19 => make_r(0, SOP_RL, 10),              -- RL  R10 (0x0001 rot left = 0x0002)

        -- Test 5: Conditional execution
        20 => make_rk(0, OP_LD, 11, 16#000A#),    -- LD R11, 10
        21 => make_i(0, IOP_NOP),                  -- NOP
        22 => make_rk(0, OP_SUB, 11, 16#000A#),   -- SUB R11, 10  -> result=0, ZF=1
        23 => make_rk(3, OP_LD, 12, 16#0001#),    -- IFZ LD R12, 1  (ZF=1 -> executes)
        24 => make_rk(2, OP_LD, 13, 16#0001#),    -- IFNZ LD R13, 1 (ZF=1 -> skipped)

        -- Test 6: TEST mode (cond=001)
        25 => make_rk(0, OP_LD, 14, 16#0005#),    -- LD R14, 5
        26 => make_i(0, IOP_NOP),                  -- NOP
        27 => make_rk(1, OP_SUB, 14, 16#0005#),   -- TEST SUB R14, 5 -> ZF=1 but R14 stays 5

        -- Test 7: Bit manipulation
        28 => make_rk(0, OP_LD, 15, 16#1234#),    -- LD R15, 0x1234
        29 => make_i(0, IOP_NOP),                  -- NOP
        30 => make_r(0, SOP_EXB, 15),             -- EXB R15 -> 0x3412
        31 => make_i(0, IOP_NOP),                  -- NOP
        32 => make_r(0, SOP_RLN, 15),             -- RLN R15 -> rotate nibble left

        -- Test 8: CALL and RET
        33 => make_k(0, KOP_CALL, 37),            -- CALL 37
        34 => make_i(0, IOP_NOP),                  -- NOP (after return)
        35 => make_i(0, IOP_NOP),                  -- NOP

        -- Infinite loop at end of test
        36 => make_k(0, KOP_JMP, 36),             -- JMP 36 (halt loop)

        -- Subroutine at address 37
        37 => make_rk(0, OP_LD, 0, 16#DEAD#),     -- LD R0, 0xDEAD
        38 => make_i(0, IOP_RET),                  -- RET

        others => (others => '0')
    );

begin

    process(iCLK)
    begin
        if rising_edge(iCLK) then
            if iRE = '1' then
                oDAT <= mem(to_integer(unsigned(iADR(9 downto 0))));
            end if;
        end if;
    end process;

end architecture sim;
