-- R1600 16-bit RISC Processor - Top Level
-- 5-stage pipeline: IF -> ID -> EX1 -> EX2 -> WB
-- Harvard architecture, 200 MHz target on Spartan-7

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.r1600_pkg.all;

entity r1600 is
    port (
        iCLK        : in  std_logic;
        iRST        : in  std_logic;
        -- Interrupt
        iINT        : in  std_logic;
        -- Debug
        iDBG_MODE   : in  std_logic;
        iDBG_BRK_ADR: in  std_logic_vector(PM_ADR_W-1 downto 0);
        oDBG_STATUS : out std_logic_vector(18 downto 0);
        -- Data Memory shared interface
        oDM_ADR     : out std_logic_vector(DM_ADR_W-1 downto 0);
        oDM_WE_A    : out std_logic;
        oDM_RE_A    : out std_logic;
        oDM_WE_B    : out std_logic;
        oDM_RE_B    : out std_logic;
        oDM_WR_DAT  : out std_logic_vector(DATA_W-1 downto 0);
        iDM_RD_DAT_A: in  std_logic_vector(DATA_W-1 downto 0);
        iDM_RD_DAT_B: in  std_logic_vector(DATA_W-1 downto 0);
        iDM_RDY     : in  std_logic;
        -- Program Memory
        oPM_ADR     : out std_logic_vector(PM_ADR_W-1 downto 0);
        iPM_DAT     : in  std_logic_vector(INSTR_W-1 downto 0);
        oPM_RE      : out std_logic
    );
end entity r1600;

architecture rtl of r1600 is

    ---------------------------------------------------------------------------
    -- Program Counter
    ---------------------------------------------------------------------------
    signal pc           : unsigned(PM_ADR_W-1 downto 0) := (others => '0');
    signal pc_next      : unsigned(PM_ADR_W-1 downto 0);
    signal pc_plus1     : unsigned(PM_ADR_W-1 downto 0);

    ---------------------------------------------------------------------------
    -- Pipeline registers
    ---------------------------------------------------------------------------
    signal if_id_r      : if_id_t := IF_ID_NOP;
    signal id_ex1_r     : id_ex1_t := ID_EX1_NOP;
    signal ex1_ex2_r    : ex1_ex2_t := EX1_EX2_NOP;
    signal ex2_wb_r     : ex2_wb_t := EX2_WB_NOP;

    ---------------------------------------------------------------------------
    -- Flags
    ---------------------------------------------------------------------------
    signal flag_cf      : std_logic := '0';
    signal flag_zf      : std_logic := '0';
    signal flag_if      : std_logic := '0';

    ---------------------------------------------------------------------------
    -- Branch control
    ---------------------------------------------------------------------------
    signal branch_target  : unsigned(PM_ADR_W-1 downto 0) := (others => '0');
    signal flush_pipe     : std_logic := '0';
    signal delay_counter  : unsigned(1 downto 0) := "00";
    signal delay_target   : unsigned(PM_ADR_W-1 downto 0) := (others => '0');
    signal delay_active   : std_logic := '0';

    ---------------------------------------------------------------------------
    -- Stall control
    ---------------------------------------------------------------------------
    signal pipe_stall     : std_logic := '0';
    signal hazard_stall   : std_logic := '0';
    signal mem_started    : std_logic := '0';

    ---------------------------------------------------------------------------
    -- Decoder output
    ---------------------------------------------------------------------------
    signal dec_ctrl       : ctrl_t;

    ---------------------------------------------------------------------------
    -- Conditional evaluation
    ---------------------------------------------------------------------------
    signal cond_exec_en   : std_logic;
    signal cond_test_en   : std_logic;

    ---------------------------------------------------------------------------
    -- Register file signals
    ---------------------------------------------------------------------------
    signal rf_wr_en       : std_logic;
    signal rf_wr_addr     : std_logic_vector(REG_ADR_W-1 downto 0);
    signal rf_wr_data     : std_logic_vector(DATA_W-1 downto 0);
    signal rf_rd_a_data   : std_logic_vector(DATA_W-1 downto 0);
    signal rf_rd_b_data   : std_logic_vector(DATA_W-1 downto 0);

    ---------------------------------------------------------------------------
    -- ALU signals
    ---------------------------------------------------------------------------
    signal alu_a          : std_logic_vector(DATA_W-1 downto 0);
    signal alu_b          : std_logic_vector(DATA_W-1 downto 0);
    signal alu_result     : std_logic_vector(DATA_W-1 downto 0);
    signal alu_cf_out     : std_logic;
    signal alu_zf_out     : std_logic;
    signal alu_cf_upd     : std_logic;
    signal alu_zf_upd     : std_logic;

    ---------------------------------------------------------------------------
    -- Memory controller signals
    ---------------------------------------------------------------------------
    signal mc_mem_read    : std_logic;
    signal mc_mem_write   : std_logic;
    signal mc_addr        : std_logic_vector(DM_ADR_W-1 downto 0);
    signal mc_wr_data     : std_logic_vector(DATA_W-1 downto 0);
    signal mc_rd_data     : std_logic_vector(DATA_W-1 downto 0);
    signal mc_rd_valid    : std_logic;
    signal mc_stall       : std_logic;
    signal mc_busy        : std_logic;

    ---------------------------------------------------------------------------
    -- PC stack signals
    ---------------------------------------------------------------------------
    signal pcs_push       : std_logic;
    signal pcs_pop        : std_logic;
    signal pcs_in         : std_logic_vector(PM_ADR_W-1 downto 0);
    signal pcs_out        : std_logic_vector(PM_ADR_W-1 downto 0);

    ---------------------------------------------------------------------------
    -- Flag stack signals
    ---------------------------------------------------------------------------
    signal fs_push        : std_logic;
    signal fs_pop         : std_logic;
    signal fs_cf_out      : std_logic;
    signal fs_zf_out      : std_logic;
    signal fs_if_out      : std_logic;

    ---------------------------------------------------------------------------
    -- Debug/interrupt controller signals
    ---------------------------------------------------------------------------
    signal int_req        : std_logic;
    signal dbg_req        : std_logic;
    signal int_vec        : std_logic_vector(PM_ADR_W-1 downto 0);
    signal dbg_vec        : std_logic_vector(PM_ADR_W-1 downto 0);
    signal dbg_mask_int   : std_logic;
    signal reti_executing : std_logic;
    signal wb_valid       : std_logic;

    ---------------------------------------------------------------------------
    -- Forwarding
    ---------------------------------------------------------------------------
    signal fwd_rt_data    : std_logic_vector(DATA_W-1 downto 0);
    signal fwd_rs_data    : std_logic_vector(DATA_W-1 downto 0);

    ---------------------------------------------------------------------------
    -- Branch target from EX1
    ---------------------------------------------------------------------------
    signal ex1_branch_target : unsigned(PM_ADR_W-1 downto 0);
    signal ex1_branch_taken  : std_logic;
    signal ex1_is_delayed    : std_logic;

    ---------------------------------------------------------------------------
    -- Flag stack capture for pipeline transport
    ---------------------------------------------------------------------------
    signal ex1_pop_flags     : std_logic;

begin

    ---------------------------------------------------------------------------
    -- Sub-module instantiation
    ---------------------------------------------------------------------------

    u_decode : entity work.decode
        port map (
            iINSTR => if_id_r.instr,
            iVALID => if_id_r.valid,
            oCTRL  => dec_ctrl
        );

    u_cond : entity work.cond_eval
        port map (
            iCOND    => dec_ctrl.cond,
            iCF      => flag_cf,
            iZF      => flag_zf,
            oEXEC_EN => cond_exec_en,
            oTEST_EN => cond_test_en
        );

    u_regfile : entity work.reg_file
        port map (
            iCLK       => iCLK,
            iRST       => iRST,
            iWR_EN     => rf_wr_en,
            iWR_ADDR   => rf_wr_addr,
            iWR_DATA   => rf_wr_data,
            iRD_A_ADDR => dec_ctrl.rt_addr,
            oRD_A_DATA => rf_rd_a_data,
            iRD_B_ADDR => dec_ctrl.rs_addr,
            oRD_B_DATA => rf_rd_b_data
        );

    u_alu : entity work.alu
        port map (
            iOP     => id_ex1_r.ctrl.alu_op,
            iA      => alu_a,
            iB      => alu_b,
            iCF     => flag_cf,
            oRESULT => alu_result,
            oCF     => alu_cf_out,
            oZF     => alu_zf_out,
            oCF_UPD => alu_cf_upd,
            oZF_UPD => alu_zf_upd
        );

    u_mem_ctrl : entity work.mem_ctrl
        port map (
            iCLK         => iCLK,
            iRST         => iRST,
            iMEM_READ    => mc_mem_read,
            iMEM_WRITE   => mc_mem_write,
            iADDR        => mc_addr,
            iWR_DATA     => mc_wr_data,
            oRD_DATA     => mc_rd_data,
            oRD_VALID    => mc_rd_valid,
            oSTALL       => mc_stall,
            oBUSY        => mc_busy,
            oDM_ADR      => oDM_ADR,
            oDM_WE_A     => oDM_WE_A,
            oDM_RE_A     => oDM_RE_A,
            oDM_WE_B     => oDM_WE_B,
            oDM_RE_B     => oDM_RE_B,
            oDM_WR_DAT   => oDM_WR_DAT,
            iDM_RD_DAT_A => iDM_RD_DAT_A,
            iDM_RD_DAT_B => iDM_RD_DAT_B,
            iDM_RDY      => iDM_RDY
        );

    u_pc_stack : entity work.pc_stack
        port map (
            iCLK  => iCLK,
            iRST  => iRST,
            iPUSH => pcs_push,
            iPOP  => pcs_pop,
            iDATA => pcs_in,
            oDATA => pcs_out
        );

    u_flag_stack : entity work.flag_stack
        port map (
            iCLK  => iCLK,
            iRST  => iRST,
            iPUSH => fs_push,
            iPOP  => fs_pop,
            iCF   => flag_cf,
            iZF   => flag_zf,
            iIF   => flag_if,
            oCF   => fs_cf_out,
            oZF   => fs_zf_out,
            oIF   => fs_if_out
        );

    u_dbg_ctrl : entity work.dbg_ctrl
        port map (
            iCLK         => iCLK,
            iRST         => iRST,
            iINT         => iINT,
            iIF_FLAG     => flag_if,
            iDBG_MODE    => iDBG_MODE,
            iDBG_BRK_ADR => iDBG_BRK_ADR,
            iCURR_PC     => std_logic_vector(pc),
            iPIPE_VALID  => wb_valid,
            iRETI_EXEC   => reti_executing,
            oINT_REQ     => int_req,
            oDBG_REQ     => dbg_req,
            oINT_VEC     => int_vec,
            oDBG_VEC     => dbg_vec,
            oMASK_INT    => dbg_mask_int,
            iCF          => flag_cf,
            iZF          => flag_zf,
            oDBG_STATUS  => oDBG_STATUS
        );

    ---------------------------------------------------------------------------
    -- Hazard detection: 1-cycle stall for RAW hazard from EX1
    ---------------------------------------------------------------------------
    hazard_stall <= '1' when id_ex1_r.valid = '1' and id_ex1_r.exec_en = '1'
                             and id_ex1_r.ctrl.wb_en = '1'
                             and if_id_r.valid = '1'
                             and ((id_ex1_r.ctrl.rt_addr = dec_ctrl.rt_addr)
                                  or (id_ex1_r.ctrl.rt_addr = dec_ctrl.rs_addr
                                      and dec_ctrl.uses_rs = '1'))
                    else '0';

    ---------------------------------------------------------------------------
    -- Pipeline stall (memory wait OR hazard OR initial memory request)
    ---------------------------------------------------------------------------
    pipe_stall <= mc_stall or hazard_stall or mc_mem_read or mc_mem_write;

    ---------------------------------------------------------------------------
    -- PC logic
    ---------------------------------------------------------------------------
    pc_plus1 <= pc + 1;

    process(all)
    begin
        pc_next <= pc_plus1;

        if dbg_req = '1' then
            pc_next <= unsigned(dbg_vec);
        elsif int_req = '1' then
            pc_next <= unsigned(int_vec);
        elsif delay_active = '1' and delay_counter = "00" then
            pc_next <= delay_target;
        elsif flush_pipe = '1' then
            pc_next <= branch_target;
        end if;
    end process;

    ---------------------------------------------------------------------------
    -- Stage 1: IF (Instruction Fetch)
    ---------------------------------------------------------------------------
    oPM_ADR <= std_logic_vector(pc);
    oPM_RE  <= '1' when pipe_stall = '0' else '0';

    process(iCLK)
    begin
        if rising_edge(iCLK) then
            if iRST = '1' then
                pc       <= (others => '0');
                if_id_r  <= IF_ID_NOP;
            elsif pipe_stall = '0' then
                pc <= pc_next;

                if flush_pipe = '1' or dbg_req = '1' or int_req = '1' then
                    if_id_r <= IF_ID_NOP;
                else
                    if_id_r.instr <= iPM_DAT;
                    if_id_r.pc    <= std_logic_vector(pc);
                    if_id_r.valid <= '1';
                end if;
            end if;
        end if;
    end process;

    ---------------------------------------------------------------------------
    -- Stage 2: ID (Instruction Decode)
    ---------------------------------------------------------------------------

    -- Data forwarding from EX2 and WB stages
    process(all)
    begin
        fwd_rt_data <= rf_rd_a_data;
        fwd_rs_data <= rf_rd_b_data;

        -- Forward from WB (lowest priority)
        if ex2_wb_r.valid = '1' and ex2_wb_r.exec_en = '1'
           and ex2_wb_r.ctrl.wb_en = '1' and ex2_wb_r.test_en = '0' then
            if ex2_wb_r.ctrl.rt_addr = dec_ctrl.rt_addr then
                fwd_rt_data <= ex2_wb_r.result;
            end if;
            if ex2_wb_r.ctrl.rt_addr = dec_ctrl.rs_addr then
                fwd_rs_data <= ex2_wb_r.result;
            end if;
        end if;

        -- Forward from EX2 (higher priority, more recent)
        if ex1_ex2_r.valid = '1' and ex1_ex2_r.exec_en = '1'
           and ex1_ex2_r.ctrl.wb_en = '1' and ex1_ex2_r.test_en = '0'
           and ex1_ex2_r.ctrl.mem_read = '0' then
            if ex1_ex2_r.ctrl.rt_addr = dec_ctrl.rt_addr then
                fwd_rt_data <= ex1_ex2_r.alu_result;
            end if;
            if ex1_ex2_r.ctrl.rt_addr = dec_ctrl.rs_addr then
                fwd_rs_data <= ex1_ex2_r.alu_result;
            end if;
        end if;
    end process;

    -- ID -> EX1 pipeline register
    process(iCLK)
    begin
        if rising_edge(iCLK) then
            if iRST = '1' then
                id_ex1_r <= ID_EX1_NOP;
            elsif pipe_stall = '0' then
                if flush_pipe = '1' or dbg_req = '1' or int_req = '1' then
                    id_ex1_r <= ID_EX1_NOP;
                else
                    id_ex1_r.ctrl    <= dec_ctrl;
                    id_ex1_r.rt_data <= fwd_rt_data;
                    id_ex1_r.rs_data <= fwd_rs_data;
                    id_ex1_r.pc      <= if_id_r.pc;
                    id_ex1_r.exec_en <= cond_exec_en and if_id_r.valid;
                    id_ex1_r.test_en <= cond_test_en;
                    id_ex1_r.valid   <= if_id_r.valid;
                end if;
            elsif hazard_stall = '1' then
                -- Hazard stall: insert bubble into EX1, hold IF/ID
                id_ex1_r <= ID_EX1_NOP;
            end if;
        end if;
    end process;

    ---------------------------------------------------------------------------
    -- Stage 3: EX1 (Execute 1)
    ---------------------------------------------------------------------------

    -- ALU operand muxing
    alu_a <= id_ex1_r.rt_data;
    alu_b <= id_ex1_r.ctrl.imm when id_ex1_r.ctrl.uses_imm = '1' and id_ex1_r.ctrl.uses_rs = '0'
             else id_ex1_r.rs_data;

    -- Memory address computation for IN/OUT
    -- RRK: address = imm(15:0) & Rs(15:0) concatenated to 32 bits
    -- RK:  address = x"0000" & imm(15:0)
    mc_addr <= id_ex1_r.ctrl.imm & id_ex1_r.rs_data
               when id_ex1_r.ctrl.uses_rs = '1' and
                    (id_ex1_r.ctrl.mem_read = '1' or id_ex1_r.ctrl.mem_write = '1')
               else x"0000" & id_ex1_r.ctrl.imm
               when id_ex1_r.ctrl.mem_read = '1' or id_ex1_r.ctrl.mem_write = '1'
               else (others => '0');

    -- Memory control signals (fire only once per memory instruction)
    mc_mem_read  <= id_ex1_r.ctrl.mem_read and id_ex1_r.exec_en and id_ex1_r.valid
                    and (not mc_busy) and (not mem_started);
    mc_mem_write <= id_ex1_r.ctrl.mem_write and id_ex1_r.exec_en and id_ex1_r.valid
                    and (not mc_busy) and (not mem_started);
    mc_wr_data   <= id_ex1_r.rt_data;

    -- Track whether the memory operation for the current EX1 instruction has started
    process(iCLK)
    begin
        if rising_edge(iCLK) then
            if iRST = '1' then
                mem_started <= '0';
            elsif pipe_stall = '0' then
                mem_started <= '0';  -- new instruction entering EX1
            elsif mc_mem_read = '1' or mc_mem_write = '1' then
                mem_started <= '1';  -- operation initiated, prevent re-trigger
            end if;
        end if;
    end process;

    -- Detect if this EX1 instruction pops flags (for pipeline capture)
    ex1_pop_flags <= '1' when id_ex1_r.valid = '1' and id_ex1_r.exec_en = '1'
                              and (id_ex1_r.ctrl.popf = '1'
                                   or id_ex1_r.ctrl.popi = '1'
                                   or id_ex1_r.ctrl.branch_type = BR_RETI
                                   or id_ex1_r.ctrl.branch_type = BR_DRETI)
                     else '0';

    -- Branch logic + stack operations in EX1
    process(all)
        variable bt : branch_type_t;
    begin
        ex1_branch_taken  <= '0';
        ex1_branch_target <= (others => '0');
        ex1_is_delayed    <= '0';
        pcs_push          <= '0';
        pcs_pop           <= '0';
        pcs_in            <= (others => '0');
        fs_push           <= '0';
        fs_pop            <= '0';

        bt := id_ex1_r.ctrl.branch_type;

        if id_ex1_r.valid = '1' and id_ex1_r.exec_en = '1' and pipe_stall = '0' then
            case bt is
                when BR_JMP =>
                    ex1_branch_taken <= '1';
                    if id_ex1_r.ctrl.fmt = FMT_K then
                        ex1_branch_target <= unsigned(id_ex1_r.ctrl.imm(PM_ADR_W-1 downto 0));
                    else
                        ex1_branch_target <= unsigned(id_ex1_r.rt_data(PM_ADR_W-1 downto 0));
                    end if;

                when BR_DJMP =>
                    ex1_branch_taken <= '1';
                    ex1_is_delayed   <= '1';
                    if id_ex1_r.ctrl.fmt = FMT_K then
                        ex1_branch_target <= unsigned(id_ex1_r.ctrl.imm(PM_ADR_W-1 downto 0));
                    else
                        ex1_branch_target <= unsigned(id_ex1_r.rt_data(PM_ADR_W-1 downto 0));
                    end if;

                when BR_CALL =>
                    ex1_branch_taken <= '1';
                    pcs_push <= '1';
                    pcs_in   <= std_logic_vector(unsigned(id_ex1_r.pc) + 1);
                    if id_ex1_r.ctrl.fmt = FMT_K then
                        ex1_branch_target <= unsigned(id_ex1_r.ctrl.imm(PM_ADR_W-1 downto 0));
                    else
                        ex1_branch_target <= unsigned(id_ex1_r.rt_data(PM_ADR_W-1 downto 0));
                    end if;

                when BR_CALLI =>
                    ex1_branch_taken <= '1';
                    pcs_push <= '1';
                    pcs_in   <= std_logic_vector(unsigned(id_ex1_r.pc) + 1);
                    fs_push  <= '1';
                    if id_ex1_r.ctrl.fmt = FMT_K then
                        ex1_branch_target <= unsigned(id_ex1_r.ctrl.imm(PM_ADR_W-1 downto 0));
                    else
                        ex1_branch_target <= unsigned(id_ex1_r.rt_data(PM_ADR_W-1 downto 0));
                    end if;

                when BR_DCALL =>
                    ex1_branch_taken <= '1';
                    ex1_is_delayed   <= '1';
                    pcs_push <= '1';
                    pcs_in   <= std_logic_vector(unsigned(id_ex1_r.pc) + 3);
                    if id_ex1_r.ctrl.fmt = FMT_K then
                        ex1_branch_target <= unsigned(id_ex1_r.ctrl.imm(PM_ADR_W-1 downto 0));
                    else
                        ex1_branch_target <= unsigned(id_ex1_r.rt_data(PM_ADR_W-1 downto 0));
                    end if;

                when BR_DCALLI =>
                    ex1_branch_taken <= '1';
                    ex1_is_delayed   <= '1';
                    pcs_push <= '1';
                    pcs_in   <= std_logic_vector(unsigned(id_ex1_r.pc) + 3);
                    fs_push  <= '1';
                    if id_ex1_r.ctrl.fmt = FMT_K then
                        ex1_branch_target <= unsigned(id_ex1_r.ctrl.imm(PM_ADR_W-1 downto 0));
                    else
                        ex1_branch_target <= unsigned(id_ex1_r.rt_data(PM_ADR_W-1 downto 0));
                    end if;

                when BR_RET =>
                    ex1_branch_taken  <= '1';
                    pcs_pop           <= '1';
                    ex1_branch_target <= unsigned(pcs_out);

                when BR_RETI =>
                    ex1_branch_taken  <= '1';
                    pcs_pop           <= '1';
                    fs_pop            <= '1';
                    ex1_branch_target <= unsigned(pcs_out);

                when BR_DRET =>
                    ex1_branch_taken  <= '1';
                    ex1_is_delayed    <= '1';
                    pcs_pop           <= '1';
                    ex1_branch_target <= unsigned(pcs_out);

                when BR_DRETI =>
                    ex1_branch_taken  <= '1';
                    ex1_is_delayed    <= '1';
                    pcs_pop           <= '1';
                    fs_pop            <= '1';
                    ex1_branch_target <= unsigned(pcs_out);

                when BR_NONE =>
                    null;
            end case;

            -- PUSHF/POPF/PUSHI/POPI handling
            if id_ex1_r.ctrl.pushf = '1' or id_ex1_r.ctrl.pushi = '1' then
                fs_push <= '1';
            end if;
            if id_ex1_r.ctrl.popf = '1' or id_ex1_r.ctrl.popi = '1' then
                fs_pop <= '1';
            end if;
        end if;
    end process;

    -- Branch/flush control
    process(iCLK)
    begin
        if rising_edge(iCLK) then
            if iRST = '1' then
                flush_pipe     <= '0';
                branch_target  <= (others => '0');
                delay_counter  <= "00";
                delay_active   <= '0';
                delay_target   <= (others => '0');
            elsif pipe_stall = '0' then
                flush_pipe <= '0';

                -- Delayed branch countdown
                if delay_active = '1' then
                    if delay_counter = "00" then
                        delay_active <= '0';
                    else
                        delay_counter <= delay_counter - 1;
                    end if;
                end if;

                -- New branch from EX1
                if ex1_branch_taken = '1' then
                    if ex1_is_delayed = '1' then
                        delay_active  <= '1';
                        delay_counter <= "01";
                        delay_target  <= ex1_branch_target;
                    else
                        flush_pipe    <= '1';
                        branch_target <= ex1_branch_target;
                    end if;
                end if;

                -- Interrupt/debug override
                if dbg_req = '1' or int_req = '1' then
                    flush_pipe    <= '1';
                    delay_active  <= '0';
                end if;
            end if;
        end if;
    end process;

    -- EX1 -> EX2 pipeline register
    process(iCLK)
    begin
        if rising_edge(iCLK) then
            if iRST = '1' then
                ex1_ex2_r <= EX1_EX2_NOP;
            elsif pipe_stall = '0' then
                ex1_ex2_r.ctrl       <= id_ex1_r.ctrl;
                ex1_ex2_r.alu_result <= alu_result;
                ex1_ex2_r.alu_cf     <= alu_cf_out;
                ex1_ex2_r.alu_zf     <= alu_zf_out;
                ex1_ex2_r.dm_addr    <= mc_addr;
                ex1_ex2_r.wr_data    <= id_ex1_r.rt_data;
                ex1_ex2_r.exec_en    <= id_ex1_r.exec_en;
                ex1_ex2_r.test_en    <= id_ex1_r.test_en;
                ex1_ex2_r.valid      <= id_ex1_r.valid;
                -- Capture flag stack output NOW (before sp changes on next edge)
                if ex1_pop_flags = '1' then
                    ex1_ex2_r.pop_cf <= fs_cf_out;
                    ex1_ex2_r.pop_zf <= fs_zf_out;
                    ex1_ex2_r.pop_if <= fs_if_out;
                else
                    ex1_ex2_r.pop_cf <= '0';
                    ex1_ex2_r.pop_zf <= '0';
                    ex1_ex2_r.pop_if <= '0';
                end if;
            end if;
        end if;
    end process;

    ---------------------------------------------------------------------------
    -- Stage 4: EX2 (Execute 2 / Memory capture)
    ---------------------------------------------------------------------------
    process(iCLK)
    begin
        if rising_edge(iCLK) then
            if iRST = '1' then
                ex2_wb_r <= EX2_WB_NOP;
            elsif pipe_stall = '0' then
                ex2_wb_r.ctrl    <= ex1_ex2_r.ctrl;
                ex2_wb_r.alu_cf  <= ex1_ex2_r.alu_cf;
                ex2_wb_r.alu_zf  <= ex1_ex2_r.alu_zf;
                ex2_wb_r.exec_en <= ex1_ex2_r.exec_en;
                ex2_wb_r.test_en <= ex1_ex2_r.test_en;
                ex2_wb_r.valid   <= ex1_ex2_r.valid;
                -- Pass through captured flag stack values
                ex2_wb_r.pop_cf  <= ex1_ex2_r.pop_cf;
                ex2_wb_r.pop_zf  <= ex1_ex2_r.pop_zf;
                ex2_wb_r.pop_if  <= ex1_ex2_r.pop_if;

                -- Result mux: memory read data or ALU result
                -- Pipeline stall guarantees mc_rd_data is valid when instruction reaches EX2
                if ex1_ex2_r.ctrl.mem_read = '1' then
                    ex2_wb_r.result <= mc_rd_data;
                else
                    ex2_wb_r.result <= ex1_ex2_r.alu_result;
                end if;
            end if;
        end if;
    end process;

    ---------------------------------------------------------------------------
    -- Stage 5: WB (Write Back)
    ---------------------------------------------------------------------------

    -- Register file write
    rf_wr_en   <= ex2_wb_r.ctrl.wb_en and ex2_wb_r.exec_en
                  and ex2_wb_r.valid and (not ex2_wb_r.test_en);
    rf_wr_addr <= ex2_wb_r.ctrl.rt_addr;
    rf_wr_data <= ex2_wb_r.result;

    wb_valid <= ex2_wb_r.valid and ex2_wb_r.exec_en;

    reti_executing <= '1' when ex2_wb_r.valid = '1' and ex2_wb_r.exec_en = '1'
                              and (ex2_wb_r.ctrl.branch_type = BR_RETI
                                   or ex2_wb_r.ctrl.branch_type = BR_DRETI)
                      else '0';

    -- Flag updates in WB stage
    process(iCLK)
    begin
        if rising_edge(iCLK) then
            if iRST = '1' then
                flag_cf <= '0';
                flag_zf <= '0';
                flag_if <= '0';
            elsif pipe_stall = '0' then
                -- ALU flag update (including TEST mode)
                if ex2_wb_r.valid = '1' and ex2_wb_r.exec_en = '1'
                   and ex2_wb_r.ctrl.flag_update = '1' then
                    flag_cf <= ex2_wb_r.alu_cf;
                    flag_zf <= ex2_wb_r.alu_zf;
                end if;

                -- POPF: restore all flags from captured stack values
                if ex2_wb_r.valid = '1' and ex2_wb_r.exec_en = '1'
                   and ex2_wb_r.ctrl.popf = '1' then
                    flag_cf <= ex2_wb_r.pop_cf;
                    flag_zf <= ex2_wb_r.pop_zf;
                    flag_if <= ex2_wb_r.pop_if;
                end if;

                -- POPI: restore IF only from captured stack values
                if ex2_wb_r.valid = '1' and ex2_wb_r.exec_en = '1'
                   and ex2_wb_r.ctrl.popi = '1' then
                    flag_if <= ex2_wb_r.pop_if;
                end if;

                -- RETI/DRETI: restore all flags from captured stack values
                if reti_executing = '1' then
                    flag_cf <= ex2_wb_r.pop_cf;
                    flag_zf <= ex2_wb_r.pop_zf;
                    flag_if <= ex2_wb_r.pop_if;
                end if;

                -- EI/DI
                if ex2_wb_r.valid = '1' and ex2_wb_r.exec_en = '1' then
                    if ex2_wb_r.ctrl.int_enable = '1' then
                        flag_if <= '1';
                    end if;
                    if ex2_wb_r.ctrl.int_disable = '1' then
                        flag_if <= '0';
                    end if;
                    if ex2_wb_r.ctrl.pushi = '1' then
                        flag_if <= '0';
                    end if;
                end if;

                -- Interrupt/debug: clear IF
                if int_req = '1' or dbg_req = '1' then
                    flag_if <= '0';
                end if;

                -- Debug mask overrides
                if dbg_mask_int = '1' then
                    flag_if <= '0';
                end if;
            end if;
        end if;
    end process;

end architecture rtl;
